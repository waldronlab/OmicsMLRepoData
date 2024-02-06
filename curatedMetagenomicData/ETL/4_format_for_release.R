




## Combine original and curated sample metadata
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
ori <- read_csv(file.path(dir, "inst/extdata/cMD_sampleMetadata.csv"))

allSampleMetadata <- ori %>%
    mutate(curation_id = paste(study_name, sample_id, sep = ":")) %>%
    dplyr::left_join(., curated_all, by = "curation_id")

allSampleMetadata$last_modified <- Sys.Date() #<<< Can I update this at the sample-level?

##### Update the column names
merging_schema <- read_csv(file.path(dir, "inst/extdata/cMD_merging_schema.csv"))

## Names of the original fields
old_field <- sapply(merging_schema$original_field, strsplit, split = ";") %>% 
    unlist %>% 
    as.character
old_field <- old_field[!is.na(old_field)]

## Names of the new fields
new_field <- sapply(merging_schema$curated_field, strsplit, split = ";") %>% 
    unlist %>% 
    as.character

## Add prefix `legacy_` for the legacy columns
legacy_ind <- which(colnames(allSampleMetadata) %in% old_field)
colnames(allSampleMetadata)[legacy_ind] <- paste0("legacy_", colnames(allSampleMetadata)[legacy_ind])





curated_ind <- grep("^curated_", colnames(allSampleMetadata))
name1 <- colnames(allSampleMetadata)[curated_ind]
name2 <-  gsub("^curated_", "", name1)

updated <- relocate(allSampleMetadata, starts_with("curated_"), .after = subject_id)
updated <- relocate(updated, starts_with("legacy_"), .before = last_modified)

updated <- updated %>%
    select(!starts_with("original_"))

data.table::setnames(updated, old = name1, new = name2)
sum(duplicated(colnames(updated))) # should be 0