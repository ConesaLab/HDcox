% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/HDcox_common_functions.R
\name{getLPforNewPatient}
\alias{getLPforNewPatient}
\title{getLPforNewPatient}
\usage{
getLPforNewPatient(model, new_pat, time = NULL, type = "lp", method = "cox")
}
\arguments{
\item{model}{HDcox model}

\item{new_pat}{New patient row (raw data)}

\item{time}{Time point for predicting Expected or Survival probability}

\item{type}{Prediction type: 'lp', 'risk', 'expected' or 'survival'.}

\item{method}{Prediction by cox model 'cox' or using W.star 'W.star' (not implemented for MB approaches)}
}
\value{
Return the lp or other metric for the patient
}
\description{
getLPforNewPatient
}
