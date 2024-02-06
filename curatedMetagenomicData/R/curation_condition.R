proj_dir <- "~/Packages/OmicsMLRepoData/curatedMetagenomicData"

suppressPackageStartupMessages({
    library(curatedMetagenomicData)
})

## Add `curation_id` to handle duplicated samples
sampleMetadata$curation_id <- paste(sampleMetadata$study_name,
                                    sampleMetadata$sample_id,
                                    sep = ":")

## Fix one different format
fix_ind <- grep("metastases_lung,metastases_nodes", sampleMetadata$disease)
sampleMetadata$disease[fix_ind]
sampleMetadata$disease[fix_ind] <- "melanoma;metastases_lung;metastases_nodes"

## Building the mapping file is described in `cMD_disease_compact.qmd` file

## Import the condition map
condition_map <- read.csv(file.path(proj_dir, "maps/cMD_condition_ontology.csv"), 
                          sep = ",", header = TRUE)
