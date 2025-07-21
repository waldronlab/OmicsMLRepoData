## cMD metadata format updating 06.24.24
## Needs the output (`curated_all_cleaned`) from `6_format_for_release.R`

##### feces_phenotype -------------
## Combine the two columns (`metric` and `value`) into one column like `biomarker`
cols <- c("feces_phenotype_metric", "feces_phenotype_value", "feces_phenotype_metric_ontology_term_id")
merged_feces <- curated_all_cleaned %>%
    select(all_of(c("curation_id", cols, "package"))) %>%
    tidyr::separate_longer_delim(cols = cols, delim = ";") %>%
    mutate(
        feces_phenotype = case_when(
            feces_phenotype_metric != "NA" & feces_phenotype_value != "NA" ~ 
                paste(feces_phenotype_metric, feces_phenotype_value, sep = ":"),
            TRUE ~ NA_character_
        ),
        feces_phenotype_ontology_term_id = feces_phenotype_metric_ontology_term_id
    ) %>%
    select(all_of(c("curation_id", "feces_phenotype", "feces_phenotype_ontology_term_id"))) %>%
    getShortMetaTb(idCols = "curation_id", 
                   targetCol = c("feces_phenotype", "feces_phenotype_ontology_term_id"))


curated_all_cleaned <- curated_all_cleaned %>%
    dplyr::full_join(merged_feces, by = "curation_id") %>%
    dplyr::select(-all_of(cols))
