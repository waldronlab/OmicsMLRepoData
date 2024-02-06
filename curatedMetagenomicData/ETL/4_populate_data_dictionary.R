### Once the data dictionary template is assembled using the merging schema 
### (check `3_assemble_data_dictionary_template.R`), its contents - such as 
### uniqueness, requiredness, and description - are manually populated in 
### this script.

### The required input is `template_dd` generated from `3_assemble_data_dictionary_template.R`.


suppressPackageStartupMessages({
    library(OmicsMLRepoCuration)
    library(dplyr)
})

# Populate data dictionary per attributes -----
## The scripts sourced below requires two inputs: `mapDir`, `scriptDir`, and `final_dd`
source(file.path(scriptDir, "template_age.R"))
source(file.path(scriptDir, "template_bodysite.R"))
source(file.path(scriptDir, "template_condition.R"))
source(file.path(scriptDir, "template_location.R"))
source(file.path(scriptDir, "template_others.R"))
source(file.path(scriptDir, "template_treatment.R"))


# # Export to Google Drive
# url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
# ss <- googledrive::as_id(url)
# googlesheets4::write_sheet(final_dd, 
#                            ss = ss, 
#                            sheet = "cMD_data_dictionary")
