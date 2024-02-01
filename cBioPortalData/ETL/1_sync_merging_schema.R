### This script syncs cBioPortal merging schema created in Google Sheet to 
### the GitHub repo. 

### Because there are quite a lot of columns involved in cBioPortal metadata 
### harmonization, its merging schema is created per attribute. 
### Each merging schema contains three major columns and more: `curated_column`, 
### `original_column`, and `completeness`


# Directory to save curation_maps from Google Sheet
cbio_ms_dir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/merging_schema/"

## Age
url <- "https://docs.google.com/spreadsheets/d/1HDB845dzSFu25i6xEPfk06eR9n70IB-2uGsV4ZWpnVM/edit?usp=sharing"
ss <- googledrive::as_id(url)
age_ms <- googlesheets4::read_sheet(ss = ss, sheet = "merging_schema_age")

## Disease
url <- "https://docs.google.com/spreadsheets/d/1IgrVEdgCZdvBmWrER21A57lSkfDjdRdV3RbK_yoqMl4/edit?usp=sharing"
ss <- googledrive::as_id(url)
disease_ms <- googlesheets4::read_sheet(ss = ss, sheet = "merging_schema_disease")

# ## Cleaning disease merging schema - First time
# dir <- "~/OmicsMLRepo/OmicsMLRepoData"
# ori <- readRDS(file.path(dir, "cBioPortalData/source/cBioPortal_all_clinicalData_combined_2023-05-18.rds"))
# disease_ms <- googlesheets4::read_sheet(ss = ss, sheet = "ms_disease")
# disease_ms$original_field <- gsub("CANCER\\.TYPE", "CANCER TYPE", disease_ms$original_field)
# 
# curated_disease <- read_csv(file.path(dir, "cBioPortalData/data/curated_disease.csv"))
# 
# for (i in seq_len(nrow(disease_ms))) {
#     ## The same value from different columns are considered different.
#     x <- ori[disease_ms$original_field[i]] %>% unlist
#     comp <- round(sum(!is.na(x))/length(x)*100, 2)
#     uniq <-  length(unique(x))
#     disease_ms[i, "original_field_completeness"] <- comp
#     disease_ms[i, "original_field_unique_values"] <- uniq
# 
#     columnName <- paste0("curated_", disease_ms$curated_field[i])
#     y <- curated_disease[columnName] %>% unlist
#     curated_comp <- round(sum(!is.na(y))/length(y)*100, 2)
#     curated_uniq <-  length(unique(y))
#     disease_ms[i, "curated_field_completeness"] <- curated_comp
#     disease_ms[i, "curated_field_unique_values"] <- curated_uniq
# }
# 
# redu_stats <- disease_ms %>%
#     group_by(curated_field) %>%
#     summarise(percent_unique_values_reduction =
#                   round(unique(curated_field_unique_values)/
#                   sum(original_field_unique_values), 2))
# res <- left_join(disease_ms[1:6], redu_stats, by = "curated_field")
# 
# googlesheets4::write_sheet(res, ss = ss, sheet = "merging_schema_disease")

## Treatment
url <- "https://docs.google.com/spreadsheets/d/1E6Xr1Aa8gxu6MgujOQ7kxarlZ7O8-Iy8XsCp7-0BHXY/edit?usp=sharing"
ss <- googledrive::as_id(url)
treatment_ms <- googlesheets4::read_sheet(ss = ss, sheet = "binned_cols")
