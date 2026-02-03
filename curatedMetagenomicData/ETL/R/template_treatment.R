### Data dictionary for: `treatment`, `antibiotics_current_use`
### Required input: `mapDir` and `filled_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"


treatment_map <- read.csv(file.path(mapDir, "cMD_treatment_map.csv"))  %>%
    .[order(.$curated_ontology_term),]
abx_map <- read.csv(file.path(mapDir, "cMD_antibiotic_map.csv")) %>%
    .[order(.$curated_ontology_term),]

# treatment -----
curated_treatment <- data.frame(
    col.name = "treatment",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = TRUE,
    description = "Medication(s)/treatment(s) applied to the subject",
    allowedvalues = paste(unique(treatment_map$curated_ontology_term,
                                 abx_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(treatment_map$curated_ontology_term_id),
                            basename(abx_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# antibiotics_current_use ----
# abx <- read.csv(file.path(dataDir, "curated_treatment.csv"))
curated_abx_current_use <- data.frame(
    col.name = "antibiotics_current_use",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Antibiotics current usage. `Yes` for currently using and `No` for not using",
    allowedvalues = "Yes|No|NA",
    ontology = NA  
)


# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(curated_treatment, curated_abx_current_use))

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)
