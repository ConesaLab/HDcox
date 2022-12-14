% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/HDcox_cox.R
\name{cox}
\alias{cox}
\title{cox}
\usage{
cox(
  X,
  Y,
  x.center = TRUE,
  x.scale = FALSE,
  y.center = FALSE,
  y.scale = FALSE,
  remove_near_zero_variance = T,
  remove_zero_variance = F,
  toKeep.zv = NULL,
  remove_non_significant = F,
  alpha = 0.05,
  MIN_EPV = 5,
  FORCE = F,
  returnData = T,
  verbose = F
)
}
\arguments{
\item{X}{Numeric matrix. Predictor variables}

\item{Y}{Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.}

\item{x.center}{Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).}

\item{x.scale}{Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).}

\item{y.center}{Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).}

\item{y.scale}{Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).}

\item{remove_near_zero_variance}{Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.}

\item{remove_zero_variance}{Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.}

\item{toKeep.zv}{Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.}

\item{remove_non_significant}{Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).}

\item{alpha}{Numeric. Cutoff for establish significant variables. Below the number are considered as significant (default: 0.05).}

\item{MIN_EPV}{Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.}

\item{FORCE}{Logical. In case the MIN_EPV is not meet, it allows to compute the model (default: FALSE).}

\item{returnData}{Logical. Return original and normalized X and Y matrices.}

\item{verbose}{Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).}
}
\value{
Instance of class "HDcox" and model "cox". The class contains the following elements:

\code{X}: List of normalized X data information.
\itemize{
\item \code{(data)}: normalized X matrix
\item \code{(x.mean)}: mean values for X matrix
\item \code{(x.sd)}: standard deviation for X matrix
}
\code{Y}: List of normalized Y data information.
\itemize{
\item \code{(data)}: normalized Y matrix
\item \code{(y.mean)}: mean values for Y matrix
\item \code{(y.sd)}: standard deviation for Y matrix
}
\code{survival_model}: List of survival model information
\itemize{
\item \code{fit}: coxph object.
\item \code{AIC}: AIC of cox model.
\item \code{BIC}: BIC of cox model.
\item \code{lp}: linear predictors for train data.
\item \code{coef}: Coefficients for cox model.
\item \code{YChapeau}: Y Chapeau residuals.
\item \code{Yresidus}: Y residuals.
}
\code{call}: call function

\code{X_input}: X input matrix

\code{Y_input}: Y input matrix

\code{nsv}: Variables removed by remove_non_significant if any.

\code{nzv}: Variables removed by remove_near_zero_variance or remove_zero_variance.

\code{time}: time consumed for running the cox analysis.
}
\description{
Performs a standard cox model (based on survival::coxph R package).
}
\examples{
\dontrun{
cox(X, Y)
cox(X, Y, x.center = TRUE, x.scale = TRUE)
}
}
