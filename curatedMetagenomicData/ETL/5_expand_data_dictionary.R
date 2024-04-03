### The required input is `expanded_dd` generated from `4_populate_data_dictionary_template.R`.
expanded_dd <- readr::read_csv(file.path(extDir, "cMD_data_dictionary.csv"))

suppressPackageStartupMessages({
    library(OmicsMLRepoCuration)
    library(dplyr)
})

# Populate data dictionary per attributes -----
## The scripts sourced below requires two inputs: `mapDir`, `scriptDir`, and `expanded_dd`
source(file.path(scriptDir, "template_new_attrs.R"))

# Order col.name column -------
required_cols <- c("study_name", "subject_id", "sample_id", 
                   "target_condition", "control", "country", 
                   "body_site")
required_ind <- c()
for (col in required_cols) {
    ind <- which(expanded_dd$col.name == col)
    required_ind <- c(required_ind, ind)
}
    
expanded_dd <- expanded_dd[-required_ind,] %>%
    dplyr::arrange(., col.name) %>% # alphabetical ordering of columns except the required cols
    dplyr::bind_rows(expanded_dd[required_ind, ], .)
