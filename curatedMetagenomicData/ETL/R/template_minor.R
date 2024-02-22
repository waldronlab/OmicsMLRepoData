### Data dictionary for cMD attributes with minior update (e.g., lower-case column names)
### Required input: `filled_dd`
### dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData"



# dna_extraction_kit -----
dna_extraction_kit <- data.frame(
    col.name = "dna_extraction_kit",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Name of the DNA extraction kit",
    allowedvalues = "Qiagen|Gnome|MoBio|MPBio|NorgenBiotek|Illuminakit|Maxwell_LEV|PSP_Spin_Stool|Tiangen|PowerSoil|Chemagen|other|PowerSoilPro|ZR_Fecal_DNA_MiniPrep|KAMA_Hyper_Prep|thermo_fisher|QIAamp",
    ontology = NA
)

# pmid -----
pmid <- data.frame(
    col.name = "pmid",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Identifier of the main publication in PubMed",
    allowedvalues = "[0-9]{8}",
    ontology = NA
)

# ncbi_accession -----
ncbi_accession <- data.frame(
    col.name = "ncbi_accession",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "A semicolon-separated vector of NCBI accessions",
    allowedvalues = "[ES]R[SR][0-9]+",
    ontology = NA
)

# bmi -----
bmi <- data.frame(
    col.name = "bmi",
    col.class = "double",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "body mass index (EFO:0004340): An indicator of body density as determined by the relationship of BODY WEIGHT to BODY HEIGHT. BMI=weight (kg)/height squared (m2).",
    allowedvalues = "[0-9]+\\.?[0-9]*",
    ontology = NA
)


# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(dna_extraction_kit,
                                 pmid,
                                 ncbi_accession,
                                 bmi))

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, attr_dd)
