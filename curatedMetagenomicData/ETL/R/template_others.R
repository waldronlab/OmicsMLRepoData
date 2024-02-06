### Data dictionary for consolidated cMD attributes
### Required input: `mapDir`, `dataDir`, and `final_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"

library(googlesheets4)
url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
ss <- googledrive::as_id(url)
map <- read_sheet(ss, sheet = "merging_schema_allCols")

# biomarkers ----
biomarkers_map <- dplyr::filter(map, classification == "biomarker_name;biomarker_value;biomarker_unit")
biomarker_name <- data.frame(
    col.name = "biomarker_name",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "",
    allowedvalues = paste(unique(biomarkers_map$ontology), collapse = "|"),
    ontology = paste(unique(biomarkers_map$ontology_term_id), collapse = "|")     
) 

biomarker_value <- data.frame(
    col.name = "biomarker_value",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA    
) 

biomarker_unit <- data.frame(
    col.name = "biomarker_unit",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "",
    allowedvalues = NA,
    ontology = NA     
) 

curated_biomarkers <- bind_rows(biomarker_name,
                                biomarker_value,
                                biomarker_unit)

# dietary_restriction -----
curated_dietary_restriction <- data.frame(
    col.name = "dietary_restriction",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Dietary regime (partial match to SNOMED:182922004 or SNOMED:162536008)",
    allowedvalues = "omnivore|vegan|vegetarian",
    ontology = NA
)

# disease_stage ------
curated_disease_stage <- data.frame(
    col.name = "disease_stage",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "",
    allowedvalues = "0|I|II|III|IV|III/IV",
    ontology = NA     
) 

# fmt_id -----
curated_fmt_id <- data.frame(
    col.name = "fmt_id",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = TRUE,
    description = "The id assigned to the FMT (Fecal microbiota transplantation) participants in the study",
    allowedvalues = NA,
    ontology = NA     
) 

# fmt_role -----
curated_fmt_role <- data.frame(
    col.name = "fmt_role",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The role of the FMT (Fecal microbiota transplantation) participants. For recipient's samples, timing information (i.e., before or after FMT) is included as well.",
    allowedvalues = "Donor|Recipient (before procedure)|Recipient (after procedure)",
    ontology = NA     
)

# neonatal ------
curated_neonatal <- data.frame(
    col.name = "neonatal",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = NA,
    allowedvalues = NA,
    ontology = NA     
)

# westernized ------
curated_westernized <- data.frame(
    col.name = "westernized",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The typical Western (American) diet charactered by low in fruits and vegetables, and high in fat and sodium. Also, refers the diet consists of large portions, high calories, and excess sugar",
    allowedvalues = "Yes|No",
    ontology = NA     
)

# obgyn_pregnancy -----
curated_obgyn_pregnancy <- data.frame(
    col.name = "obgyn_pregnancy",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "The pregnancy status of an individual.",
    allowedvalues = "Pregnant|Not Pregnant",
    ontology = "NCIT:C124295|NCIT:C82475"     
) 

# obgyn_birth_control ----
curated_obgyn_birth_control <- data.frame(
    col.name = "obgyn_birth_control",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Use of birth control pill (Oral Contraceptive)",
    allowedvalues = "Yes|No",
    ontology = NA     
) 

## obgyn_menopause
curated_obgyn_menopause <- data.frame(
    col.name = "obgyn_menopause",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "An indicator as to whether the female subject is in menopause",
    allowedvalues = "Premenopausal|Postmenopausal",
    ontology = "NCIT:C15491|NCIT:C15421"     
) 

# probing_pocket_depth -----
curated_probing_pocket_depth <- data.frame(
    col.name = "probing_pocket_depth", #<<<<<<<<<<<<<<<< Switch to this?
    col.class = "numeric", #<<<<<<<<<< Updated depending on the definition of the abbreviation
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Depth of periodontal pocket (observable entity)",
    allowedvalues = "[0-9]+",
    ontology = ""     
) 

# smoker ----
curated_smoker <- data.frame(
    col.name = "smoker",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Tobacco smoking behavior",
    allowedvalues = "smoker (finding)|Non-smoker (finding)|Ex-smoker (finding)",
    ontology = "SNOMED:77176002|SNOMED:8392000|SNOMED:8517006"
) 

# sex ----
sex <- read.csv(file.path(dataDir, "curated_gender.csv"))
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

# uncurated_metadata ----
uncurated_metadata <- data.frame(
    col.name = "uncurated_metadata",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Additional information that doesn't belong to the existing fields",
    allowedvalues = ".+",
    ontology = NA   
)

# hla ------
hla <- read.csv(file.path(mapDir, "cMD_hla_map.csv"))
curated_hla <- data.frame(
    col.name = "hla",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "HLA complex. A family of proteins that are essential for the presentation of peptide antigens on cell surfaces that modulate the host defensive activities of T-cells. This protein family includes major histocompatibility complex (MHC) class I and class II proteins.",
    allowedvalues = sapply(hla$curated_ontology_term, strsplit, split = ";") %>%
        unlist %>% unique %>% paste0(collapse = "|"),
    ontology = sapply(hla$curated_ontology_term_id, strsplit, split = ";") %>%
        unlist %>% unique %>% paste0(collapse = "|")
)

# feces_phenotype ----
feces_phenotype_metric <- data.frame(
    col.name = "feces_phenotype_metric",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Measurements collected from stool sample, including observation, chemical test, and diagnostic procedure",
    allowedvalues = "Bristol stool form score (observable entity)|Calprotectin Measurement|Harvey-Bradshaw Index Clinical Classification",
    ontology = "SNOMED:443172007|NCIT:C82005|NCIT:C191036"     
) 

feces_phenotype_value <- data.frame(
    col.name = "feces_phenotype_value",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Measured value for the metric specified under 'feces_phenotype_metric'",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA     
) 

curated_feces_phenotype <- bind_rows(feces_phenotype_metric,
                                     feces_phenotype_value)


# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(curated_biomarkers,
                                 curated_dietary_restriction,
                                 curated_disease_stage,
                                 curated_feces_phenotype,
                                 curated_fmt_id,
                                 curated_fmt_role,
                                 curated_hla,
                                 curated_neonatal,
                                 curated_westernized,
                                 curated_obgyn_birth_control,
                                 curated_obgyn_menopause,
                                 curated_obgyn_pregnancy,
                                 curated_probing_pocket_depth,
                                 # curated_response_to_therapy,
                                 curated_smoker,
                                 curated_sex,
                                 uncurated_metadata))

# Add the content to data dictionary template, `final_dd` ----
final_dd <- fillDataDictionary(final_dd, attr_dd)
