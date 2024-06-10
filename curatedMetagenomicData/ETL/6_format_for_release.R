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



# Add unchanged columns ----------
extDir <- "~/OmicsMLRepo/OmicsMLRepoData/inst/extdata"
map <- read_sheet(ss, sheet = "merging_schema_allCols")
dd <- read_sheet(ss, sheet = "data_dictionary_allCols") %>%
    mutate(merge = as.character(merge))

kept_categories <- dd %>% filter(merge == FALSE) %>% .[["curated_column"]]
kept_cols <- map %>%
    filter(curated_column %in% kept_categories) %>%
    .[["ori_column"]]

# Subset the metadata to be kept -------
sampleMetadata <- read_csv(file.path(extDir, "cMD_sampleMetadata.csv"))
kept_meta <- sampleMetadata %>% select(all_of(kept_cols))
kept_meta$curation_id <- paste(kept_meta$study_name, 
                               kept_meta$sample_id, sep = ":")

# Combine all metadata --------
cmd_meta_release <- dplyr::full_join(curated_all_cleaned, 
                                     kept_meta,
                                     by = "curation_id")


# Combine data dictionary drafts ----
allCols <- colnames(cmd_meta_release)
required_cols <- c("study_name", "subject_id", "sample_id", "curation_id", 
                   "target_condition", "target_condition_ontology_term_id",
                   "control", "control_ontology_term_id", 
                   "country", "country_ontology_term_id", 
                   "body_site", "body_site_ontology_term_id")
optional_cols <- allCols[!allCols %in% required_cols]
col_order <- c(required_cols, sort(optional_cols))
cmd_meta_release <- cmd_meta_release[col_order]

# Add attribute -----------
attr(cmd_meta_release, "source") <- "curatedMetagenomicData"
attr(cmd_meta_release, "last_updated") <- Sys.time()
