### This script upload cMD curation maps to Google Sheet
### Some maps were cleaned/ reorganized programmatically, so need to be updated in this direction.

# Upload curation maps to Google Sheet ----
url <- "https://docs.google.com/spreadsheets/d/1QSbB_b1DkfqOc7q5eHE0IDHSiGqNUyTE8d4GzbSEzjM/edit?usp=sharing"
ss <- googledrive::as_id(url)

new_map_names <- paste0("cMD_", new_maps)

for (new_map_name in new_map_names) {
    new_map_fname <- paste0(new_map_name, "_map.csv")
    tb <- read.csv(file.path(cmd_maps_dir, new_map_fname))
    googlesheets4::write_sheet(tb, ss = ss, sheet = new_map_name)
}
