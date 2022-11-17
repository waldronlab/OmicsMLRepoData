#' Extract the percent completeness of the metadata at the sample level
#' 
#' @param db Character(1). Currently only "cMD" is supported.
#' @param var Character(1). Name of the variable to check the completeness.
#' 
#' @export
perComp <- function(db, var) {
    ## Select the variables to be exposed from the Google Sheet
    dir <- system.file("extdata", package = "OmicsMLRepoData")
    fname <- paste0(db, "_metadata_export_version.csv")
    map <- read.table(file.path(dir, fname), sep = ",", header = TRUE)[,-1]
    
    ## Check the validity of input argument "var"
    if (!var %in% map$ind) {stop(paste(var, "doesn't exist."))}
    
    ## Sample-level completeness
    res <- map[map$ind == var, "values"] 
    return(paste0(var, " of ", db, " : ", res, "% of samples completed."))
}