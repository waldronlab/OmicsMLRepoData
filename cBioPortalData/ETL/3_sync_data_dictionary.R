### This script sync the data dictionary created in Google Sheet to GitHub
### repository. Main data entry happens in Google Sheet which GitHub version
### is for user facing, so do not make any major modification outside of 
### Google Sheet. 

cbio_dd_dir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/data_dictionary/"

url <- "https://docs.google.com/spreadsheets/d/1t2GTvDpgIrR84_ECoft6bQbb2qUr9RoeFtLZWM-ZRDI/edit?usp=sharing"
ss <- googledrive::as_id(url)
dd <- googlesheets4::read_sheet(ss = ss, sheet = "data_dictionary_all")
write.csv(dd,
          file.path(cbio_dd_dir, "cBioPortal_data_dictionary.csv"),
          row.names = FALSE)
