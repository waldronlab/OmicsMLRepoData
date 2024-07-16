### This script imports cMD curation maps created in Google Sheet

# Import curation maps from Google Sheet ----
url <- "https://docs.google.com/spreadsheets/d/1QSbB_b1DkfqOc7q5eHE0IDHSiGqNUyTE8d4GzbSEzjM/edit?usp=sharing"
ss <- googledrive::as_id(url)
all_sheets <- googlesheets4::sheet_names(ss)
attributes <- all_sheets[grep("cMD_", all_sheets)]

for (attribute in attributes) {
    res <- googlesheets4::read_sheet(ss, sheet = attribute)
    map_colnames <- c("original_value","curated_ontology_term",
                      "curated_ontology_term_id","curated_ontology_term_db")
    
    ## Column name sanity check
    if (!all(map_colnames %in% colnames(res))) {
        msg <- paste("The mapping table for the attributes", attribute,
                     "lacks the required columns.")
        next(msg)
    }
    
    fname <- paste0(attribute, ".csv")
    write.csv(res, file.path(cmd_maps_dir, fname), row.names = FALSE)
}
