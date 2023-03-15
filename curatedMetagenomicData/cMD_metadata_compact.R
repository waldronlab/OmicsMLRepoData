## Select the variables to be exposed 
## I edited this from the Google Sheet
dir <- system.file("extdata", package = "OmicsMLRepoData")
map <- read.table(file.path(dir, "cMD_metadata_export_version.csv"), 
                  sep = ",", header = TRUE)[,-1]

## Variables not to be included for the selected version of export
uncurated_var <- map$ind[which(map$ver_0.99.0 == "FALSE")]

## Make a compact version of sampleMetadata
library(curatedMetagenomicData)
x <- sampleMetadata
for (var in uncurated_var) {
    x[var] <- paste(var, x[[var]], sep = ":") # 'column_name:value' separated by ':'
}
meta <- x %>% 
    tidyr::unite(col = "uncurated",
                 uncurated_var,
                 sep = ";", # columns separated by ';'
                 remove = TRUE, # remove the individual column
                 na.rm = FALSE) # NA stays 

## Load harmonized attributes
data_dir <- "curatedMetagenomicData/data/"
condition <- read.csv(file.path(data_dir, "curated_condition.csv"))
bodysite <- read.csv(file.path(data_dir, "curated_bodysite.csv"))
age <- read.csv(file.path(data_dir, "curated_age.csv"))

## Update sampleMetadata with harmonized attributes
meta$curation_id <- paste(meta$study_name, meta$sample_id, sep = ":")
meta <- dplyr::full_join(meta, condition, by = "curation_id") %>%
    dplyr::full_join(., bodysite, by = "curation_id") %>%
    dplyr::full_join(., age, by = "curation_id")

meta$last_updated <- Sys.Date()
write.csv(meta, "inst/extdata/cMD_curated_sampleMetadata.csv",
          row.names = FALSE)
