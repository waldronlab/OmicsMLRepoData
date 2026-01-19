### This script collect all the curated cMD metadata data files per attribute
### and combine them into a single `curated_all` table. 


# Import curated/harmonized attributes ----
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
dataDir <- file.path(dir, "curatedMetagenomicData/data")
curated <- list.files(dataDir)
curated <- curated[grepl("\\.csv$", curated)] # choose only file
curatedDatObj <- gsub(".csv", "", curated)

for (i in seq_along(curated)) {
    res <- read_csv(file.path(dataDir, curated[i]))
    assign(curatedDatObj[i], res)
}


# Collect the original data to be kept -----
url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
ss <- googledrive::as_id(url)
dd <- googlesheets4::read_sheet(ss, sheet = "data_dictionary_allCols") %>%
    mutate(merge = as.character(merge))
ms <- googlesheets4::read_sheet(ss, sheet = "merging_schema_allCols")
sampleMetadata <- read.csv(file.path(cmd_dir, "source/sampleMetadata.csv"), header = TRUE) %>%
    mutate(curation_id = paste(study_name, sample_id, sep = ":"))

# Individual columns to be kept: `keep_origin == TRUE` in dd
cols_to_keep <- dd %>%
    filter(keep_origin == TRUE) %>%
    pull(curated_column)
cols_to_keep_names <- ms %>%
    filter(curated_column %in% cols_to_keep) %>%
    pull(ori_column)
kept_cols <- sampleMetadata %>% 
    select(all_of(c("curation_id", cols_to_keep_names)))
colnames(kept_cols) <- c("curation_id", cols_to_keep) # to match the colname capitalization

# Categories to be kept: `merge == FALSE` in dd
categories_to_keep <- dd %>% 
    filter(merge == FALSE) %>% 
    pull(curated_column)
categories_to_keep_names <- ms %>%
    filter(curated_column %in% categories_to_keep) %>%
    pull(ori_column)
kept_categories <- sampleMetadata %>% 
    select(all_of(c("curation_id", categories_to_keep_names)))


# Combine all the curated sample metadata ----
curated_all <- get(curatedDatObj[1])
for (i in 2:length(curatedDatObj)) { # assuming there are >= 2 tables to be combined
    dat <- get(curatedDatObj[i])
    curated_all <- dplyr::left_join(curated_all, dat, by = "curation_id")
}

# Combine original metadata to be kept ----------
curated_all <- dplyr::left_join(curated_all, kept_cols, by = "curation_id") %>%
    dplyr::left_join(., kept_categories, by = "curation_id")

# Update the format ----------------
formatDir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/ETL/format_update/"
source(file.path(formatDir, "0_1_curated_metadata.R"))
