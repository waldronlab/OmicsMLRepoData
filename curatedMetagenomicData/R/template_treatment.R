##### Build a template for the curated-version of treatment cMD attributes
## Required input: `dir` 

treatment_map <- read.csv(file.path(dir, "maps/cMD_treatment_ontology.csv"))
abx_map <- read.csv(file.path(dir, "maps/cMD_antibiotic_ontology.csv"))

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