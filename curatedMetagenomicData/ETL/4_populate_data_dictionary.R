### Once the data dictionary template is assembled using the merging schema 
### (check `3_assemble_data_dictionary_template.R`), its contents - such as 
### uniqueness, requiredness, and description - are manually populated in 
### this script.

### The required input is `filled_dd` generated from `3_assemble_data_dictionary_template.R`.


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
source(file.path(scriptDir, "template_sub_cols.R"))
source(file.path(scriptDir, "template_treatment.R"))


# # Populate data dictionary per attributes -----
# ## The scripts sourced below requires two inputs: `mapDir`, `scriptDir`, and `final_dd`
# templates <- list.files(scriptDir)
# for (template in templates) {
#     source(file.path(scriptDir, template))
# }