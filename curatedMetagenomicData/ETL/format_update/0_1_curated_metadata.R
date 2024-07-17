## cMD metadata format updating 06.24.24

##### body_site --------
## Separate the previous `body_subsite` information into `body_site_detailed`
newCols <- c("curated_body_site", "curated_body_site_details")
curated_all <- curated_all %>%
    tidyr::separate(curated_body_site, 
             into = newCols, sep = ";", extra = "merge")
newCols <- c("curated_body_site_ontology_term_id", "curated_body_site_details_ontology_term_id")
curated_all <- curated_all %>%
    tidyr::separate(curated_body_site_ontology_term_id, 
             into = newCols, sep = ";", extra = "merge")

#### probing_pocket_depth -----------------
## Switch the delimiter to separate multiple values to `<;>` instead of `;`
curated_all$curated_probing_pocket_depth <- gsub(";", "<;>", curated_all$curated_probing_pocket_depth)
curated_all$curated_probing_pocket_depth_ontology_term_id <- gsub(";", "<;>", curated_all$curated_probing_pocket_depth_ontology_term_id)

#### smoker -----------------
## Update the dictionary to include all (including both high/low resolution) terms
## Definition is supplemented with the instruction.

#### uncurated_metadata -----------------
## Switch the delimiter to separate multiple values to `<;>` instead of `;`
curated_all$curated_uncurated_metadata <- gsub(";", "<;>", curated_all$curated_uncurated_metadata)
