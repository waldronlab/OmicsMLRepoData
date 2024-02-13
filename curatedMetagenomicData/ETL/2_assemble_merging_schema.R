### cMD merging schema is designed in Google Sheet. This script imports that
### merging schema draft and assemble into an exporting form, including
### completeness and unique values of the original and curated fields. The
### properly formatted merging schema table is released for users/publication.


suppressPackageStartupMessages({
    library(dplyr)
    library(googlesheets4)
    library(readr)
    library(OmicsMLRepoCuration)
})

# Connect to Google Drive
url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
ss <- googledrive::as_id(url)

# Import merging schema drafts from Google Sheet ----
map <- read_sheet(ss, sheet = "merging_schema_allCols")
dd <- read_sheet(ss, sheet = "data_dictionary_allCols")
dd$merge <- as.character(dd$merge)

# Summarize consolidated columns as merging schema ---- 
## `map_to_ms` is a two-column table with `curated_field` and `original_field` columns
new_cols <- dd[which(dd$merge == "TRUE"),]$curated_column
map_to_ms <- map %>%
    dplyr::filter(curated_column %in% new_cols) %>%
    dplyr::group_by(curated_column) %>%
    dplyr::summarise(original_field = paste0(ori_column, collapse = ";")) %>%
    dplyr::rename(curated_field = curated_column)


# Completeness and uniqueness of original fields -----
dir <- "~/OmicsMLRepo/OmicsMLRepoData/inst/extdata"
originalSampleMetadata <- read_csv(file.path(dir, "cMD_sampleMetadata.csv"))
a <- map_to_ms$original_field 
original_field_name <- sapply(a, function(x) {
    strsplit(x, split = ";") %>% 
        unlist %>% 
        # paste0("legacy_", .) %>% #<<<<<<<<<<<<<<<<<<<<<<< mark 'legacy_' for the final harmonization
        paste0(., collapse = ";")
}) %>% as.vector

original_field_name[which(original_field_name == "legacy_NA")] <- NA
original_field_name[which(original_field_name == "NA")] <- NA
original_field_num <- sapply(original_field_name, 
                             function(x) {
                                 strsplit(x, ";") %>% unlist %>% na.omit %>% length
                             }) %>% stack %>%
    dplyr::rename(original_field_num = values,
                  original_field = ind)


original_field_completeness <- checkCurationStats(
    fields_list = original_field_name,
    DB = originalSampleMetadata)
original_field_unique_values <- checkCurationStats(
    fields_list = original_field_name,
    check = "unique",
    DB = originalSampleMetadata)

# Completeness and uniqueness of curated fields -----
source(file.path(cmd_etl_dir, "0_assemble_curated_metadata.R"))
colnames(curated_all) <- gsub("curated_", "", colnames(curated_all)) #<<<<<<<<<<<< remove `curated_` prefix for now
b <- map_to_ms$curated_field 
curated_field_name <- sapply(b, function(x) {
    strsplit(x, split = ";") %>% 
        unlist %>% 
        # paste0("curated_", .) %>% 
        gsub("curated_", "", .) %>%
        paste0(., collapse = ";")
}) %>% as.vector

curated_field_completeness <- checkCurationStats(
    fields_list = curated_field_name,
    DB = curated_all)
curated_field_unique_values <- checkCurationStats(
    fields_list = curated_field_name,
    check = "unique",
    DB = curated_all)

# Add completeness and uniqueness of fields ----
map_to_ms$original_field_completeness <- original_field_completeness
map_to_ms$curated_field_completeness <- curated_field_completeness
map_to_ms$original_field_unique_values <- original_field_unique_values
map_to_ms$curated_field_unique_values <- curated_field_unique_values
map_to_ms <- full_join(map_to_ms, original_field_num, by = "original_field")

map_to_ms <- map_to_ms %>% 
    dplyr::relocate(original_field_num, .after = original_field) %>%
    dplyr::relocate(original_field_completeness, .after = original_field_num) %>%
    dplyr::relocate(curated_field_completeness, .after = curated_field) %>%
    dplyr::relocate(original_field_unique_values, .after = original_field_completeness) %>%
    dplyr::relocate(curated_field_unique_values, .after = curated_field_completeness)

# Convert empty of NA (character) into NA
map_to_ms[map_to_ms == ""] <- NA
map_to_ms[map_to_ms == "NA"] <- NA

# Merging schema table, `cbio_ms`, for curated/harmonizied fields ----
cmd_ms <- arrange(map_to_ms, curated_field)
