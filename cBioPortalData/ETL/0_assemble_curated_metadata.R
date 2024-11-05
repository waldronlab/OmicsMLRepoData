### This script collect all the curated cBioPortal metadata data files and
### combine them into a single `curated_all` table. 


# Import curated/harmonized data files ------
## cBioPortal metadata other than treatment
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
dataDir <- file.path(dir, "cBioPortalData/data")
curated <- list.files(dataDir)
curated <- curated[grep(".csv", curated)]
curatedDatObj <- gsub(".csv", "", curated)
for (i in seq_along(curated)) {
    res <- readr::read_csv(file.path(dataDir, curated[i]))
    assign(curatedDatObj[i], res)
}

## cBioPortal_treatment 
dataDir <- file.path(dir, "cBioPortalData/cBioPortal_treatment/data")
curatedTrtObj <- "curated_treatment_all"
res <- readRDS(file.path(dataDir, "compressed_curated_treatment.rds")) # compressed version
assign(curatedTrtObj, res)

# Merge all the curated tables using `curation_id` -------
curatedAll <- c(curatedDatObj, curatedTrtObj) # names of all the curated tables
curated_all <- get(curatedAll[1])
for (i in 2:length(curatedAll)) { # assuming there are >= 2 tables to be combined
    dat <- get(curatedAll[i])
    curated_all <- dplyr::left_join(curated_all, dat, by = "curation_id")
}
