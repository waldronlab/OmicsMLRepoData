### This script sync the cBioPortal data dictionary created in Google Sheet 
### to GitHub repository. Main data entry happens in Google Sheet which 
### GitHub version is for user facing, so do not make any major modification 
### outside of Google Sheet. 

cbio_dd_dir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/data_dictionary/"

url <- "https://docs.google.com/spreadsheets/d/1t2GTvDpgIrR84_ECoft6bQbb2qUr9RoeFtLZWM-ZRDI/edit?usp=sharing"
ss <- googledrive::as_id(url)

# ## All
# dd_all <- googlesheets4::read_sheet(ss = ss, sheet = "data_dictionary_all")
# write.csv(dd_all,
#           file.path(cbio_dd_dir, "cBioPortal_data_dictionary_all.csv"),
#           row.names = FALSE)

## Release
dd_release <- googlesheets4::read_sheet(ss = ss, sheet = "data_dictionary")
dd_columns <- c("ColName", "ColClass", "Unique",
                 "Required", "MultipleValues", "Description", "AllowedValues", 
                 "Delimiter", "Separater", "DynamicEnum", "DynamicEnumProperty")
dd_release <- dd_release |> dplyr::select(dd_columns)
if (ncol(dd_release) != length(dd_columns)) {stop("Double-check subset")}

write.csv(dd_release,
          file.path("~/OmicsMLRepo/OmicsMLRepoData/inst/extdata/cBioPortal_data_dictionary.csv"),
          row.names = FALSE)

## Release for OmicsMLRepoR
file.copy(from = file.path(cbio_dd_dir, "cBioPortal_data_dictionary.csv"),
          to = "~/OmicsMLRepo/OmicsMLRepoR/inst/extdata/cBioPortal_data_dictionary.csv",
          overwrite = TRUE)
