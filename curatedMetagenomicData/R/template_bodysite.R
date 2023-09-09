##### Build a template for the curated-version of bodysite-related cMD attributes
## Required input: `dir` 

bodysite_map <- read.csv(file.path(dir, "maps/cMD_bodysite_ontology.csv"))

bodysite <- bodysite_map[which(bodysite_map$bodysite_values == "Yes"),]
bodysubsite <- bodysite_map[which(bodysite_map$bodysite_values == "No"),]

## bodysite
curated_bodysite <- data.frame(
    col.name = "bodysite",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Subject's bodysite the given sample was collected from",
    allowedvalues = paste(unique(bodysite$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(bodysite$curated_ontology_term_id)), 
                     collapse = "|")     
)

## body_subsite
curated_bodysubsite <- data.frame(
    col.name = "body_subsite",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Subject's body subsite the given sample was collected from. Should be more specific information than bodysite",
    allowedvalues = paste(unique(bodysubsite$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(bodysubsite$curated_ontology_term_id)), 
                     collapse = "|")     
)
