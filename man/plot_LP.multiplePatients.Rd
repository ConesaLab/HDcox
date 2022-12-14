% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/HDcox_plot_functions.R
\name{plot_LP.multiplePatients}
\alias{plot_LP.multiplePatients}
\title{plot_LP.multiplePatients}
\usage{
plot_LP.multiplePatients(
  model,
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
\item{model}{HDcox models}

\item{df.pat}{Dataframe of observations}

\item{error.bar}{Show error bar.}

\item{onlySig}{Show only significant variables.}

\item{alpha}{Significant value.}

\item{zero.rm}{Remove variables equal to 0.}

\item{auto.limits}{Logical. If TRUE, limits are detected for a better plot.}

\item{top}{Number. Show top variables.}
}
\description{
plot_LP.multiplePatients
}
