### Data dictionary for the bodysite-related cMD attributes: `bodysite` and `body_subsite`
### Required input: `mapDir` and `final_dd` 
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"

bodysite_map <- read.csv(file.path(mapDir, "cMD_bodysite_map.csv"))

bodysite <- bodysite_map[which(bodysite_map$bodysite_values == "Yes"),]
bodysubsite <- bodysite_map[which(bodysite_map$bodysite_values == "No"),]

# bodysite ----
curated_bodysite <- data.frame(
    col.name = "body_site",
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

# body_subsite ----
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

# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(curated_bodysite, curated_bodysubsite))

# Add the content to data dictionary template, `final_dd` ----
final_dd <- fillDataDictionary(final_dd, attr_dd)
