### Data dictionary for: `control`, `disease`, `target_condition`
### Required input: `mapDir` and `filled_dd`

### projDir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"
### mapDir <- file.path(projDir, "maps")


# control ----
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

# disease ----
disease_map <- read.csv(file.path(mapDir, "cMD_disease_map.csv")) %>%
    .[order(.$curated_ontology_term),]
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

# target_condition ----
target_condition_map <- read.csv(file.path(mapDir, "cMD_target_condition_map.csv")) %>%
    .[order(.$curated_ontology_term),]

target_condition <- data.frame(
    col.name = "target_condition",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = TRUE,
    description = "Main phenotype(s)/condition(s) of interest for a given study",
    # Because target_condition can take multiple values
    allowedvalues = paste(unique(target_condition_map$curated_ontology_term), collapse = ";") %>% 
        strsplit(., ";") %>% 
        unlist %>% 
        unique %>% 
        paste(., collapse = "|"),
    ontology = paste(unique(target_condition_map$curated_ontology_term_id), collapse = ";") %>% 
        strsplit(., ";") %>% 
        unlist %>% 
        unique %>% 
        paste(., collapse = "|")     
)


# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(control, disease, target_condition))

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)