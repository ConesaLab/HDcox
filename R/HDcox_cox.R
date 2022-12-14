#### ### ##
# METHODS #
#### ### ##

#' cox
#' @description Performs a standard cox model (based on survival::coxph R package).
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param x.center Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).
#' @param x.scale Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).
#' @param y.center Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).
#' @param y.scale Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).
#' @param remove_near_zero_variance Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.
#' @param remove_zero_variance Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.
#' @param toKeep.zv Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.
#' @param remove_non_significant Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param alpha Numeric. Cutoff for establish significant variables. Below the number are considered as significant (default: 0.05).
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param FORCE Logical. In case the MIN_EPV is not meet, it allows to compute the model (default: FALSE).
#' @param returnData Logical. Return original and normalized X and Y matrices.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#'
#' @return Instance of class "HDcox" and model "cox". The class contains the following elements:
#'
#' \code{X}: List of normalized X data information.
#' \itemize{
#'  \item \code{(data)}: normalized X matrix
#'  \item \code{(x.mean)}: mean values for X matrix
#'  \item \code{(x.sd)}: standard deviation for X matrix
#'  }
#' \code{Y}: List of normalized Y data information.
#' \itemize{
#'  \item \code{(data)}: normalized Y matrix
#'  \item \code{(y.mean)}: mean values for Y matrix
#'  \item \code{(y.sd)}: standard deviation for Y matrix
#'  }
#' \code{survival_model}: List of survival model information
#' \itemize{
#'  \item \code{fit}: coxph object.
#'  \item \code{AIC}: AIC of cox model.
#'  \item \code{BIC}: BIC of cox model.
#'  \item \code{lp}: linear predictors for train data.
#'  \item \code{coef}: Coefficients for cox model.
#'  \item \code{YChapeau}: Y Chapeau residuals.
#'  \item \code{Yresidus}: Y residuals.
#' }
#' \code{call}: call function
#'
#' \code{X_input}: X input matrix
#'
#' \code{Y_input}: Y input matrix
#'
#' \code{nsv}: Variables removed by remove_non_significant if any.
#'
#' \code{nzv}: Variables removed by remove_near_zero_variance or remove_zero_variance.
#'
#' \code{time}: time consumed for running the cox analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' cox(X, Y)
#' cox(X, Y, x.center = TRUE, x.scale = TRUE)
#' }

cox <- function (X, Y,
                 x.center = TRUE, x.scale = FALSE,
                 y.center = FALSE, y.scale = FALSE,
                 remove_near_zero_variance = T, remove_zero_variance = F, toKeep.zv = NULL,
                 remove_non_significant = F, alpha = 0.05,
                 MIN_EPV = 5, FORCE = F, returnData = T, verbose = F){


  t1 <- Sys.time()

  #### Original data
  X_original <- X
  Y_original <- Y

  time <- Y[,"time"]
  event <- Y[,"event"]

  #### REQUIREMENTS
  ## should be a data.frame
  if(class(X)[1]!="data.frame" & class(X)[1]=="matrix"){
    X <- as.data.frame(X)
  }
  if(class(Y)[1]!="data.frame" & class(Y)[1]=="matrix"){
    Y <- as.data.frame(Y)
  }

  #### ZERO VARIANCE - ALWAYS
  lst_dnz <- deleteZeroOrNearZeroVariance(X = X,
                                          remove_near_zero_variance = remove_near_zero_variance,
                                          remove_zero_variance = remove_zero_variance,
                                          toKeep.zv = toKeep.zv,
                                          freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  #colnames Y
  checkY.colnames(Y)

  #### MAX PREDICTORS
  check.maxPredictors.cox(X, Y, MIN_EPV, FORCE)

  #### SCALING
  lst_scale <- XY.scale(X, Y, x.center, x.scale, y.center, y.scale)
  Xh <- lst_scale$Xh
  Yh <- lst_scale$Yh
  xmeans <- lst_scale$xmeans
  xsds <- lst_scale$xsds
  ymeans <- lst_scale$ymeans
  ysds <- lst_scale$ysds

  X_norm <- Xh

  #### INITIALISING VARIABLES
  d <- as.data.frame(cbind(Xh, Yh)) #data
  best_cox <- tryCatch(
    # Specifying expression
    expr = {
      survival::coxph(formula = survival::Surv(time,event) ~ .,
                      data = d,
                      ties = "efron",
                      singular.ok = T,
                      robust = T,
                      nocenter = rep(1, ncol(Xh)),
                      model=T)
    },
    # Specifying error message
    error = function(e){
      message(paste0("COX: ", e))
      invisible(gc())
      return(NA)
    }
  )

  cox_trycatch <- function(X){
    tryCatch(
      # Specifying expression
      expr = {
        survival::coxph(formula = survival::Surv(time,event) ~ .,
                        data = X,
                        ties = "efron",
                        singular.ok = T,
                        robust = T,
                        nocenter = rep(1, ncol(X)-2),
                        model=T)
      },
      # Specifying error message
      error = function(e){
        message(paste0("COX: ", e))
        invisible(gc())
        return(NA)
      }
    )
  }

  if(all(is.na(best_cox))){
    # Probably by "data contains an infinite predictor"
    message("It is possible that your data has NAs. Cox algorithm cannot manage NAs. Try to clean the data.")
    # lst_cox_uni <- purrr::map(colnames(Xh), ~cox_trycatch(as.data.frame(cbind(Xh[,.], Yh))))
    # names(lst_cox_uni) = colnames(Xh)
    t2 <- Sys.time()
    time <- difftime(t2,t1,units = "mins")

    func_call <- match.call()

    invisible(gc())
    return(cox_class(list(X = list("data" = if(returnData) Xh else NA, "x.mean" = xmeans, "x.sd" = xsds),
                          Y = list("data" = Yh, "y.mean" = ymeans, "y.sd" = ysds),
                          survival_model = NULL,
                          call = func_call,
                          X_input = if(returnData) X_original else NA,
                          Y_input = if(returnData) Y_original else NA,
                          nsv = NULL,
                          nzv = variablesDeleted,
                          class = pkg.env$cox,
                          time = time)))
  }

  # RETURN a MODEL with ALL significant Variables from complete, deleting one by one
  removed_variables <- NULL

  # REMOVE NA-PVAL VARIABLES
  # p_val could be NA for some variables (if NA change to P-VAL=1)
  # DO IT ALWAYS, we do not want problems in COX models
  p_val <- summary(best_cox)[[7]][,"Pr(>|z|)"]
  while(sum(is.na(p_val))>0){
    to_remove <- names(p_val)[is.na(p_val)]
    to_remove <- deleteIllegalChars(to_remove)
    d <- d[,!colnames(d) %in% c(to_remove)]
    best_cox <- tryCatch(
      # Specifying expression
      expr = {
        survival::coxph(formula = survival::Surv(time,event) ~ .,
                        data = d,
                        ties = "efron",
                        singular.ok = T,
                        robust = T,
                        nocenter = rep(1, ncol(d)-ncol(Yh)),
                        model=T)
      },
      # Specifying error message
      error = function(e){
        message(paste0("COX: ", e))
        invisible(gc())
        return(NA)
      }
    )

    removed_variables <- c(removed_variables, to_remove)
    p_val <- summary(best_cox)[[7]][,"Pr(>|z|)"]
  }

  if(remove_non_significant){
    p_val <- summary(best_cox)[[7]][,"Pr(>|z|)"]
    # p_val could be NA for some variables (if NA change to P-VAL=1)
    # should not happen, but just in case new models generate NAs
    if(length(is.na(p_val))>0){
      p_val[is.na(p_val)] = 1
    }

    while(any(p_val>alpha) & length(p_val)>1){ # keep at least one variable even if the variable is not significant
      to_remove <- names(which.max(p_val))
      to_remove <- deleteIllegalChars(to_remove)
      d <- d[,!colnames(d) %in% c(to_remove)]
      best_cox <- tryCatch(
        # Specifying expression
        expr = {
          survival::coxph(formula = survival::Surv(time,event) ~ .,
                          data = d,
                          ties = "efron",
                          singular.ok = T,
                          robust = T,
                          nocenter = rep(1, ncol(d)-ncol(Yh)),
                          model=T)
        },
        # Specifying error message
        error = function(e){
          message(paste0("COX: ", e))
          invisible(gc())
          return(NA)
        }
      )

      removed_variables <- c(removed_variables, to_remove)
      p_val <- summary(best_cox)[[7]][,"Pr(>|z|)"]
    }
  }

  while(any(is.na(best_cox$coefficients))){ #if any NA
    to_remove <- names(best_cox$coefficients)[is.na(best_cox$coefficients)]
    d <- d[,!colnames(d) %in% c(to_remove)]
    best_cox <- tryCatch(
      # Specifying expression
      expr = {
        survival::coxph(formula = survival::Surv(time,event) ~ .,
                        data = d,
                        ties = "efron",
                        singular.ok = T,
                        robust = T,
                        nocenter = rep(1, ncol(d)-ncol(Yh)),
                        model=T)
      },
      # Specifying error message
      error = function(e){
        message(paste0("COX: ", e))
        invisible(gc())
        return(NA)
      }
    )
    removed_variables <- c(removed_variables, to_remove)
  }

  if(class(best_cox)=="coxph"){
    survival_model <- getInfoCoxModel(best_cox)
  }else{
    survival_model <- NULL
  }

  func_call <- match.call()

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  return(cox_class(list(X = list("data" = if(returnData) Xh else NA, "x.mean" = xmeans, "x.sd" = xsds),
                        Y = list("data" = Yh, "y.mean" = ymeans, "y.sd" = ysds),
                        survival_model = survival_model,
                        call = func_call,
                        X_input = if(returnData) X_original else NA,
                        Y_input = if(returnData) Y_original else NA,
                        nsv = removed_variables,
                        nzv = variablesDeleted,
                        class = pkg.env$cox,
                        time = time)))
}


### ## ##
# CLASS #
### ## ##

cox_class = function(cox_model, ...) {
  model = structure(cox_model, class = pkg.env$model_class,
                    model = pkg.env$cox)
  return(model)
}
