% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/HDcox_plot_functions.R
\name{plot_LP.multiplePatients.list}
\alias{plot_LP.multiplePatients.list}
\title{plot_LP.multiplePatients.list}
\usage{
plot_LP.multiplePatients.list(
  lst_models,
  df.pat,
  error.bar = F,
  onlySig = T,
  alpha = 0.05,
  zero.rm = T,
  auto.limits = T,
  top = NULL
)
}
\arguments{
\item{lst_models}{List HDcox models}

\item{df.pat}{Dataframe of observations}

\item{error.bar}{Show error bar.}

\item{onlySig}{Show only significant variables.}

\item{alpha}{Significant value.}

\item{zero.rm}{Remove variables equal to 0.}

\item{auto.limits}{Logical. If TRUE, limits are detected for a better plot.}

\item{top}{Number. Show top variables.}
}
\description{
plot_LP.multiplePatients.list
}
