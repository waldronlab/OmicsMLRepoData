proj_dir <- "~/Packages/OmicsMLRepoData/curatedMetagenomicData"

suppressPackageStartupMessages({
    library(curatedMetagenomicData)
})

## Add `curation_id` to handle duplicated samples
sampleMetadata$curation_id <- paste(sampleMetadata$study_name,
                                    sampleMetadata$sample_id,
                                    sep = ":")

## Subset of age-associated metadata
age_tb <- sampleMetadata[,c("curation_id", "age", "infant_age", "age_category")]

## Sanity check: agreement between different columns

## Curation
### `age` and `infant_age`
curated_infant_age <- age_tb %>%
    dplyr::filter(!is.na(infant_age)) %>%
    dplyr::transmute(curation_id = curation_id,
                     original_age_source = "infant_age",
                     original_age_value = infant_age,
                     original_age_unit = "day",
                     curated_age = infant_age/365,
                     curated_age_min = infant_age/365,
                     curated_age_max = infant_age/365,
                     curated_age_group = NA,
                     curated_age_group_ontology = NA)

curated_age <- age_tb %>%
    dplyr::filter(is.na(infant_age) & !is.na(age)) %>% 
    dplyr::transmute(curation_id = curation_id, 
                     original_age_source = "age",
                     original_age_value = age,
                     original_age_unit = "year",
                     curated_age = age,
                     curated_age_min = age,
                     curated_age_max = age,
                     curated_age_group = NA,
                     curated_age_group_ontology = NA)

## `age_category`
age_group_only <- age_tb %>%
    dplyr::filter(is.na(age) & is.na(infant_age)) %>%
    dplyr::transmute(curation_id = curation_id, 
                     age_category = age_category, # keep this for mapping
                     original_age_source = "age_category",
                     original_age_value = NA,
                     original_age_unit = NA,
                     curated_age = NA,
                     curated_age_min = NA,
                     curated_age_max = NA,
                     curated_age_group = NA,
                     curated_age_group_ontology = NA)  

age_group_need_curation <- age_tb %>%   # curated age fields are filled with numeric value
    dplyr::filter(!is.na(age) | !is.na(infant_age)) %>%
    dplyr::transmute(curation_id = curation_id,
                     curated_age_group = NA,
                     curated_age_group_ontology = NA)

## Import the manually created age_group map
age_group_map <- read.csv(file.path(proj_dir, "maps/cMD_age_ontology.csv"), 
                          sep = ",", header = TRUE)

## age_group for samples without any numeric age-information
### age_group ontology
curated_age_group <- plyr::mapvalues(x = age_group_only$age_category, 
                                     from = age_group_map$original_value, 
                                     to = age_group_map$curated_age_group, 
                                     warn_missing = TRUE)

### age_group min
curated_age_min <- plyr::mapvalues(x = age_group_only$age_category, 
                                   from = age_group_map$original_value, 
                                   to = age_group_map$curated_age_min, 
                                   warn_missing = TRUE)

### age_group max
curated_age_max <- plyr::mapvalues(x = age_group_only$age_category, 
                                   from = age_group_map$original_value, 
                                   to = age_group_map$curated_age_max, 
                                   warn_missing = TRUE)

### Add the curated values
age_group_only$curated_age_group <- curated_age_group
age_group_only$curated_age_min <- curated_age_min
age_group_only$curated_age_max <- curated_age_max

age_group_only <- age_group_only[,-which(colnames(age_group_only) == "age_category")]

## age_group for samples with some numeric age-information
curated_numeric_age <- rbind(curated_infant_age, curated_age) 

### Assign age_group based on the numeric age info
res_pool <- age_group_map$curated_age_group[order(age_group_map$curated_age_min)]
res_ind <- findInterval(curated_numeric_age$curated_age, vec = sort(age_group_map$curated_age_min))
curated_numeric_age$curated_age_group <- res_pool[res_ind]

curated_age_all <- rbind(curated_numeric_age, age_group_only)
nrow(curated_age_all) == nrow(age_tb) ## Check all 22,588 samples are there

### Assign ontology to all
age_onto <- plyr::mapvalues(x = curated_age_all$curated_age_group, 
                            from = age_group_map$curated_age_group, 
                            to = age_group_map$curated_age_group_ontology, 
                            warn_missing = TRUE)
curated_age_all$curated_age_group_ontology <- age_onto
curated_age_all <- curated_age_all[order(curated_age_all$curation_id),]

# Save
write.csv(curated_age_all, 
          file = file.path(proj_dir, "data/curated_age.csv"),
          row.names = FALSE)
