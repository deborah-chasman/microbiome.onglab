#!/usr/bin/env Rscript

## wrapper for sourcetracker run

library(optparse)

opt_list <- list(
  make_option("--asv_file", action = "store_true" , type = "character",
              help = "Name of the dada2 asv matrix. This is the matrix after
              removing the chimeras."),
  make_option("--neg_control_file", action = "store_true", type = "character",
              help = "Name of an rds file with the relationship between samples and controls.
	            It is expected a tibble with two columns: sample | neg_control, where the
	            elements of the second column are character vectors with the neg. controls
	            that correspond to the sample"),
  make_option("--param_file", action = "store_true", type = "character",
              help = "Location of the parameter file in json format, if not provided
        	the script will use sourcetracker default parameters"),
  make_option("--top_asvs", action = "store_true", type = "numeric",
              default = 50,
              help = "Number of the top ASVs to use"),
  make_option("--max_split_size", action = "store_true", type = "numeric",
              default = 30,
              help = "Max number of samples that are going to be processed at once"),
  make_option("--rarefaction_depth", action = "store_true", type = "character",
              default = "inf",
              help = "Depth to rarefy the samples [Numeric or 'inf']"),
  make_option("--outfile", action = "store_true", type = "character",
              help = "Name of the file where the results are saved"),
  make_option("--cores", action = "store_true", type = "numeric",
              default = 4 ,
              help = "Number of cores to be used for parallel processing"))


sourcetracker_url <-
  "https://raw.githubusercontent.com/danknights/sourcetracker/master/src/SourceTracker.r"

opt <- parse_args(OptionParser(option_list = opt_list))

out_file = opt$outfile ## may change if we change the directory structure

stopifnot(file.exists(opt$asv_file),
          file.exists(opt$neg_control_file))

if(tolower(opt$rarefaction_depth) == "inf"){
  opt$rarefaction_depth = NULL
}else{
  opt$rarefaction_depth = as.numeric(opt$rarefaction_depth)
}

library(magrittr)
library(tidyverse)
library(parallel)
library(microbiome.onglab)


asv_table <- readRDS(opt$asv_file)
neg_controls <- readRDS(opt$neg_control_file)


if(!file.exists(opt$param_file)){
  params <- data.frame()
}else{
  params <- fromJSON(opt$param_file, flatten = TRUE)
}

dada2_params <- c("alpha1","alpha2","beta")

stopifnot( all( names(params) %in% dada2_params))



neg_controls_groups <- neg_controls %>%
  mutate( neg_control_full = map_chr(neg_control, str_c,collapse = "_")) %>%
  count( neg_control_full) %>%
  mutate( id = str_c("G",row_number()))

neg_controls %<>%
  mutate(
    neg_control_full = map_chr(neg_control,str_c,collapse = "_")) %>%
  left_join(neg_controls_groups) %>%
  select(-n,-neg_control_full)

samples <- rownames(asv_table)


all_negative_controls <- neg_controls %>% pull(neg_control) %>%
  unlist() %>% unique()

controls.ix <- str_to_lower(samples) %in% str_to_lower(all_negative_controls)

## only use the top_asvs in order to make the code run faster
asv_table <- asv_table[,seq_len(opt$top_asvs)]

script <- RCurl::getURL(sourcetracker_url)
eval(parse(text = script))

alpha1 <- get_param_sourcetracker("alpha1", params)
alpha2 <- get_param_sourcetracker("alpha2", params)
beta <- get_param_sourcetracker("beta",params)


neg_controls %<>% nest(-id,.key = "group")


create_sourcetracker_object <- function(group,asv,rarefaction_depth)
{
  samples <- group %>% pull(sample)
  neg_controls <- pull(group,neg_control) %>% unlist() %>% unique()

  sourcetracker(asv[samples,],asv[neg_controls,],rarefaction_depth = rarefaction_depth)

}

split_run <- function(stracker,group,asv,split_size)
{
  samples <- pull(group,sample)
  sample_table <- asv[samples,]
  if( nrow(sample_table) > split_size){

    splits <- seq_len(ceiling(nrow(sample_table) / split_size))
    splits <- rep(splits,each = split_size)
    splits <- splits[seq_len(nrow(sample_table))]
    split_samples <- split(samples,splits)

    split_samples <- map(split_samples, ~ sample_table[.,])


  }else{
    split_samples <- list(sample_table)
  }

  split_results <- mclapply(split_samples,
                            function(x)predict(stracker,x,
                                               alpha1 = alpha1 ,
                                               alpha2 = alpha2,
                                               beta = beta),
                            mc.cores = opt$cores)

  split_results
}

merge_results <- function(split_results)
{

  draws <- map(split_results,"draws")
  draws <- do.call(abind::abind,draws,3)

  proportions <- map(split_results,"proportions")
  proportions <- do.call(rbind,proportions)

  proportions_sd <- map(split_results,"proportions_sd")
  proportions_sd <- do.call(rbind,proportions_sd)

  train.envs <- map(split_results,"train.envs")
  train.envs <- train.envs[[1]]

  samplenames <- map(split_results,"samplenames")
  samplenames <- do.call(c,samplenames)

  out <- list(
    "draws" = draws,
    "proportions" = proportions,
    "proportions_sd" = proportions_sd,
    "train.envs" = train.envs,
    "samplenames" = samplenames)

  class(out) <- "sourcetracker.fit"

  invisible(out)
}

# train SourceTracker object on training data
neg_controls %<>%
  mutate(
    stracker = map(group,create_sourcetracker_object,asv_table,opt$rarefaction_depth),
    preds = map2(stracker,group,split_run,asv_table,opt$max_split_size))

# merge parallel results and clean them to tibble / data.frame
neg_controls %<>%
  mutate(
    results = map(preds, merge_results),
    draws = map(results,"draws"),
    proportions = map(results, "proportions"),
    proportions_sd = map(results, "proportions_sd"),
    train.envs = map(results,"train.envs"),
    samplenames = map(results,"samplenames"))

clean_proportions <- function(proportions,proportions_sd)
{

  proportions %<>% as.data.frame() %>%
    rownames_to_column("sample") %>%
    as_tibble()
  proportions_sd %<>%
    as.data.frame() %>%
    rownames_to_column("sample") %>%
    as_tibble()
  proportions %<>%
    gather(control,value,-sample)
  proportions_sd %<>%
    gather(control,value,-sample)

  bind_rows(
    proportions %>%
      mutate(
        type = "mean"),
    proportions_sd %>%
      mutate(
        type = "sd"))

}

clean_draws <- function(draw,train.envs,samplenames)
{
  draw <- aperm(draw, perm = c(3,2,1))
  train.envs %<>% str_replace_all("\\-","\\_")
  samplenames %<>% str_replace_all("\\-","\\_")

  dimnames(draw) <- list(samplenames,
                         train.envs,
                         NULL)

  flat_draw <- draw %>% as.data.frame() %>%
    as_tibble() %>%
    mutate(sample = samplenames) %>%
    gather(control_draw, proportion, -sample)

  flat_draw %>% separate(control_draw,into = c("control","draw"),sep = "\\.")


}

neg_controls %<>%
  mutate(
    draws = pmap(list(draws,train.envs,samplenames), clean_draws),
    proportions = map2(proportions,proportions_sd,clean_proportions))

neg_controls %<>%
  select(-proportions_sd,-train.envs,-samplenames,-stracker,
         -preds,-merged_results,-results)


neg_controls %>% saveRDS(out_file)