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
## The scripts sourced below requires two inputs: `mapDir`, `scriptDir`, and `filled_dd`
source(file.path(scriptDir, "template_age.R"))
source(file.path(scriptDir, "template_bodysite.R"))
source(file.path(scriptDir, "template_condition.R"))
source(file.path(scriptDir, "template_minor.R"))
source(file.path(scriptDir, "template_others.R"))
source(file.path(scriptDir, "template_sub_cols.R"))
source(file.path(scriptDir, "template_treatment.R"))
source(file.path(scriptDir, "template_ppd.R"))

# Order col.name column -------
required_cols <- c("study_name", "subject_id", "sample_id", 
                   "target_condition", "control", "country", 
                   "body_site")
required_ind <- c()
for (col in required_cols) {
    ind <- which(filled_dd$col.name == col)
    required_ind <- c(required_ind, ind)
}
    
filled_dd <- filled_dd[-required_ind,] %>%
    dplyr::arrange(., col.name) %>% # alphabetical ordering of columns except the required cols
    dplyr::bind_rows(filled_dd[required_ind, ], .)

# Add summary of ontologies used (`ontoDB` column) ----------
ontologies <- lapply(filled_dd$ontology, 
                     function(x) {x %>% strsplit(., "\\|") %>% 
                             unlist %>% get_ontologies(.) %>% 
                             table %>% sort(decreasing = TRUE) %>% 
                             names %>% paste(., collapse = "|")}) %>% unlist
ontologies[ontologies == ""] <- NA
filled_dd$ontoDB <- ontologies

# # Populate data dictionary per attributes -----
# ## The scripts sourced below requires two inputs: `mapDir`, `scriptDir`, and `filled_dd`
# templates <- list.files(scriptDir)
# templates <- templates[grep(".R$", templates)]
#
# for (template in templates) {
#     source(file.path(scriptDir, template))
# }


## Update the format -----------------------
source("~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/ETL/format_update/4_1_dictionary.R")

