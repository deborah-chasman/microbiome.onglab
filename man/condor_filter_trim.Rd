% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/filter_and_trim_functions.R
\name{condor_filter_trim}
\alias{condor_filter_trim}
\title{generate the input to filter and trim the fastq files
with condor}
\usage{
condor_filter_trim(trim_queue_file = "", trim_param_file = "",
  trim_outdir = ".", condor_file = "./condor_filter_trim",
  batch_name = "dada2_trim_sequences", request_cores = 4,
  request_mem = "4 GB")
}
\arguments{
\item{trim_queue_file}{name of the file with the queue, it has 3 columns sample_name | R1.fastq | R2.fastq}

\item{trim_param_file}{name of the file with the filter and trim parameters}

\item{trim_outdir}{directory where the output is going to be saved}

\item{condor_file}{name of the file with condor instructions}

\item{batch_name}{string with the name of the batch}

\item{request_cores}{number of cpus per machine}

\item{request_mem}{number of GB required as memory}
}
\description{
generate the input to filter and trim the fastq files
with condor
}
