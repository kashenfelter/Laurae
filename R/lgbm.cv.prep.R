#' LightGBM Cross-Validated Model Preparation
#'
#' This function allows you to prepare the cross-validatation of a LightGBM model.
#' It is recommended to have your x_train and x_val sets as data.table (or data.frame), and the data.table development version. To install data.table development version, please run in your R console: \code{install.packages("data.table", type = "source", repos = "http://Rdatatable.github.io/data.table")}.
#' SVMLight conversion requires Laurae's sparsity package, which can be installed using \code{devtools:::install_github("Laurae2/sparsity")}. SVMLight format extension used is \code{.svm}.
#' Does not handle weights or groups.
#' 
#' @param y_train Type: vector. The training labels.
#' @param x_train Type: data.table or dgCMatrix (with \code{SVMLight = TRUE}). The training features.
#' @param x_test Type: data.table or dgCMatrix (with \code{SVMLight = TRUE}). The testing features, if necessary. Not providing a data.frame or a matrix results in at least 3x memory usage. Defaults to \code{NA}.
#' @param SVMLight Type: boolean. Whether the input is a dgCMatrix to be output to SVMLight format. Setting this to \code{TRUE} enforces you must provide labels separately (in \code{y_train}) and headers will be ignored. This is default behavior of SVMLight format. Defaults to \code{FALSE}.
#' @param data_has_label Type: boolean. Whether the data has labels or not. Do not modify this. Defaults to \code{FALSE}.
#' @param NA_value Type: numeric or character. What value replaces NAs. Use \code{"na"} if you want to specify "missing". It is not recommended to use something else, even by soemthing like a numeric value out of bounds (like \code{-999} if all your values are greater than \code{-999}). You should change from the default \code{"na"} if they have a real numeric meaning. Defaults to \code{"na"}.
#' @param workingdir Type: character. The working directory used for LightGBM. Defaults to \code{getwd()}.
#' @param train_all Type: boolean. Whether the full train data should be exported to the requested format for usage with \code{lgbm.train}. Defaults to \code{FALSE}.
#' @param test_all Type: boolean. Whether the full test data should be exported to the requested format for usage with \code{lgbm.train}. Defaults to \code{FALSE}.
#' @param cv_all Type: boolean. Whether the full cross-validation data should be exported to the requested format for usage with \code{lgbm.cv}. Defaults to \code{TRUE}.
#' @param train_name Type: character. The name of the default training data file for the model. Defaults to \code{paste0('lgbm_train', ifelse(SVMLight, '.svm', '.csv'))}.
#' @param val_name Type: character. The name of the default validation data file for the model. Defaults to \code{paste0('lgbm_val', ifelse(SVMLight, '.svm', '.csv'))}.
#' @param test_name Type: character. The name of the testing data file for the model. Defaults to \code{paste0('lgbm_test', ifelse(SVMLight, '.svm', '.csv'))}.
#' @param verbose Type: boolean. Whether \code{fwrite} data is output. Defaults to \code{TRUE}.
#' @param folds Type: integer, vector of two integers, vector of integers, or list. If a integer is supplied, performs a \code{folds}-fold cross-validation. If a vector of two integers is supplied, performs a \code{folds[1]}-fold cross-validation repeated \code{folds[2]} times. If a vector of integers (larger than 2) was provided, each integer value should refer to the fold, of the same length of the training data. Otherwise (if a list was provided), each element of the list must refer to a fold and they will be treated sequentially. Defaults to \code{5}.
#' @param folds_weight Type: vector of numerics. The weights assigned to each fold. If no weight is supplied (\code{NA}), the weights are automatically set to \code{rep(1/length(folds))} for an average (does not mix well with folds with different sizes). When the folds are automatically created by supplying \code{fold} a vector of two integers, then the weights are automatically computed. Defaults to \code{NA}.
#' @param stratified Type: boolean. Whether the folds should be stratified (keep the same label proportions) or not. Defaults to \code{TRUE}.
#' @param fold_seed Type: integer or vector of integers. The seed for the random number generator. If a vector of integer is provided, its length should be at least longer than \code{n}. Otherwise (if an integer is supplied), it starts each fold with the provided seed, and adds 1 to the seed for every repeat. Defaults to \code{0}.
#' @param fold_cleaning Type: integer. When using cross-validation, data must be subsampled. This parameter controls how aggressive RAM usage should be against speed. The lower this value, the more aggressive the method to keep memory usage as low as possible. Defaults to \code{50}.
#' 
#' @return The \code{folds} and \code{folds_weight} elements in a list if \code{cv_all = TRUE}. All files are output and ready to use for \code{lgbm.cv} with \code{files_exist = TRUE}. If using \code{train_all}, it is ready to be used with \code{lgbm.train} and \code{files_exist = TRUE}. Returns \code{"Success"} if \code{cv_all = FALSE} and the code does not error mid-way.
#' 
#' @examples
#' \dontrun{
#' Prepare files for cross-validation.
#' trained.cv <- lgbm.cv(y_train = targets,
#'                       x_train = data[1:1500, ],
#'                       workingdir = file.path(getwd(), "temp"),
#'                       train_conf = 'lgbm_train.conf',
#'                       train_name = 'lgbm_train.csv',
#'                       val_name = 'lgbm_val.csv',
#'                       folds = 3)
#' }
#' 
#' @export

lgbm.cv.prep <- function(
  
  # Data-related
  y_train,
  x_train,
  x_test = NA,
  SVMLight = is(x_train, "dgCMatrix"),
  data_has_label = FALSE,
  NA_value = "nan",
  
  # LightGBM I/O-related
  workingdir = getwd(),
  
  # Data files to create/user
  train_all = FALSE,
  test_all = FALSE,
  cv_all = TRUE,
  train_name = paste0('lgbm_train', ifelse(SVMLight, '.svm', '.csv')),
  val_name = paste0('lgbm_val', ifelse(SVMLight, '.svm', '.csv')),
  test_name = paste0('lgbm_test', ifelse(SVMLight, '.svm', '.csv')),
  verbose = TRUE,
  
  # Validation method
  folds = 5,
  folds_weight = NA,
  stratified = TRUE,
  fold_seed = 0,
  fold_cleaning = 50
  
) {
  
  if (train_all) {
    
    if (verbose) {
      cat("\n\nExporting now the train set...\n")
    }
    
    if (SVMLight == FALSE) {
      
      # Create folds
      x_tr <- x_train
      if (data_has_label == FALSE) {
        x_tr[, datatable_target := y_train]
        setcolorder(x_tr, c("datatable_target", colnames(x_tr)[-ncol(x_tr)]))
      }
      fwrite(x_tr, file.path(workingdir, train_name), col.names = FALSE, sep = ",", na = as.character(NA_value), verbose = verbose, quote = FALSE)
      if (data_has_label == FALSE) {
        x_tr[, datatable_target := NULL] #data.table pointer strangeness
      }
      rm(x_tr)
      gc(verbose = FALSE)
      
    } else {
      
      write.svmlight(x_train, y_train, file.path(workingdir, train_name))
      gc(verbose = FALSE)
      
    }
    
  }
  
  
  if (test_all) {
    
    if (verbose) {
      cat("\n\nExporting now the test set...\n")
    }
    if (SVMLight == FALSE) {
      fwrite(x_test, file.path(workingdir, test_name), col.names = FALSE, sep = ",", na = as.character(NA_value), verbose = verbose, quote = FALSE)
    } else {
      write.svmlight(x_test, file = file.path(workingdir, test_name))
    }
    
  }
  
  if (cv_all) {
    
    outputs <- list()
    outputs[["Models"]] <- list()
    
    # Attempts to unscramble "folds"
    if (!is.list(folds)) {
      # It's not the list case
      
      if (length(folds) == 1) {
        # It's the case of 1 integer value passed
        folds_list <- kfold(y = y_train, k = folds, stratified = stratified, seed = fold_seed)
        if (is.na(folds_weight[1])) {folds_weight <- rep(1/folds, folds)}
        
      } else {
        # It's not the case of 1 integer value passed
        
        if (length(folds) == 2) {
          # It's the case of 2 integers value passed
          folds_list <- nkfold(y = y_train, n = folds[2], k = folds[1], stratified = stratified, seed = fold_seed, weight = TRUE)
          if (is.na(folds_weight[1])) {folds_weight <- folds_list$Weights}
          folds_list <- folds_list$Folds
          
        } else {
          # It's the case of a vector of integers passed, so check length
          if (!(length(folds) == length(y_train))) {
            cat("Folds are not matching the training data. (Folds=", length(folds), " vs Train=", length(y_train), ")  \n", sep = "")
            return("Bad fold length!")
          } else {
            # Parse folds appropriately
            folds_list <- list()
            folds_unique <- unique(folds)
            for (i in 1:length(folds_unique)) {
              folds_list[[i]] <- which(folds == folds_unique[i])
            }
            if (is.na(folds_weight[1])) {folds_weight <- rep(1/length(folds_unique), length(folds_unique))}
            
          }
          
        }
        
      }
    } else {
      
      folds_list <- folds
      if (is.na(folds_weight[1])) {
        folds_weight <- rep(1/length(folds_list), length(folds_list))
      }
      
    }
    
    gc(verbose = FALSE)
    
    for (i in 1:length(folds_list)) {
      
      fold_shortcut <- sprintf(paste("%0", floor(log10(length(folds_list)) + 1), "d", sep = ""), i)
      if (verbose) {
        cat(paste0('  \n', paste('Exporting now the fold ', fold_shortcut), ' / ', length(folds_list), '...  \n'))
      }
      
      if (SVMLight == FALSE) {
        
        # Create folds
        x_tr <- DTsubsample(DT = x_train, kept = (1:nrow(x_train))[-folds_list[[i]]], low_mem = FALSE, collect = fold_cleaning, silent = !verbose)
        if (data_has_label == FALSE) {
          x_tr[, datatable_target := y_train[-folds_list[[i]]]]
          setcolorder(x_tr, c("datatable_target", colnames(x_tr)[-ncol(x_tr)]))
        }
        fwrite(x_tr, file.path(workingdir, stri_replace_last_fixed(train_name, ".", paste0("_", fold_shortcut, "."))), col.names = FALSE, sep = ",", na = as.character(NA_value), verbose = verbose, quote = FALSE)
        rm(x_tr)
        gc(verbose = FALSE)
        
        x_val <- DTsubsample(DT = x_train, kept = folds_list[[i]], low_mem = FALSE, collect = fold_cleaning, silent = !verbose)
        if (data_has_label == FALSE) {
          x_val[, datatable_target := y_train[folds_list[[i]]]]
          setcolorder(x_val, c("datatable_target", colnames(x_val)[-ncol(x_val)]))
        }
        fwrite(x_val, file.path(workingdir, stri_replace_last_fixed(val_name, ".", paste0("_", fold_shortcut, "."))), col.names = FALSE, sep = ",", na = as.character(NA_value), verbose = verbose, quote = FALSE)
        rm(x_val)
        gc(verbose = FALSE)
        
      } else {
        
        cat("Exporting the train set...\n")
        x_tr <- x_train[(1:nrow(x_train))[-folds_list[[i]]], ]
        write.svmlight(x_tr, y_train[-folds_list[[i]]], file.path(workingdir, stri_replace_last_fixed(train_name, ".", paste0("_", fold_shortcut, "."))))
        rm(x_tr)
        gc(verbose = FALSE)
        
        cat("Exporting the validation set...\n")
        x_val <- x_train[folds_list[[i]], ]
        write.svmlight(x_val, y_train[folds_list[[i]]], file.path(workingdir, stri_replace_last_fixed(val_name, ".", paste0("_", fold_shortcut, "."))))
        rm(x_val)
        gc(verbose = FALSE)
        
      }
      
      
    }
    
    folded <- list()
    folded[["folds"]] <- folds_list
    folded[["folds_weight"]] <- folds_weight
    
    return(folded)
    
  }
  
  return("Success")
  
}