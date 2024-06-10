### This script adds the ontology term for dynamic enum for the selected
### attributes. 
### The required input is a data dictionary, `cmd_dd`.


suppressPackageStartupMessages({
    library(OmicsMLRepoCuration)
    library(dplyr)
})

target_attr <- c("biomarker", "body_site", "disease", "country",
                 "target_condition", "treatment")

cmd_dd <- addDynamicEnumNodes(target_attr[1], enum_dd) %>%
    addDynamicEnumNodes(target_attr[2], .) %>%
    addDynamicEnumNodes(target_attr[3], .) %>%
    addDynamicEnumNodes(target_attr[4], .) %>%
    addDynamicEnumNodes(target_attr[5], .) 
