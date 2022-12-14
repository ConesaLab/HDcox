#### ### ##
# METHODS #
#### ### ##

#' sPLSDA-COX
#' @description Performs a splsdacox_mixOmics model.
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param n.comp Numeric. Number of principal components to compute in the PLS model.
#' @param vector Numeric vector. Used for computing best number of variables. If NULL, an automatic detection is perform.
#' @param MIN_NVAR Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param MAX_NVAR Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param n.cut_points Numeric. Number of start cut points for look the optimal number of variable. 2 cut points mean start with the minimum and maximum. 3 start with minimum, maximum and middle point...(default: 3)
#' @param MIN_AUC_INCREASE Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param x.center Logical. If x.center = TRUE, X matrix is centered to zero means (default: TRUE).
#' @param x.scale Logical. If x.scale = TRUE, X matrix is scaled to unit variances (default: FALSE).
#' @param y.center Logical. If y.center = TRUE, Y matrix is centered to zero means (default: FALSE).
#' @param y.scale Logical. If y.scale = TRUE, Y matrix is scaled to unit variances (default: FALSE).
#' @param remove_near_zero_variance Logical. If remove_near_zero_variance = TRUE, remove_near_zero_variance variables will be removed.
#' @param remove_zero_variance Logical. If remove_zero_variance = TRUE, remove_zero_variance variables will be removed.
#' @param toKeep.zv Character vector. Name of variables in X to not be deleted by (near) zero variance filtering.
#' @param remove_non_significant Logical. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param alpha Numeric. Cutoff for establish significant variables. Below the number are considered as significant (default: 0.05).
#' @param EVAL_METHOD Numeric. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param pred.method Character. AUC method for evaluation. Must be one of the following: "risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I" (default: "cenROC")
#' @param max.iter Maximum number of iterations for PLS convergence.
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param returnData Logical. Return original and normalized X and Y matrices.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#'
#' @return Instance of class "HDcox" and model "sPLS-DACOX-MixOmics". The class contains the following elements:
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

splsdacox_mixOmics <- function (X, Y,
                               n.comp = 4, vector = NULL,
                               MIN_NVAR = 10, MAX_NVAR = 1000, n.cut_points = 5,
                               MIN_AUC_INCREASE = 0.01,
                               x.center = TRUE, x.scale = FALSE,
                               y.center = FALSE, y.scale = FALSE,
                               remove_near_zero_variance = T, remove_zero_variance = T, toKeep.zv = NULL,
                               remove_non_significant = F, alpha = 0.05,
                               EVAL_METHOD = "AUC", pred.method = "cenROC", max.iter = 200,
                               MIN_EPV = 5, returnData = T, verbose = F){

  t1 <- Sys.time()

  #### Original data
  X_original <- X
  Y_original <- Y

  time <- Y[,"time"]
  event <- Y[,"event"]

  #### REQUIREMENTS
  lst_check <- checkXY.class(X, Y, verbose = verbose)
  X <- lst_check$X
  Y <- lst_check$Y

  checkY.colnames(Y)

  #### ZERO VARIANCE - ALWAYS
  lst_dnz <- deleteZeroOrNearZeroVariance(X = X,
                                          remove_near_zero_variance = remove_near_zero_variance,
                                          remove_zero_variance = remove_zero_variance,
                                          toKeep.zv = toKeep.zv,
                                          freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  #### SCALING
  lst_scale <- XY.scale(X, Y, x.center, x.scale, y.center, y.scale)
  Xh <- lst_scale$Xh
  Yh <- lst_scale$Yh
  xmeans <- lst_scale$xmeans
  xsds <- lst_scale$xsds
  ymeans <- lst_scale$ymeans
  ysds <- lst_scale$ysds

  X_norm <- Xh

  ####MAX PREDICTORS
  n.comp <- check.maxPredictors(X, Y, MIN_EPV, n.comp)

  ########################################
  # DIVIDE Y VENCERAS - BEST VECTOR SIZE #
  ########################################

  DR_coxph <- NULL

  if(is.null(vector)){
    keepX <- getBestVector(Xh, DR_coxph, Yh, n.comp, max.iter, vector, MIN_AUC_INCREASE, MIN_NVAR = MIN_NVAR, MAX_NVAR = MAX_NVAR, cut_points = n.cut_points,
                           EVAL_METHOD = EVAL_METHOD, EVAL_EVALUATOR = pred.method, PARALLEL = F, mode = "splsda", verbose = verbose)
  }else{
    if(class(vector)=="numeric"){
      keepX <- vector
      if(length(keepX)>1){
        message("keepX must be a number, not a vector. Maximum value will be selected for compute the sPLS model.")
        keepX <- max(keepX)
      }

      if(keepX>ncol(X)){
        message("keepX must be a lesser than the number of columns in X. The value will be updated to that one.")
        keepX <- ncol(X)
      }
    }else{
      message("Vector does not has the proper structure. Optimizing best n.variables by using your vector as start vector.")
      keepX <- getBestVector(Xh, DR_coxph, Yh, n.comp, max.iter, vector = NULL, MIN_AUC_INCREASE, MIN_NVAR = MIN_NVAR, MAX_NVAR = MAX_NVAR, cut_points = n.cut_points,
                             EVAL_METHOD = EVAL_METHOD, EVAL_EVALUATOR = pred.method, PARALLEL = F, mode = "splsda", verbose = verbose)
    }
  }

  ###############################################
  ######             PLSDA-COX             ######
  ###############################################

  splsda <- mixOmics::splsda(Xh, Yh[,"event"], scale=F, ncomp = n.comp, keepX = rep(keepX, n.comp), max.iter = max.iter, near.zero.var = T)

  #last model includes all of them
  tt_splsDR = data.matrix(splsda$variates$X)
  ww_splsDR = data.matrix(splsda$loadings$X)
  pp_splsDR = data.matrix(splsda$mat.c)

  colnames(tt_splsDR) <- paste0("comp_", 1:n.comp)

  ##############################################
  #                                            #
  #      Computation of the coefficients       #
  #      of the model with kk components       #
  #                                            #
  ##############################################

  ##############################################
  ######              PLS-COX            ######
  ##############################################
  d <- as.data.frame(cbind(tt_splsDR, Yh))
  cox_model <- NULL
  cox_model$fit <- tryCatch(
    # Specifying expression
    expr = {
      survival::coxph(formula = survival::Surv(time,event) ~ .,
                      data = d,
                      ties = "efron",
                      singular.ok = T,
                      robust = T,
                      nocenter = rep(1, ncol(d)),
                      model=T)
    },
    # Specifying error message
    error = function(e){
      message(paste0("splsdacox_mixOmics: ", e))
      invisible(gc())
      return(NA)
    }
  )

  #RETURN a MODEL with ALL significant Variables from complete, deleting one by one in backward method
  if(remove_non_significant){
    lst_rnsc <- removeNonSignificativeCox(cox = cox_model$fit, alpha = alpha, cox_input = d)

    cox_model$fit <- lst_rnsc$cox
    removed_variables <- lst_rnsc$removed_variables
  }

  survival_model = NULL
  if(!length(cox_model$fit) == 1){
    survival_model <- getInfoCoxModel(cox_model$fit)
  }

  #get W.star
  W <- ww_splsDR
  P <- pp_splsDR
  W.star <- W %*% solve(t(P) %*% W, tol = 1e-20)
  Ts <- tt_splsDR

  func_call <- match.call()

  rownames(Ts) <- rownames(X)
  #rownames(P) <- rownames(W) <-  rownames(W.star) <- colnames(X) #as some variables cannot be selected, that name does not work

  colnames(Ts) <- colnames(P) <- colnames(W) <-  colnames(W.star) <- paste0("comp_", 1:n.comp)

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  return(splsdacox_mixOmics_class(list(X = list("data" = if(returnData) X_norm else NA, "loadings" = P, "weightings" = W, "W.star" = W.star, "scores" = Ts, "x.mean" = xmeans, "x.sd" = xsds),
                                      Y = list("data" = Yh, "y.mean" = ymeans, "y.sd" = ysds),
                                      survival_model = survival_model,
                                      n.comp = n.comp, #number of components
                                      n.varX = keepX,
                                      call = func_call,
                                      X_input = if(returnData) X_original else NA,
                                      Y_input = if(returnData) Y_original else NA,
                                      alpha = alpha,
                                      removed_variables_cox = removed_variables,
                                      nzv = variablesDeleted,
                                      class = pkg.env$splsdacox_mixomics,
                                      time = time)))
}

#### ### ### ### ###
# CROSS-EVALUATION #
#### ### ### ### ###

#' Cross validation splsdacox_mixOmics
#' @description plsdacox_mixOmics cross validation model
#'
#' @param X Numeric matrix. Predictor variables
#' @param Y Numeric matrix. Response variables. It assumes it has two columns named as "time" and "event". For event column, values can be 0/1 or FALSE/TRUE for censored and event samples.
#' @param max.ncomp Numeric. Maximum number of PLS components to compute for the cross validation.
#' @param vector Numeric vector. Used for computing best number of variables. If NULL, an automatic detection is perform.
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
#' @param MIN_NVAR Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param MAX_NVAR Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param n.cut_points Numeric. Number of start cut points for look the optimal number of variable. 2 cut points mean start with the minimum and maximum. 3 start with minimum, maximum and middle point...(default: 3)
#' @param MIN_AUC_INCREASE Numeric If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param EVAL_METHOD Numeric. If remove_non_significant = TRUE, non-significant variables in final cox model will be removed until all variables are significant (forward selection).
#' @param pred.method Character. AUC method for evaluation. Must be one of the following: "risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I" (default: "cenROC")
#' @param w_AIC Numeric. Weight for AIC evaluator. All three weights must sum 1 (default: 0).
#' @param w_c.index Numeric. Weight for C-Index evaluator. All three weights must sum 1 (default: 0).
#' @param w_AUC Numeric. Weight for AUC evaluator. All three weights must sum 1 (default: 1).
#' @param times Numeric vector. Time points where the AUC will be evaluated. If NULL, a maximum of 15 points will be selected equally distributed.
#' @param MIN_AUC Numeric. Minimum AUC desire.
#' @param MIN_COMP_TO_CHECK Numeric. Number of penalties to check whether the AUC improves.
#' @param pred.attr Character. Method for average the AUC. Must be one of the following: "mean" or "median" (default: "mean").
#' @param pred.method Character. AUC method for evaluation. Must be one of the following: "risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I" (default: "cenROC")
#' @param fast_mode Logical. If fast_mode = TRUE, for each run, only one fold is evaluated simultaneously. If fast_mode = FALSE, for each run, all linear predictors are computed for test observations. Once all have their linear predictors, the evaluation is perform across all the observations together (default: FALSE).
#' @param max.iter Maximum number of iterations for PLS convergence.
#' @param MIN_EPV Minimum number of Events Per Variable you want reach for the final cox model. Used to restrict the number of variables can appear in cox model. If the minimum is not meet, the model is not computed.
#' @param return_models Logical. Return all models computed in cross validation.
#' @param PARALLEL Logical. Run the cross validation with multicore option. As many cores as your total cores - 1 will be used. It could lead to higher RAM consumption.
#' @param verbose Logical. If verbose = TRUE, extra messages could be displayed (default: FALSE).
#' @param seed Number. Seed value for perform the runs/folds divisions.
#'
#' @return Instance of class "HDcox" and model "cv.sPLS-DACOX-MixOmics".
#' @export

cv.splsdacox_mixOmics <- function(X, Y,
                        max.ncomp = 10, n_run = 10, k_folds = 10,
                        vector = NULL,
                        x.center = TRUE, x.scale = FALSE,
                        y.center = FALSE, y.scale = FALSE,
                        remove_near_zero_variance = T, remove_zero_variance = T, toKeep.zv = NULL,
                        remove_non_significant_models = F, remove_non_significant = F, alpha = 0.05,
                        MIN_NVAR = 10, MAX_NVAR = 1000, n.cut_points = 5,
                        MIN_AUC_INCREASE = 0.01,
                        EVAL_METHOD = "AUC",
                        w_AIC = 0,  w_c.index = 0, w_AUC = 1, times = NULL,
                        MIN_AUC = 0.8, MIN_COMP_TO_CHECK = 3,
                        pred.attr = "mean", pred.method = "cenROC", fast_mode = F,
                        max.iter = 500,
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
  max.ncomp <- check.ncomp(X, max.ncomp)
  # if(!pred.method %in% c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I")){
  #   stop_quietly(paste0("pred.method must be one of the following: ", paste0(c("risksetROC", "survivalROC", "cenROC", "nsROC", "smoothROCtime_C", "smoothROCtime_I"), collapse = ", ")))
  # }
  if(!pred.method %in% pkg.env$AUC_evaluators){
    stop_quietly(paste0("pred.method must be one of the following: ", paste0(pkg.env$AUC_evaluators, collapse = ", ")))
  }

  ####MAX PREDICTORS
  max.ncomp <- check.maxPredictors(X, Y, MIN_EPV, max.ncomp, verbose = verbose)

  #### REQUIREMENTS
  lst_dnz <- deleteZeroOrNearZeroVariance(X = X,
                                          remove_near_zero_variance = remove_near_zero_variance,
                                          remove_zero_variance = remove_zero_variance,
                                          toKeep.zv = toKeep.zv,
                                          freqCut = 95/5)
  X <- lst_dnz$X
  variablesDeleted <- lst_dnz$variablesDeleted

  ######
  # CV #
  ######

  set.seed(seed)
  lst_data <- splitData_Iterations_Folds(X, Y, n_run = n_run, k_folds = k_folds) #FOR TEST
  lst_X_train <- lst_data$lst_X_train
  lst_Y_train <- lst_data$lst_Y_train
  lst_X_test <- lst_data$lst_X_test
  lst_Y_test <- lst_data$lst_Y_test

  ################
  # TRAIN MODELS #
  ################

  total_models <- 1 * k_folds * n_run

  comp_model_lst <- get_HDCOX_models2.0(method = pkg.env$splsdacox_mixomics,
                                       lst_X_train = lst_X_train, lst_Y_train = lst_Y_train,
                                       max.ncomp = max.ncomp, eta.list = NULL, EN.alpha.list = NULL, n_run = n_run, k_folds = k_folds,
                                       vector = vector,
                                       MIN_NVAR = MIN_NVAR, MAX_NVAR = MAX_NVAR, n.cut_points = n.cut_points,
                                       MIN_AUC_INCREASE = MIN_AUC_INCREASE,
                                       EVAL_METHOD = EVAL_METHOD,
                                       x.center = x.center, x.scale = x.scale, y.center = y.center, y.scale = y.scale,
                                       remove_near_zero_variance = F, remove_zero_variance = F, toKeep.zv = NULL,
                                       remove_non_significant = remove_non_significant,
                                       total_models = total_models, max.iter = max.iter, PARALLEL = PARALLEL, verbose = verbose)

  # comp_model_lst <- get_HDCOX_models(method = pkg.env$splsdacox_mixomics,
  #                                    lst_X_train = lst_X_train, lst_Y_train = lst_Y_train,
  #                                    max.ncomp = max.ncomp, eta.list = NULL, EN.alpha.list = NULL, n_run = n_run, k_folds = k_folds,
  #                                    x.center = x.center, x.scale = x.scale, y.center = y.center, y.scale = y.scale,
  #                                    total_models = total_models, max.iter = max.iter)

  ##########################
  # BEST MODEL FOR CV DATA #
  ##########################
  total_models <- max.ncomp * k_folds * n_run
  df_results_evals <- get_COX_evaluation_AIC_CINDEX(comp_model_lst = comp_model_lst,
                                                    max.ncomp = max.ncomp, eta.list = NULL, n_run = n_run, k_folds = k_folds,
                                                    total_models = total_models, remove_non_significant_models = remove_non_significant_models)

  if(all(is.null(df_results_evals))){
    message(paste0("Best model could NOT be obtained. All models computed present problems."))

    t2 <- Sys.time()
    time <- difftime(t2,t1,units = "mins")
    if(return_models){
      return(cv.splsdacox_mixOmics_class(list(best_model_info = NULL, df_results_folds = NULL, df_results_runs = NULL, df_results_comps = NULL, lst_models = comp_model_lst, pred.method = pred.method, opt.comp = NULL, opt.nvar = NULL, plot_AUC = NULL, plot_c_index = NULL, plot_AIC = NULL, time = time)))
    }else{
      return(cv.splsdacox_mixOmics_class(list(best_model_info = NULL, df_results_folds = NULL, df_results_runs = NULL, df_results_comps = NULL, lst_models = NULL, pred.method = pred.method, opt.comp = NULL, opt.nvar = NULL, plot_AUC = NULL, plot_c_index = NULL, plot_AIC = NULL, time = time)))
    }
  }

  ##################
  # EVALUATING AUC #
  ##################
  df_results_evals_comp <- NULL
  df_results_evals_run <- NULL
  df_results_evals_fold <- NULL
  optimal_component <- NULL
  optimal_component_flag <- NULL

  if(w_AUC!=0){
    total_models <- ifelse(!fast_mode, n_run * max.ncomp, k_folds * n_run * max.ncomp)

    lst_df <- get_COX_evaluation_AUC(comp_model_lst = comp_model_lst,
                                     lst_X_test = lst_X_test, lst_Y_test = lst_Y_test,
                                     df_results_evals = df_results_evals, times = times,
                                     fast_mode = fast_mode, pred.method = pred.method, pred.attr = pred.attr,
                                     max.ncomp = max.ncomp, n_run = n_run, k_folds = k_folds,
                                     MIN_AUC_INCREASE = MIN_AUC_INCREASE, MIN_AUC = MIN_AUC, MIN_COMP_TO_CHECK = MIN_COMP_TO_CHECK,
                                     w_AUC = w_AUC, total_models = total_models, method.train = pkg.env$splsdacox_mixomics, PARALLEL = F)

    df_results_evals_comp <- lst_df$df_results_evals_comp
    df_results_evals_run <- lst_df$df_results_evals_run
    df_results_evals_fold <- lst_df$df_results_evals_fold
    optimal_comp_index <- lst_df$optimal_comp_index
    optimal_comp_flag <- lst_df$optimal_comp_flag
  }else{
    df_results_evals_fold <- df_results_evals
  }

  ##############
  # BEST MODEL #
  ##############

  df_results_evals_comp <- cv.getScoreFromWeight(df_results_evals_comp, w_AIC, w_c.index, w_AUC, colname_AIC = "AIC", colname_c_index = "c_index", colname_AUC = "AUC")

  if(optimal_comp_flag){
    best_model_info <- df_results_evals_comp[optimal_comp_index,, drop=F][1,]
    best_model_info <- as.data.frame(best_model_info)
  }else{
    best_model_info <- df_results_evals_comp[which(df_results_evals_comp[,"score"] == max(df_results_evals_comp[,"score"], na.rm = T)),, drop=F][1,]
    best_model_info <- as.data.frame(best_model_info)
  }

  #########
  # PLOTS #
  #########
  lst_EVAL_PLOTS <- get_EVAL_PLOTS(fast_mode = fast_mode, best_model_info = best_model_info, w_AUC = w_AUC, max.ncomp = max.ncomp,
                                   df_results_evals_fold = df_results_evals_fold, df_results_evals_run = df_results_evals_run, df_results_evals_comp = df_results_evals_comp,
                                   colname_AIC = "AIC", colname_c_index = "c_index", colname_AUC = "AUC", x.text = "Component")
  df_results_evals_comp <- lst_EVAL_PLOTS$df_results_evals_comp
  ggp_AUC <- lst_EVAL_PLOTS$ggp_AUC
  ggp_c_index <- lst_EVAL_PLOTS$ggp_c_index
  ggp_AIC <- lst_EVAL_PLOTS$ggp_AIC

  ##########
  # RETURN #
  ##########
  best_model_info$n.var <- as.numeric(as.character(best_model_info$n.var)) #just in case be a factor

  message(paste0("Best model obtained."))

  t2 <- Sys.time()
  time <- difftime(t2,t1,units = "mins")

  invisible(gc())
  if(return_models){
    return(cv.splsdacox_mixOmics_class(list(best_model_info = best_model_info, df_results_folds = df_results_evals_fold, df_results_runs = df_results_evals_run, df_results_comps = df_results_evals_comp, lst_models = comp_model_lst, pred.method = pred.method, opt.comp = best_model_info$n.comps, opt.nvar = best_model_info$n.var, plot_AUC = ggp_AUC, plot_c_index = ggp_c_index, plot_AIC = ggp_AIC, time = time)))
  }else{
    return(cv.splsdacox_mixOmics_class(list(best_model_info = best_model_info, df_results_folds = df_results_evals_fold, df_results_runs = df_results_evals_run, df_results_comps = df_results_evals_comp, lst_models = NULL, pred.method = pred.method, opt.comp = best_model_info$n.comps, opt.nvar = best_model_info$n.var, plot_AUC = ggp_AUC, plot_c_index = ggp_c_index, plot_AIC = ggp_AIC, time = time)))
  }

}

### ## ##
# CLASS #
### ## ##

splsdacox_mixOmics_class = function(pls_model, ...) {
  model = structure(pls_model, class = pkg.env$model_class,
                    model = pkg.env$splsdacox_mixomics)
  return(model)
}

cv.splsdacox_mixOmics_class = function(pls_model, ...) {
  model = structure(pls_model, class = pkg.env$model_class,
                    model = pkg.env$cv.splsdacox_mixomics)
  return(model)
}
