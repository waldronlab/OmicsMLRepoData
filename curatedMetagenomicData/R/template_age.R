##### Build a template for the curated-version of age-related cMD attributes
## Required input: `dir` 

age <- read.csv(file.path(dir, "maps/cMD_age_category_ontology.csv"))

## age
curated_age <- data.frame(
    col.name = "age",
    col.class = "integer",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Age of the subject using the unit specified under 'age_unit' column",
    allowedvalues = "[0-9]+",
    ontology = NA   
)

## age_unit
curated_age_unit <- data.frame(
    col.name = "age_unit",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional", # required if 'curated_age' is entered?
    multiplevalues = FALSE,
    description = "Unit of the subject's age specified under 'age' column",
    allowedvalues = "Day|Week|Month|Year",
    ontology = "NCIT:C25301|NCIT:C29844|NCIT:C29846|NCIT:C29848"   
)

## age_group
desc <- paste(age$curated_age_min, "<=", 
              age$curated_ontology, "<", age$curated_age_max)
curated_age_group <- data.frame(
    col.name = "age_group",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = paste(desc, collapse = "|"),
    allowedvalues = paste(age$curated_ontology, collapse = "|"),
    ontology = paste(basename(age$curated_ontology_term_id), collapse = "|")
)

## curated_age_all
curated_age_all <- do.call("rbind", list(curated_age, curated_age_unit, curated_age_group))
