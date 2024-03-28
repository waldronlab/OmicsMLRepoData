library(OmicsMLRepoR)

# Load the biomarker curation map -----
url <- "https://docs.google.com/spreadsheets/d/1QSbB_b1DkfqOc7q5eHE0IDHSiGqNUyTE8d4GzbSEzjM/edit?usp=sharing"
ss <- googledrive::as_id(url)
biomarker_map <- googlesheets4::read_sheet(ss = ss, sheet = "cMD_biomarker_map")

# Format the column name -----------
unitColNames <- paste0(gsub(" Measurement", "", biomarker_map$curated_ontology_term), 
                       "_in_", biomarker_map$curated_unit) %>%
    gsub(" ", "_", .) %>%
    gsub("_in_n.a.", "", .)

biomarker_map$curated_column_names <- unitColNames
biomarker_map$curated_ontology_term_db <- get_ontologies(biomarker_map$curated_ontology_term_id)

# Update the biomarker map in Google Sheet -------------
url <- "https://docs.google.com/spreadsheets/d/1QSbB_b1DkfqOc7q5eHE0IDHSiGqNUyTE8d4GzbSEzjM/edit?usp=sharing"
ss <- googledrive::as_id(url)
googlesheets4::write_sheet(biomarker_map, ss = ss, sheet = "cMD_biomarker_map")