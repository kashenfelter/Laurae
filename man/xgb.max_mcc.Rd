% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/xgb.max_mcc.R
\name{xgb.max_mcc}
\alias{xgb.max_mcc}
\title{xgboost evaluation metric for maximum Matthews Correlation Coefficient}
\usage{
xgb.max_mcc(pred, dtrain)
}
\arguments{
\item{pred}{Type: numeric. The predictions.}

\item{dtrain}{Type: xgb.DMatrix. The training data.}
}
\value{
The maximum Matthews Correlation Coefficient for binary data.
}
\description{
This function allows xgboost to use a custom thresholding method to maximize the Matthews Correlation Coefficient. You can use this function via \code{eval_metric}. It leaks memory over time, but it can be reclaimed using \code{gc()}.
}

