##### Build a template for cMD attributes with binary values
## Required input: `dir` 

## sex
sex <- read.csv(file.path(dir, "data/curated_gender.csv"))
curated_sex <- data.frame(
    col.name = "sex",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Biological sex of the subject",
    allowedvalues = "Female|Male|NA",
    ontology = "NCIT:C16576|NCIT:C20197"   
)


## abx_current_use
abx <- read.csv(file.path(dir, "data/curated_treatment.csv"))
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