#' Extract PMID for a given variable
#' 
#' @param db Character(1). Currently only "cMD" is supported.
#' @param key Character(1). Column name where your value belongs to.
#' @param value Character(1). Attribute of your interest.
#' 
#' @export
getPMID <- function(db, key, value) {
    # ## Further curated, alpha-version of cMD sampleMetadata table:
    # dir <- system.file("extdata", package = "OmicsMLRepoData")
    # fname <- paste0(db, "_sampleMetadataCompact.csv")
    # meta <- read.table(file.path(dir, fname), sep = ",", header = TRUE)
    
    ## Uncurated cMD sampleMetadata
    dir <- system.file("extdata", package = "OmicsMLRepoData")
    fname <- paste0(db, "_sampleMetadata.csv")
    meta <- read.table(file.path(dir, fname), sep = ",", header = TRUE)
    
    ind <- grep(value, meta[,key])
    print(unique(meta$PMID[ind]))
}