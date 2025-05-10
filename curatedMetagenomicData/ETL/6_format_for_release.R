### This script creates a `cmd_meta_release` table, which containing only 
### the curated attributes formatted in an user-facing version (e.g., no 
### legacy/source columns, no ontology term id).


# Load `curated_all` table ------
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
fpath <- file.path(dir, "inst/extdata/cMD_curated_metadata_all.csv")
curated_all <- readr::read_csv(fpath)

# Remove accessory columns --------
ori_ind <- grep("^original_", colnames(curated_all)) # `original_` cols
curated_all_cleaned <-curated_all[-ori_ind]

source_ind <- grep("_source$", colnames(curated_all_cleaned)) # `_source` cols
curated_all_cleaned <- curated_all_cleaned[-source_ind]

# Remove `curated_` prefix ---------
updated_col_names <- gsub("^curated_", "", colnames(curated_all_cleaned))
colnames(curated_all_cleaned) <- updated_col_names

# Add attribute -----------
curated_all_cleaned$package <- "cMD"
curated_all_cleaned$last_updated <- Sys.time()

# Update the format of the released version ----------------------------
formatDir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/ETL/format_update/"
source(file.path(formatDir, "6_1_release.R"))

# Combine data dictionary drafts ----
allCols <- colnames(curated_all_cleaned)
required_cols <- c("study_name", "subject_id", "sample_id", "curation_id", 
                   "target_condition", "target_condition_ontology_term_id",
                   "control", "control_ontology_term_id", 
                   "country", "country_ontology_term_id", 
                   "body_site", "body_site_ontology_term_id",
                   "body_site_details", "body_site_details_ontology_term_id")
annot_cols <- c("package", "last_updated")
optional_cols <- allCols[!allCols %in% c(required_cols, annot_cols)]
col_order <- c(required_cols, sort(optional_cols), annot_cols)
cmd_meta_release <- curated_all_cleaned[col_order]

