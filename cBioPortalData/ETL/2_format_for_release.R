### This script creates a `cbio_meta_release` table, which containing only 
### the curated attributes formatted in an user-facing version (e.g., no 
### legacy/source columns, no ontology term id).


# Load `curated_all` table ------
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
fpath <- file.path(dir, "inst/extdata/cBioPortal_curated_metadata.csv")
curated_all <- readr::read_csv(fpath)

# Remove accessory columns --------
ori_ind <- grep("^original_", colnames(curated_all)) # `original_` cols
curated_all_cleaned <-curated_all[-ori_ind]

source_ind <- grep("_source$", colnames(curated_all_cleaned)) # `_source` cols
curated_all_cleaned <- curated_all_cleaned[-source_ind]

# Remove `curated_` prefix ---------
updated_col_names <- gsub("^curated_", "", colnames(curated_all_cleaned))
colnames(curated_all_cleaned) <- updated_col_names


# Subset the metadata to be kept (ID columns) -------
srcDir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/source"
ori <- readRDS(file.path(srcDir, "cBioPortal_all_clinicalData_combined_2023-05-18.rds"))

kept_cols <- c("studyId", "patientId", "sampleId", "SAMPLE_COUNT")
kept_meta <- ori %>% select(all_of(kept_cols))
kept_meta$curation_id <- paste(kept_meta$studyId, 
                               kept_meta$patientId, sep = ":") %>%
    paste(., kept_meta$sampleId, sep = ":")


# Combine all metadata --------
cbio_meta_release <- dplyr::full_join(curated_all_cleaned, 
                                      kept_meta,
                                      by = "curation_id")
allCols <- colnames(cbio_meta_release)
required_cols <- c("studyId", "patientId", "sampleId", "curation_id", "SAMPLE_COUNT")
optional_cols <- allCols[!allCols %in% required_cols]
col_order <- c(required_cols, sort(optional_cols)) # alphabetical order
cbio_meta_release <- cbio_meta_release[col_order] %>%
    dplyr::rename(sample_count = SAMPLE_COUNT) # consistent capitalization of attribute names

attr(cbio_meta_release, "source") <- "cBioPortalData" # add attribute

# Add attribute -----------
cbio_meta_release$package <- "cBioPortal"
cbio_meta_release$last_updated <- Sys.time()

# Tidying ---------------
# ## Remove all treatment_* columns except treatment_name/type
# all_trt_cols <- grep("treatment_", colnames(cbio_meta_release), value = TRUE)
# kept_trt_cols <- grep("treatment_name|treatment_type", colnames(cbio_meta_release), value = TRUE)
# rm_trt_cols <- setdiff(all_trt_cols, kept_trt_cols)

## Remove all treatment availability related columns (e.g., `treatment_not_provided`, `treatment_no`)
rm_trt_cols <- grep("treatment_", colnames(cbio_meta_release), value = TRUE) %>%
    grep("_no$|_not_", ., value = TRUE)
cbio_meta_release_tidy <- cbio_meta_release %>% select(!all_of(rm_trt_cols))

# dd <- read.csv("~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/data_dictionary/cBioPortal_data_dictionary.csv")
# removeCols <- dd %>% filter(main.col == "FALSE") %>% pull(col.name)
# 
# ## All the associated cols
# onto_cols <- paste0(removeCols, "_ontology_term_id")
# unit_cols <- paste0(removeCols, "_unit")
# unit_onto_cols <- paste0(unit_cols, "_ontology_term_id")
# removeColsAll <- intersect(c(removeCols, onto_cols, unit_cols, unit_onto_cols), 
#                            colnames(cbio_meta_release))
# cbio_meta_release <- cbio_meta_release %>% select(!removeColsAll)

