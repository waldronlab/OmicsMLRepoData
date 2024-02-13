### Data dictionary for: `location`
### Required input: `mapDir` and `filled_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"

# Load the map
location_map <- read.csv(file.path(mapDir, "cMD_location_map.csv"))

# location ----
curated_location <- data.frame(
    col.name = "location",
    col.class = "character",
    uniqueness = "unique", 
    requiredness = "required",
    multiplevalues = FALSE,
    description = "Location where subject lives",
    allowedvalues = paste(unique(location_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(location_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)