% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/HDcox_comparison_functions.R
\name{super.evalAllModels}
\alias{super.evalAllModels}
\title{super.evalAllModels}
\usage{
super.evalAllModels(
  lst_subdata,
  lst_subdata_models,
  lst_evaluations,
  pred.attr = "mean",
  times = NULL,
  max_time_points = 15,
  PARALLEL = T,
  progress_bar = F
)
}
\arguments{
\item{lst_subdata}{List of data}

\item{lst_subdata_models}{List of model per each data}

\item{lst_evaluations}{List of which evaluators to use: "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I", "risksetROC"}

\item{pred.attr}{Evaluate by "mean" or "median"}

\item{times}{Time points to evaluate. If NULL, they will be compute automaticatly.}

\item{max_time_points}{Maximum number of time points to compute.}

\item{PARALLEL}{Use multicore option.}

\item{progress_bar}{Show progress bar.}
}
\description{
super.evalAllModels
}
