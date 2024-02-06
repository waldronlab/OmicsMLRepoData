### Data dictionary for consolidated cMD attributes in their 'wide' form for curators
### Required input: ``final_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"





# response_to_therapy ----
RECIST <- data.frame(
    col.name = "RECIST",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Response Evaluation Criteria in Solid Tumors (RECIST, DICOM:112022): Standard parameters to be used when documenting response of solid tumors to treatment; a set of published rules that define when cancer patients improve (`respond`), stay the same (`stable`), or worsen (`progression`) during treatments. (from www.recist.com)",
    allowedvalues = "RECIST Complete Response|RECIST Partial Response|RECIST Progressive Disease|RECIST Stable Disease",
    ontology = "NCIT:C159715|NCIT:C159547|NCIT:C159716|NCIT:C159546"
) 

overall_response <- data.frame(
    col.name = "ORR",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Overal Response (ORR, NCIT:C96613): An assessment of the overall response of the disease to the therapy",
    allowedvalues = "Yes|No|NA",
    ontology = NA
) 

progression_free_survival <- data.frame(
    col.name = "PFS",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Progression Free Survival (PFS, EFO:0004920): Progression free survival is a measurement from a defined time point e.g. diagnosis and indicates that the disease did not progress i.e. tumours did not increase in size and new incidences did not occur. PFS is usually used in analyzing results of treatment for advanced disease.",
    allowedvalues = "Yes|No|NA",
    ontology = NA
) 

progression_free_survival_timepoint <- data.frame(
    col.name = "PFS_timepoint_months",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",  #<<<<<<<< required if `progression_free_survival` is entered
    multiplevalues = FALSE, 
    description = "A time point used to observe PFS. Unit is 'month'",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA
)

curated_response_to_therapy <- bind_rows(RECIST,
                                         overall_response,
                                         progression_free_survival,
                                         progression_free_survival_timepoint)
