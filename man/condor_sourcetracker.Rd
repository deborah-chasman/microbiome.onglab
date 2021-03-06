% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sourcetracker_functions.R
\name{condor_sourcetracker}
\alias{condor_sourcetracker}
\title{generates the condor file to performing quality control with sourcertracker}
\usage{
condor_sourcetracker(sourcetracker_asvfile = "",
  sourcetracker_negcontrol = "", sourcetracker_paramfile = "",
  sourcetracker_outdir = ".", top_asv = 50, max_split_size = 30,
  rarefaction_depth = NULL, sourcetracker_prefix = "sourcetracker",
  condor_file = "./condor_sourcetracker",
  batch_name = "sourcetracker_run", request_cores = 8,
  request_mem = "4 GB")
}
\arguments{
\item{sourcetracker_asvfile}{name of the rds file with the asv matrix}

\item{sourcetracker_negcontrol}{name of the rds file with the relationship between samples and negative controls}

\item{sourcetracker_paramfile}{json file with sourcetracker's parameters}

\item{sourcetracker_outdir}{directory where the results are saved}

\item{top_asv}{number of ASVs to be used with sourcetracker to accelerate performance}

\item{max_split_size}{max. number of samples to do by a cpu}

\item{rarefaction_depth}{parameter to control for ASVs (OTUs) with higher abundance. This makes all taxa to have at most this abundance
(by default NULL skips this step)}

\item{sourcetracker_prefix}{prefix of the file with the results}

\item{condor_file}{file where the condor commands are saved}

\item{batch_name}{name of the batch}

\item{request_cores}{Number of cpus to request by condor}

\item{request_mem}{Memory request by condor}
}
\description{
sourcetracker (Knights et al 2013, https://dx.doi.org/10.1038%2Fnmeth.1650) fits a mixture model of the samples with sources as components, in our
case we use the negative controls as such.
}
