### Data dictionary for consolidated cMD attributes
### Required input: `mapDir`, `dataDir`, and `filled_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"


# dietary_restriction -----
curated_dietary_restriction <- data.frame(
    col.name = "dietary_restriction",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Dietary regime (partial match to SNOMED:182922004 or SNOMED:162536008)",
    allowedvalues = "omnivore|vegan|vegetarian|high_fiber|low_fiber|high_gluten|low_gluten",
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
    allowedvalues = ".+",
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

# westernized ------
curated_westernized <- data.frame(
    col.name = "westernized",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Subject adopt or be influenced by the cultural, economic, or political systems of Europe and North America.",
    allowedvalues = "Yes|No",
    ontology = NA     
)

# smoker ----
curated_smoker <- data.frame(
    col.name = "smoker",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Tobacco smoking behavior. Assign `Non-smoker (finding)` only when the past smoking behavior information is unavailable.",
    allowedvalues = "smoker (finding)|Non-smoker (finding)|Ex-smoker (finding)|Never smoked tobacco (finding)",
    ontology = "SNOMED:77176002|SNOMED:8392000|SNOMED:8517006|SNOMED:266919005"
) 

# sex ----
# sex <- read.csv(file.path(dataDir, "curated_sex.csv"))
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
    multiplevalues = TRUE,
    description = "Additional information that doesn't belong to the existing fields",
    allowedvalues = ".+",
    ontology = NA   
)

# hla ------
hla <- read.csv(file.path(mapDir, "cMD_hla_map.csv")) %>%
    .[order(.$curated_ontology_term),]
curated_hla <- data.frame(
    col.name = "hla",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = TRUE,
    description = "HLA complex. A family of proteins that are essential for the presentation of peptide antigens on cell surfaces that modulate the host defensive activities of T-cells. This protein family includes major histocompatibility complex (MHC) class I and class II proteins.",
    allowedvalues = sapply(hla$curated_ontology_term, strsplit, split = ";") %>%
        unlist %>% unique %>% paste0(collapse = "|"),
    ontology = sapply(hla$curated_ontology_term_id, strsplit, split = ";") %>%
        unlist %>% unique %>% paste0(collapse = "|")
)

# feces_phenotype ----
# feces_phenotype_metric <- data.frame(
#     col.name = "feces_phenotype_metric",
#     col.class = "character",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Measurements collected from stool sample, including observation, chemical test, and diagnostic procedure",
#     allowedvalues = "Bristol stool form score (observable entity)|Calprotectin Measurement|Harvey-Bradshaw Index Clinical Classification",
#     ontology = "SNOMED:443172007|NCIT:C82005|NCIT:C191036"     
# ) 
# 
# feces_phenotype_value <- data.frame(
#     col.name = "feces_phenotype_value",
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Measured value for the metric specified under 'feces_phenotype_metric'",
#     allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
#     ontology = NA     
# ) 
# 
# curated_feces_phenotype <- bind_rows(feces_phenotype_metric,
#                                      feces_phenotype_value)
curated_feces_phenotype <- data.frame(
    col.name = "feces_phenotype",
    col.class = "character",
    uniqueness = "non-unique",
    requiredness = "optional",
    multiplevalues = TRUE,
    description = "Measurements collected from stool sample, including observation, chemical test, and diagnostic procedure",
    allowedvalues = "Bristol stool form score (observable entity)|Calprotectin Measurement|Harvey-Bradshaw Index Clinical Classification",
    ontology = "SNOMED:443172007|NCIT:C82005|NCIT:C191036"
)

# country ----
country_map <- read.csv(file.path(mapDir, "cMD_country_map.csv")) %>%
    .[order(.$curated_ontology_term),]
curated_country <- data.frame(
    col.name = "country",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = FALSE,
    description = "Location where subject lives and/or data was collected",
    allowedvalues = paste(unique(country_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(country_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# ancestry ----
ancestry_map <- read.csv(file.path(mapDir, "cMD_ancestry_map.csv")) %>%
    .[order(.$curated_ontology_term),]
curated_ancestry <- data.frame(
    col.name = "ancestry",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = FALSE,
    description = "Population category defined using ancestry informative markers (AIMs) based on genetic/genomic data (children of HANCESTRO:0004)",
    allowedvalues = paste(unique(ancestry_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(ancestry_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# ancestry_details ----
ancestry_details_map <- read.csv(file.path(mapDir, "cMD_ancestry_details_map.csv")) %>%
    .[order(.$curated_ontology_term),]
curated_ancestry_details <- data.frame(
    col.name = "ancestry_details",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "required",
    multiplevalues = TRUE,
    description = "Population category defined using ancestry informative markers (AIMs) based on genetic/genomic data (descendants of `ancestry`)",
    allowedvalues = paste(unique(ancestry_details_map$curated_ontology_term), 
                          collapse = "|"),
    ontology = paste(unique(basename(ancestry_details_map$curated_ontology_term_id)), 
                     collapse = "|")     
)

# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(curated_ancestry,
                                 curated_ancestry_details,
                                 curated_country,
                                 curated_dietary_restriction,
                                 curated_feces_phenotype,
                                 curated_fmt_id,
                                 curated_fmt_role,
                                 curated_hla,
                                 curated_westernized,
                                 # curated_probing_pocket_depth,
                                 # curated_response_to_therapy,
                                 curated_smoker,
                                 curated_sex,
                                 uncurated_metadata))

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)
