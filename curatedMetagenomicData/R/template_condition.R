##### Build a template for the curated-version of age-related cMD attributes
## Required input: `dir` 

disease_map <- read.csv(file.path(dir, "maps/cMD_study_condition_ontology.csv"))

## control
control <- data.frame(
    col.name = "control",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = FALSE,
    description = "Whether the sample is control, case, or not used in the study",
    allowedvalues = "Study Control|Case|Not Used",
    ontology = "NCIT:C142703|NCIT:C49152|NCIT:C69062"   
)

## disease
disease <- data.frame(
    col.name = "disease",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = TRUE,
    description = "Reported disease/condition type(s) for a participant. 'Healthy' if disease(s)/condition(s) assessed under a given study is not detected",
    allowedvalues = paste(unique(disease_map$curated_ontology_term), collapse = "|"),
    ontology = paste(unique(basename(disease_map$curated_ontology_term_id)), collapse = "|")     
)

## target_condition
pheno_map <- read.csv(file.path(dir, "maps/cMD_target_condition_map.csv"))

phenotype <- data.frame(
    col.name = "target_condition",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = TRUE,
    description = "Main phenotype(s)/condition(s) of interest for a given study",
    # Because target_condition can take multiple values
    allowedvalues = paste(unique(pheno_map$target_condition), collapse = ";") %>% 
        strsplit(., ";") %>% 
        unlist %>% 
        unique %>% 
        paste(., collapse = "|"),
    ontology = paste(unique(pheno_map$target_condition_term_id), collapse = ";") %>% 
        strsplit(., ";") %>% 
        unlist %>% 
        unique %>% 
        paste(., collapse = "|")     
)

## curated_disease_all
curated_disease_all <- do.call("rbind", list(control, disease, phenotype))