### This script imports cMD curation maps created in Google Sheet

# Import curation maps from Google Sheet ----
url <- "https://docs.google.com/spreadsheets/d/1QSbB_b1DkfqOc7q5eHE0IDHSiGqNUyTE8d4GzbSEzjM/edit?usp=sharing"
ss <- googledrive::as_id(url)
all_sheets <- googlesheets4::sheet_names(ss)
attributes <- all_sheets[grep("cMD_", all_sheets)]

for (attribute in attributes) {
    res <- googlesheets4::read_sheet(ss, sheet = attribute)
    fname <- paste0(attribute, ".csv")
    write.csv(res, file.path(cmd_maps_dir, fname), row.names = FALSE)
}
