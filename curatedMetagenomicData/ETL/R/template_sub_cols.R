### Data dictionary for consolidated cMD attributes in their 'wide' form for curators
### Required input: ``final_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"


# biomarkers ----
biomarker_map <- read.csv(file.path(mapDir, "cMD_biomarker_map.csv"))
curated_biomarker <- data.frame(
    col.name = "biomarker",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "A measurable and quantifiable characteristic or substance that serves as an indicator of a biological state, condition, or process within an organism.",
    allowedvalues = paste(unique(biomarker_map$curated_ontology), collapse = "|"),
    ontology = paste(unique(biomarker_map$curated_ontology_term_id), collapse = "|")     
) 

# biomarker_value <- data.frame(
#     col.name = "biomarker_value",
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "",
#     allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
#     ontology = NA    
# ) 
# 
# biomarker_unit <- data.frame(
#     col.name = "biomarker_unit",
#     col.class = "character",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "",
#     allowedvalues = NA,
#     ontology = NA     
# ) 
# 
# curated_biomarkers <- bind_rows(biomarker_name,
#                                 biomarker_value,
#                                 biomarker_unit)

# curated_neonatal ----
preterm_birth <- data.frame(
    col.name = "neonatal_preterm_birth",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Birth when a fetus is less than 37 weeks and 0 days gestational age (NCIT:C92861).",
    allowedvalues = "Yes|No",
    ontology = NA  
)

birth_weight <- data.frame(
    col.name = "neonatal_birth_weight",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The mass or quantity of heaviness of an individual at BIRTH. (EFO:0004344)",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA  
)

delivery_procedure <- data.frame(
    col.name = "neonatal_delivery_procedure",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Description of the method by which a fetus is delivered. (NCIT:C81179)",
    allowedvalues = "Elective Cesarean Delivery|Emergency Cesarean Delivery|Cesarean Section|Vaginal Delivery",
    ontology = "NCIT:C114141|NCIT:C92772|NCIT:C46088|NCIT:C81303"  
)

feeding_method <- data.frame(
    col.name = "neonatal_feeding_method",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Infant feeding methods. 'Breastfeeding' refers feeding milk from human (include non-mother's and through bottle), 'mixed_feeding' refers both breastfeeding and formula feeding",
    allowedvalues = "exclusively_breastfeeding|exclusively_formula_feeding|mixed_feeding|no_breastfeeding",
    ontology = NA  
)

gestational_age <- data.frame(
    col.name = "neonatal_gestational_age",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The age of the conceptus, beginning from the time of FERTILIZATION. (EFO:0005112)",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA  
)

# Data dictionary for curated attributes ----
curated_neonatal <- do.call("rbind", list(preterm_birth, 
                                          birth_weight, 
                                          delivery_procedure, 
                                          feeding_method,
                                          gestational_age))


# curated_obgyn -----
obgyn_pregnancy <- data.frame(
    col.name = "obgyn_pregnancy",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The pregnancy status of an individual.",
    allowedvalues = "Pregnant|Not Pregnant",
    ontology = "NCIT:C124295|NCIT:C82475"     
) 

obgyn_birth_control <- data.frame(
    col.name = "obgyn_birth_control",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Use of birth control pill (Oral Contraceptive)",
    allowedvalues = "Yes|No",
    ontology = NA     
) 

obgyn_menopause <- data.frame(
    col.name = "obgyn_menopause",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "An indicator as to whether the female subject is in menopause",
    allowedvalues = "Premenopausal|Postmenopausal",
    ontology = "NCIT:C15491|NCIT:C15421"     
) 

obgyn_lactating <- data.frame(
    col.name = "obgyn_lactating",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "An indication that the subject is currently producing milk. (NCIT:C82463)",
    allowedvalues = "Yes|No",
    ontology = NA    
) 

curated_obgyn <- bind_rows(obgyn_pregnancy,
                           obgyn_birth_control,
                           obgyn_menopause,
                           obgyn_lactating)



# disease_response ----
RECIST <- data.frame(
    col.name = "disease_response_recist",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Response Evaluation Criteria in Solid Tumors (RECIST, DICOM:112022): Standard parameters to be used when documenting response of solid tumors to treatment; a set of published rules that define when cancer patients improve (`respond`), stay the same (`stable`), or worsen (`progression`) during treatments. (from www.recist.com)",
    allowedvalues = "RECIST Complete Response|RECIST Partial Response|RECIST Progressive Disease|RECIST Stable Disease",
    ontology = "NCIT:C159715|NCIT:C159547|NCIT:C159716|NCIT:C159546"
) 

overall_response <- data.frame(
    col.name = "disease_response_orr",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Overal Response (ORR, NCIT:C96613): An assessment of the overall response of the disease to the therapy",
    allowedvalues = "Yes|No|NA",
    ontology = NA
) 

progression_free_survival <- data.frame(
    col.name = "disease_response_pfs",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Progression Free Survival (PFS, EFO:0004920): Progression free survival is a measurement from a defined time point e.g. diagnosis and indicates that the disease did not progress i.e. tumours did not increase in size and new incidences did not occur. PFS is usually used in analyzing results of treatment for advanced disease.",
    allowedvalues = "Yes|No|NA",
    ontology = NA
) 

progression_free_survival_timepoint <- data.frame(
    col.name = "disease_response_pfs_month",
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


# tumor_staging ------
ajcc <- data.frame(
    col.name = "tumor_staging_ajcc",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "A system to describe the amount and spread of cancer in a patient's body",
    allowedvalues = "0|I|II|III|IV|III/IV",
    ontology = NA     
) 

tnm <- data.frame(
    col.name = "tumor_staging_tnm",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "A system to describe the amount and spread of cancer in a patient's body",
    allowedvalues = "t[1-4]n[0-3]m[0-1]",
    ontology = NA     
)

curated_tumor_staging <- bind_rows(ajcc, tnm)

# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(curated_biomarker,
                                 curated_neonatal,
                                 curated_obgyn,
                                 curated_response_to_therapy,
                                 curated_tumor_staging))

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)

