### Data dictionary for: `location`
### Required input: `mapDir` and `final_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"

# Load the map
location_map <- read.csv(file.path(mapDir, "cMD_location_map.csv"))

# location ----
curated_location <- data.frame(
    col.name = "location",
    col.class = "character",
    uniqueness = "unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Location where subject lives",
    allowedvalues = paste(unique(location_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(location_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# Add the content to data dictionary template, `final_dd` ----
final_dd <- fillDataDictionary(final_dd, attr_dd)