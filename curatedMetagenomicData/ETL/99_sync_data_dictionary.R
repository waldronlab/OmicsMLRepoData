### After the initial assembly of data dictionary, we keep the Google 
### Drive version as a gold standard and make a modification only on it. 


### Google Drive ---------------------------------------------------------------
url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
ss <- googledrive::as_id(url)
cmd_dd <- googlesheets4::read_sheet(ss = ss, sheet = "cMD_data_dictionary")

## Sanity check
(isTRUE(cmd_dd$multipleClasses)) {sum(!is.na(cmd_dd$Delimiter))}


## ODM template (on Google Drive)

# Load the cMD data dictionary from GitHub
cmd_dd_gh <- 




extDir <- "~/OmicsMLRepo/OmicsMLRepoData/inst/extdata"
write.csv(final_data_dictionary, 
          file.path(extDir, "cMD_data_dictionary.csv"), 
          row.names = FALSE)








cmd_dd_dir <- "~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicDAta/data_dictionary/"
cmd_dd






