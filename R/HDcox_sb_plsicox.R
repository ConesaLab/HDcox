#### ### ##
# METHODS #
#### ### ##

#' SB.PLS-ICOX
#' @description Performs a SB.PLS-ICOX model.
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param n.comp Numeric. Number of principal components to compute in the PLS model.
#' @param x.center Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).
#' @param x.scale Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).
#' @param y.center Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).
#' @param y.scale Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).
#' @param remove_near_zero_variance Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.
#' @param remove_zero_variance Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.
#' @param toKeep.zv Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.
#' @param remove_non_significant Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param returnData Logical. Return original and normalized X and Y matrices.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#'
#' @return Instance of class "HDcox" and model "sb.plsicox". The class contains the following elements:
#' \code{X}: List of normalized X data information.
#' \itemize{
#'  \item \code{(data)}: normalized X matrix
#'  \item \code{(weightings)}: PLS weights
#'  \item \code{(weightings_norm)}: PLS normalize weights
#'  \item \code{(W.star)}: PLS W* vector
#'  \item \code{(scores)}: PLS scores/variates
#'  \item \code{(x.mean)}: mean values for X matrix
#'  \item \code{(x.sd)}: standard deviation for X matrix
#'  }
#' \code{Y}: List of normalized Y data information.
#' \itemize{
#'  \item \code{(deviance_residuals)}: deviance residual vector used as Y matrix in the sPLS.
#'  \item \code{(dr.mean)}: mean values for deviance residuals Y matrix
#'  \item \code{(dr.sd)}: standard deviation for deviance residuals Y matrix'
#'  \item \code{(data)}: normalized X matrix
#'  \item \code{(y.mean)}: mean values for Y matrix
#'  \item \code{(y.sd)}: standard deviation for Y matrix'
#'  }
#' \code{survival_model}: List of survival model information.
#' \itemize{
#'  \item \code{fit}: coxph object.
#'  \item \code{AIC}: AIC of cox model.
#'  \item \code{BIC}: BIC of cox model.
#'  \item \code{lp}: linear predictors for train data.
#'  \item \code{coef}: Coefficients for cox model.
#'  \item \code{YChapeau}: Y Chapeau residuals.
#'  \item \code{Yresidus}: Y residuals.
#' }
#'
#' \code{list_pls_models}: List of PLS-ICOX models computed for each block.
#'
#' \code{n.comp}: Number of components selected.
#'
#' \code{call}: call function
#'
#' \code{X_input}: X input matrix
#'
#' \code{Y_input}: Y input matrix
#'
#' \code{nzv}: Variables removed by remove_near_zero_variance or remove_zero_variance.
#'
#' \code{time}: time consumed for running the cox analysis.
#'
#' @export

sb.plsicox <- function (X, Y,
                        n.comp = 4,
                        x.center = TRUE, x.scale = FALSE,
                        y.center = FALSE, y.scale = FALSE,
                        remove_near_zero_variance = T, remove_zero_variance = T, toKeep.zv = NULL,
                        remove_non_significant = F,
                        MIN_EPV = 5, returnData = T, verbose = F){

  t1 <- Sys.time()

  #### Original data
  X_original <- X
  Y_original <- Y

  time <- Y[,"time"]
  event <- Y[,"event"]

  #### REQUIREMENTS
  lst_check <- checkXY.mb.class(X, Y, verbose = verbose)
  X <- lst_check$X
  Y <- lst_check$Y

  checkY.colnames(Y)

  #### ZERO VARIANCE - ALWAYS
  lst_dnz <- deleteZeroOrNearZeroVariance.mb(X = X,
                                            remove_near_zero_variance = remove_near_zero_variance,
                                            remove_zero_variance = remove_zero_variance,
                                            toKeep.zv = toKeep.zv,
                                            freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  #### SCALING
  lst_scale <- XY.mb.scale(X, Y, x.center, x.scale, y.center, y.scale)
  Xh <- lst_scale$Xh
  Yh <- lst_scale$Yh
  xmeans <- lst_scale$xmeans
  xsds <- lst_scale$xsds
  ymeans <- lst_scale$ymeans
  ysds <- lst_scale$ysds

  X_norm <- Xh

  ####MAX PREDICTORS
  n.comp <- check.mb.maxPredictors(X, Y, MIN_EPV, n.comp, verbose = verbose)

  # CREATE INDIVIDUAL MODELS
  lst_sb.pls <- list()
  for(b in names(Xh)){
    lst_sb.pls[[b]] <- plsicox(X = Xh[[b]], Y = Yh, n.comp = n.comp,
                                x.scale = F, x.center = F, y.scale = F, y.center = F,
                                remove_near_zero_variance = F, remove_zero_variance = F, toKeep.zv = NULL, #zero_var already checked
                                returnData = F, verbose = verbose)
  }

  # CHECK ALL MODELS SAME COMPONENTS
  aux_ncomp <- purrr::map(lst_sb.pls, ~.$n.comp)

  # CREATE COMBINE MODEL
  data <- NULL
  cn.merge <- NULL
  for(b in names(Xh)){
    data <- cbind(data, lst_sb.pls[[b]]$X$scores)
    cn.merge <- c(cn.merge, paste0(colnames(lst_sb.pls[[b]]$X$scores), "_", b))
  }

  #colnames(data) <- apply(expand.grid(colnames(lst_sb.pls[[1]]$X$scores), names(Xh)), 1, paste, collapse="_")
  colnames(data) <- cn.merge
  cox_model <- cox(X = data, Y = Yh,
                   x.center = F, x.scale = F,
                   y.center = F, y.scale = F,
                   remove_near_zero_variance = F, remove_zero_variance = F,
                   remove_non_significant = remove_non_significant, FORCE = T)

  ##########
  # RETURN #
  ##########
  func_call <- match.call()

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  return(sb.plsicox_class(list(X = list("data" = if(returnData) X_norm else NA, "x.mean" = xmeans, "x.sd" = xsds),
                                Y = list("data" = lst_sb.pls[[1]]$Y$data, "y.mean" = ymeans, "y.sd" = ysds),
                                survival_model = cox_model$survival_model,
                                list_pls_models = lst_sb.pls,
                                n.comp = n.comp, #number of components used, but could be lesser than expected because not computed models
                                call = func_call,
                                X_input = if(returnData) X_original else NA,
                                Y_input = if(returnData) Y_original else NA,
                                nzv = variablesDeleted,
                                class = pkg.env$sb.plsicox,
                                time = time)))
}

#### ### ### ### ###
# CROSS-EVALUATION #
#### ### ### ### ###

#' Cross validation cv.sb.plsicox
#' @description cv.sb.plsicox cross validation model
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param max.ncomp Numeric. Maximum number of PLS components to compute for the cross validation.
#' @param n_run Number. Number of runs for cross validation.
#' @param k_folds Number. Number of folds for cross validation.
#' @param x.center Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).
#' @param x.scale Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).
#' @param y.center Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).
#' @param y.scale Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).
#' @param remove_near_zero_variance Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.
#' @param remove_zero_variance Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.
#' @param toKeep.zv Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.
#' @param remove_non_significant_models Logical. If remove_non_significant_models = TRUE, non-significant models are removed before computing the evaluation.
#' @param remove_non_significant Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param alpha Numeric. Cutoff for establish significant variables. Below the number are considered as significant (default: 0.05).
#' @param w_AIC Numeric. Weight for AIC evaluator. All three weights must sum 1 (default: 0).
#' @param w_c.index Numeric. Weight for C-Index evaluator. All three weights must sum 1 (default: 0).
#' @param w_AUC Numeric. Weight for AUC evaluator. All three weights must sum 1 (default: 1).
#' @param times Numeric vector. Time points where the AUC will be evaluated. If NULL, a maximum of 15 points will be selected equally distributed.
#' @param MIN_AUC_INCREASE Numeric. Minimum improvement between different EN.alpha.list to continue evaluating. If not reached for the next MIN_COMP_TO_CHECK penalties and the minimum MIN_AUC is reach, the evaluation stop.
#' @param MIN_AUC Numeric. Minimum AUC desire.
#' @param MIN_COMP_TO_CHECK Numeric. Number of penalties to check whether the AUC improves.
#' @param pred.attr Character. Method for average the AUC. Must be one of the following: "mean" or "median" (default: "mean").
#' @param pred.method Character. AUC method for evaluation. Must be one of the following: "risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I" (default: "cenROC")
#' @param fast_mode Logical. If fast_mode = TRUE, for each run, only one fold is evaluated simultaneously. If fast_mode = FALSE, for each run, all linear predictors are computed for test observations. Once all have their linear predictors, the evaluation is perform across all the observations together (default: FALSE).
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param return_models Logical. Return all models computed in cross validation.
#' @param PARALLEL Logical. Run the cross validation with multicore option. As many cores as your total cores - 1 will be used. It could lead to higher RAM consumption.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#' @param seed Number. Seed value for perform the runs/folds divisions.
#'
#' @return Instance of class "HDcox" and model "cv.SB.PLS-ICOX".
#' @export

cv.sb.plsicox <- function(X, Y,
                          max.ncomp = 10, n_run = 10, k_folds = 10,
                          x.center = TRUE, x.scale = FALSE,
                          y.center = FALSE, y.scale = FALSE,
                          remove_near_zero_variance = T, remove_zero_variance = T, toKeep.zv = NULL,
                          remove_non_significant_models = F, remove_non_significant = F, alpha = 0.05,
                          w_AIC = 0,  w_c.index = 0, w_AUC = 1, times = NULL,
                          MIN_AUC_INCREASE = 0.01, MIN_AUC = 0.8, MIN_COMP_TO_CHECK = 3,
                          pred.attr = "mean", pred.method = "cenROC", fast_mode = F,
                          MIN_EPV = 5, return_models = F,
                          PARALLEL = F, verbose = F, seed = 123){

  t1 <- Sys.time()

  ############
  # WARNINGS #
  ############

  #Check evaluator installed:
  checkLibraryEvaluator(pred.method)

  #### REQUIREMENTS
  checkY.colnames(Y)
  check.cv.weights(c(w_AIC, w_c.index, w_AUC))
  # if(!pred.method %in% c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I")){
  #   stop_quietly(paste0("pred.method must be one of the following: ", paste0(c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I"), collapse = ", ")))
  # }
  if(!pred.method %in% pkg.env$AUC_evaluators){
    stop_quietly(paste0("pred.method must be one of the following: ", paste0(pkg.env$AUC_evaluators, collapse = ", ")))
  }

  #### ZERO VARIANCE - ALWAYS
  lst_dnz <- deleteZeroOrNearZeroVariance.mb(X = X,
                                            remove_near_zero_variance = remove_near_zero_variance,
                                            remove_zero_variance = remove_zero_variance,
                                            toKeep.zv = toKeep.zv,
                                            freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  max.ncomp <- check.mb.ncomp(X, max.ncomp)

  ####MAX PREDICTORS
  max.ncomp <- check.mb.maxPredictors(X, Y, MIN_EPV, max.ncomp, verbose = verbose)

  ######
  # CV #
  ######
  set.seed(seed)
  lst_data <- splitData_Iterations_Folds.mb(X, Y, n_run = n_run, k_folds = k_folds) #FOR TEST
  lst_X_train <- lst_data$lst_X_train
  lst_Y_train <- lst_data$lst_Y_train
  lst_X_test <- lst_data$lst_X_test
  lst_Y_test <- lst_data$lst_Y_test

  ################
  # TRAIN MODELS #
  ################
  #total_models <- 1 * k_folds * n_run
  total_models <- max.ncomp * k_folds * n_run

  lst_model <- get_HDCOX_models2.0(method = pkg.env$sb.plsicox,
                                   lst_X_train = lst_X_train, lst_Y_train = lst_Y_train,
                                   max.ncomp = max.ncomp, eta.list = NULL, EN.alpha.list = NULL,
                                   n_run = n_run, k_folds = k_folds,
                                   remove_near_zero_variance = F, remove_zero_variance = F, toKeep.zv = NULL,
                                   remove_non_significant = remove_non_significant,
                                   x.center = x.center, x.scale = x.scale, y.center = y.center, y.scale = y.scale,
                                   total_models = total_models, PARALLEL = PARALLEL, verbose = verbose)

  # lst_model <- get_HDCOX_models(method = pkg.env$sb.plsicox,
  #                               lst_X_train = lst_X_train, lst_Y_train = lst_Y_train,
  #                               max.ncomp = max.ncomp, eta.list = NULL, EN.alpha.list = NULL,
  #                               n_run = n_run, k_folds = k_folds,
  #                               x.center = x.center, x.scale = x.scale, y.center = y.center, y.scale = y.scale,
  #                               total_models = total_models)

  ##########################
  # BEST MODEL FOR CV DATA #
  ##########################
  total_models <- max.ncomp * k_folds * n_run
  df_results_evals <- get_COX_evaluation_AIC_CINDEX(comp_model_lst = lst_model,
                                                    max.ncomp = max.ncomp, eta.list = NULL, n_run = n_run, k_folds = k_folds,
                                                    total_models = total_models, remove_non_significant_models = remove_non_significant_models)

  if(all(is.null(df_results_evals))){
    message(paste0("Best model could NOT be obtained. All models computed present problems."))

    t2 <- Sys.time()
    time <- difftime(t2,t1,units = "mins")
    if(return_models){
      return(cv.sb.plsicox_class(list(best_model_info = NULL, df_results_folds = NULL, df_results_runs = NULL, df_results_comps = NULL, lst_models = lst_model, pred.method = pred.method, opt.comp = NULL, plot_AUC = NULL, plot_c_index = NULL, plot_AIC = NULL, time = time)))
    }else{
      return(cv.sb.plsicox_class(list(best_model_info = NULL, df_results_folds = NULL, df_results_runs = NULL, df_results_comps = NULL, lst_models = NULL, pred.method = pred.method, opt.comp = NULL, plot_AUC = NULL, plot_c_index = NULL, plot_AIC = NULL, time = time)))
    }
  }

  ##################
  # EVALUATING AUC #
  ##################
  df_results_evals_comp <- NULL
  df_results_evals_run <- NULL
  df_results_evals_fold <- NULL
  optimal_comp_index <- NULL
  optimal_eta_index <- NULL
  optimal_eta <- NULL
  optimal_comp_flag <- NULL

  if(w_AUC!=0){
    total_models <- ifelse(!fast_mode, n_run * max.ncomp, k_folds * n_run * max.ncomp)

    lst_df <- get_COX_evaluation_AUC(comp_model_lst = lst_model,
                                         lst_X_test = lst_X_test, lst_Y_test = lst_Y_test,
                                         df_results_evals = df_results_evals, times = times,
                                         fast_mode = fast_mode, pred.method = pred.method, pred.attr = pred.attr,
                                         max.ncomp = max.ncomp, n_run = n_run, k_folds = k_folds,
                                         MIN_AUC_INCREASE = MIN_AUC_INCREASE, MIN_AUC = MIN_AUC, MIN_COMP_TO_CHECK = MIN_COMP_TO_CHECK,
                                         w_AUC = w_AUC, total_models = total_models, method.train = pkg.env$sb.plsicox, PARALLEL = F)

    df_results_evals_comp <- lst_df$df_results_evals_comp
    df_results_evals_run <- lst_df$df_results_evals_run
    df_results_evals_fold <- lst_df$df_results_evals_fold
    optimal_comp_index <- lst_df$optimal_comp_index
    optimal_comp_flag <- lst_df$optimal_comp_flag
    optimal_eta <- lst_df$optimal_eta
    optimal_eta_index <- lst_df$optimal_eta_index
  }else{
    df_results_evals_fold <- df_results_evals
  }

  ##############
  # BEST MODEL #
  ##############

  df_results_evals_comp <- cv.getScoreFromWeight(df_results_evals_comp, w_AIC, w_c.index, w_AUC,
                                                 colname_AIC = "AIC", colname_c_index = "c_index", colname_AUC = "AUC")

  if(optimal_comp_flag){
    best_model_info <- df_results_evals_comp[df_results_evals_comp[,"n.comps"]==optimal_comp_index,, drop=F][1,]
    best_model_info <- as.data.frame(best_model_info)
  }else{
    best_model_info <- df_results_evals_comp[which(df_results_evals_comp[,"score"] == max(df_results_evals_comp[,"score"], na.rm = T)),, drop=F][1,]
    best_model_info <- as.data.frame(best_model_info)
  }

  ########
  # PLOT #
  ########
  lst_EVAL_PLOTS <- get_EVAL_PLOTS(fast_mode = fast_mode, best_model_info = best_model_info, w_AUC = w_AUC, max.ncomp = max.ncomp, eta.list = NULL,
                                   df_results_evals_fold = df_results_evals_fold, df_results_evals_run = df_results_evals_run, df_results_evals_comp = df_results_evals_comp,
                                   colname_AIC = "AIC", colname_c_index = "c_index", colname_AUC = "AUC", x.text = "Component")

  ggp_AUC <- lst_EVAL_PLOTS$ggp_AUC
  ggp_c_index <- lst_EVAL_PLOTS$ggp_c_index
  ggp_AIC <- lst_EVAL_PLOTS$ggp_AIC

  df_results_evals_comp <- lst_EVAL_PLOTS$df_results_evals_comp

  ##########
  # RETURN #
  ##########

  message(paste0("Best model obtained.\n"))

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  if(return_models){
    return(cv.sb.plsicox_class(list(best_model_info = best_model_info, df_results_folds = df_results_evals_fold, df_results_runs = df_results_evals_run, df_results_comps = df_results_evals_comp, lst_models = lst_model, pred.method = pred.method, opt.comp = best_model_info$n.comps, plot_AUC = ggp_AUC, plot_c_index = ggp_c_index, plot_AIC = ggp_AIC, time = time)))
  }else{
    return(cv.sb.plsicox_class(list(best_model_info = best_model_info, df_results_folds = df_results_evals_fold, df_results_runs = df_results_evals_run, df_results_comps = df_results_evals_comp, lst_models = NULL, pred.method = pred.method, opt.comp = best_model_info$n.comps, plot_AUC = ggp_AUC, plot_c_index = ggp_c_index, plot_AIC = ggp_AIC, time = time)))
  }
}

#' Cross validation fast.cv.sb.plsicox
#' @description fast.cv.sb.plsicox cross validation model
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param max.ncomp Numeric. Maximum number of PLS components to compute for the cross validation.
#' @param n_run Number. Number of runs for cross validation.
#' @param k_folds Number. Number of folds for cross validation.
#' @param x.center Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).
#' @param x.scale Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).
#' @param y.center Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).
#' @param y.scale Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).
#' @param remove_near_zero_variance Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.
#' @param remove_zero_variance Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.
#' @param toKeep.zv Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.
#' @param remove_non_significant_models Logical. If remove_non_significant_models = TRUE, non-significant models are removed before computing the evaluation.
#' @param remove_non_significant Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param alpha Numeric. Cutoff for establish significant variables. Below the number are considered as significant (default: 0.05).
#' @param w_AIC Numeric. Weight for AIC evaluator. All three weights must sum 1 (default: 0).
#' @param w_c.index Numeric. Weight for C-Index evaluator. All three weights must sum 1 (default: 0).
#' @param w_AUC Numeric. Weight for AUC evaluator. All three weights must sum 1 (default: 1).
#' @param times Numeric vector. Time points where the AUC will be evaluated. If NULL, a maximum of 15 points will be selected equally distributed.
#' @param MIN_AUC_INCREASE Numeric. Minimum improvement between different EN.alpha.list to continue evaluating. If not reached for the next MIN_COMP_TO_CHECK penalties and the minimum MIN_AUC is reach, the evaluation stop.
#' @param MIN_AUC Numeric. Minimum AUC desire.
#' @param MIN_COMP_TO_CHECK Numeric. Number of penalties to check whether the AUC improves.
#' @param pred.attr Character. Method for average the AUC. Must be one of the following: "mean" or "median" (default: "mean").
#' @param pred.method Character. AUC method for evaluation. Must be one of the following: "risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I" (default: "cenROC")
#' @param fast_mode Logical. If fast_mode = TRUE, for each run, only one fold is evaluated simultaneously. If fast_mode = FALSE, for each run, all linear predictors are computed for test observations. Once all have their linear predictors, the evaluation is perform across all the observations together (default: FALSE).
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param returnData Logical. Return original and normalized X and Y matrices.
#' @param return_models Logical. Return all models computed in cross validation.
#' @param PARALLEL Logical. Run the cross validation with multicore option. As many cores as your total cores - 1 will be used. It could lead to higher RAM consumption.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#' @param seed Number. Seed value for perform the runs/folds divisions.
#'
#' @return Instance of class "HDcox" and model "SB.PLS-ICOX".
#' @export

fast.cv.sb.plsicox <- function(X, Y,
                               max.ncomp = 10, n_run = 10, k_folds = 10,
                               x.center = TRUE, x.scale = FALSE,
                               y.center = FALSE, y.scale = FALSE,
                               remove_near_zero_variance = T, remove_zero_variance = T, toKeep.zv = NULL,
                               remove_non_significant_models = F, remove_non_significant = F, alpha = 0.05,
                               w_AIC = 0,  w_c.index = 0, w_AUC = 1, times = NULL,
                               MIN_AUC_INCREASE = 0.01, MIN_AUC = 0.8, MIN_COMP_TO_CHECK = 3,
                               pred.attr = "mean", pred.method = "cenROC", fast_mode = F,
                               MIN_EPV = 5, returnData = T, return_models = F,
                               PARALLEL = F, verbose = F, seed = 123){

  t1 <- Sys.time()

  #### REQUIREMENTS
  checkY.colnames(Y)
  check.cv.weights(c(w_AIC, w_c.index, w_AUC))
  max.ncomp <- check.mb.ncomp(X, max.ncomp)
  # if(!pred.method %in% c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I")){
  #   stop_quietly(paste0("pred.method must be one of the following: ", paste0(c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I"), collapse = ", ")))
  # }
  if(!pred.method %in% pkg.env$AUC_evaluators){
    stop_quietly(paste0("pred.method must be one of the following: ", paste0(pkg.env$AUC_evaluators, collapse = ", ")))
  }

  #### Original data
  X_original <- X
  Y_original <- Y

  time <- Y[,"time"]
  event <- Y[,"event"]

  #### REQUIREMENTS
  lst_check <- checkXY.mb.class(X, Y, verbose = verbose)
  X <- lst_check$X
  Y <- lst_check$Y

  checkY.colnames(Y)

  #### SCALE
  if(length(x.center)==1){
    x.center <- rep(x.center, length(names(X)))
    names(x.center) <- names(X)
  }
  if(length(x.scale)==1){
    x.scale <- rep(x.scale, length(names(X)))
    names(x.scale) <- names(X)
  }

  #### ZERO VARIANCE - ALWAYS
  lst_dnz <- deleteZeroOrNearZeroVariance.mb(X = X,
                                            remove_near_zero_variance = remove_near_zero_variance,
                                            remove_zero_variance = remove_zero_variance,
                                            toKeep.zv = toKeep.zv,
                                            freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  #### SCALING
  lst_scale <- XY.mb.scale(X, Y, x.center, x.scale, y.center, y.scale)
  Xh <- lst_scale$Xh
  Yh <- lst_scale$Yh
  xmeans <- lst_scale$xmeans
  xsds <- lst_scale$xsds
  ymeans <- lst_scale$ymeans
  ysds <- lst_scale$ysds

  X_norm <- Xh

  ####MAX PREDICTORS
  max.ncomp <- check.mb.maxPredictors(X, Y, MIN_EPV, max.ncomp, verbose = verbose)

  # CREATE INDIVIDUAL MODELS
  lst_sb.pls <- list()
  for(b in names(Xh)){

    message(paste0("Running cross validation PLS-ICOX for block: ", b, "\n"))

    cv.splsdrcox_res <- cv.plsicox(X = Xh[[b]], Y = Yh,
                                   max.ncomp = max.ncomp,
                                   n_run = n_run, k_folds = k_folds, alpha = alpha, remove_non_significant_models = remove_non_significant_models,
                                   w_AIC = w_AIC, w_c.index = w_c.index, w_AUC = w_AUC, times = times,
                                   MIN_AUC_INCREASE = MIN_AUC_INCREASE, MIN_AUC = MIN_AUC, MIN_COMP_TO_CHECK = MIN_COMP_TO_CHECK,
                                   x.scale = x.scale[[b]], x.center = x.center[[b]], y.scale = y.scale, y.center = y.center,
                                   remove_near_zero_variance = F, remove_zero_variance = F, toKeep.zv = NULL,
                                   remove_non_significant = remove_non_significant,
                                   fast_mode = fast_mode, return_models = return_models, MIN_EPV = MIN_EPV,
                                   pred.attr = pred.attr, pred.method = pred.method, seed = seed, PARALLEL = PARALLEL)

    lst_sb.pls[[b]] <- plsicox(X = Xh[[b]],
                               Y = Yh,
                               n.comp = cv.splsdrcox_res$opt.comp,
                               remove_near_zero_variance = F, remove_zero_variance = F, toKeep.zv = NULL,
                               remove_non_significant = remove_non_significant,
                               returnData = F,
                               x.center = x.center[[b]], x.scale = x.scale[[b]],
                               y.scale = y.scale, y.center = y.center)
  }

  # CHECK ALL MODELS SAME COMPONENTS
  aux_ncomp <- purrr::map(lst_sb.pls, ~.$n.comp)

  # CREATE COMBINE MODEL
  data <- NULL
  cn.merge <- NULL
  for(b in names(Xh)){
    data <- cbind(data, lst_sb.pls[[b]]$X$scores)
    cn.merge <- c(cn.merge, paste0(colnames(lst_sb.pls[[b]]$X$scores), "_", b))
  }

  #colnames(data) <- apply(expand.grid(colnames(lst_sb.pls[[1]]$X$scores), names(Xh)), 1, paste, collapse="_")
  colnames(data) <- cn.merge
  cox_model <- cox(X = data, Y = Yh, x.center = F, x.scale = F, y.center = F, y.scale = F, remove_non_significant = remove_non_significant, FORCE = T)

  #RETURN a MODEL with ALL significant Variables from complete, deleting one by one in backward method
  if(remove_non_significant){
    lst_rnsc <- removeNonSignificativeCox(cox = cox_model$fit, alpha = alpha, cox_input = cbind(data, Yh))

    cox_model$fit <- lst_rnsc$cox
    removed_variables <- lst_rnsc$removed_variables
  }

  ##########
  # RETURN #
  ##########
  func_call <- match.call()

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  return(sb.plsicox_class(list(X = list("data" = if(returnData) X_norm else NA, "x.mean" = xmeans, "x.sd" = xsds),
                                Y = list("data" = lst_sb.pls[[1]]$Y$data, "y.mean" = ymeans, "y.sd" = ysds),
                                survival_model = cox_model$survival_model,
                                list_pls_models = lst_sb.pls,
                                n.comp = aux_ncomp, #number of components used, but could be lesser than expected because not computed models
                                call = func_call,
                                X_input = if(returnData) X_original else NA,
                                Y_input = if(returnData) Y_original else NA,
                               alpha = alpha,
                               removed_variables_cox = removed_variables,
                                class = pkg.env$sb.plsicox,
                                time = time)))
}

### ## ##
# CLASS #
### ## ##

sb.plsicox_class = function(pls_model, ...) {
  model = structure(pls_model, class = pkg.env$model_class,
                    model = pkg.env$sb.plsicox)
  return(model)
}

cv.sb.plsicox_class = function(pls_model, ...) {
  model = structure(pls_model, class = pkg.env$model_class,
                    model = pkg.env$cv.sb.plsicox)
  return(model)
}
