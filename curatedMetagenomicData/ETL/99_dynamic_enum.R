### This script adds the ontology term for dynamic enum for the selected attributes. 
### The required input is a data dictionary, `enum_dd`, with all the captured values


suppressPackageStartupMessages({
    library(OmicsMLRepoCuration)
    library(dplyr)
})

cmd_dd <- enum_dd
target_attr <- c("biomarker", "disease", "target_condition", "treatment")

for (i in seq_along(target_attr)) {

    attr_row_ind <- which(cmd_dd$ColName == target_attr[i]) # row index of the target attribute
    onto <- enum_dd %>% # all the captured values
        filter(ColName == target_attr[i]) %>% 
        pull(Ontology) 
    
    if (onto != "" & !is.na(onto)) {
        values <- onto %>% 
            stringr::str_split(., "\\|") %>% 
            unlist %>%
            stringr::str_replace("SNOMED:", "")
        enums <- mapNodes(values, cutoff = 0.9) %>%
            filter(num_original_covered > 1)
        
        # Assign the dynamic enum node that covers the most of the original values
        # Terms not covered by this enum node need to be further reviewed.
        coverage <- order(enums$num_original_covered, decreasing = TRUE)
        n <- 2 # top 2 most-covering nodes
        top_n_inds <- coverage[seq_len(n)] %>% .[!is.na(.)]
        cmd_dd$DynamicEnum[attr_row_ind] <- enums$ontology_term_id[top_n_inds] %>% paste(collapse = "|")
    }
}

