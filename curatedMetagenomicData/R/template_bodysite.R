##### Build a template for the curated-version of bodysite-related cMD attributes
## Required input: `dir` 

bodysite_map <- read.csv(file.path(dir, "maps/cMD_bodysite_ontology.csv"))

## bodysite
curated_bodysite <- data.frame(
    col.name = "bodysite",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Subject's bodysite the given sample was collected from",
    allowedvalues = paste(unique(bodysite_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(bodysite_map$curated_ontology_term_id)), 
                     collapse = "|")     
)