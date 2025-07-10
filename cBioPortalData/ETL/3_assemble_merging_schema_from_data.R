### This script create the merging schema table from the curated data files
### `0_curated_metadata_table.R` should be run before this script to provide
### the required inputs.


# Create the template table for merging schema (`cbio_ms`). 
# It includes age, body site, sex, disease, treatment, and ancestry.
allCols <- colnames(curated_all)
srcCols <- allCols[grep("_source", allCols)]
srcCols <- srcCols[srcCols != "curated_treatment_source"] # remove the generic version

cbio_ms <- as.data.frame(matrix(nrow = length(srcCols), ncol = 7))
colnames(cbio_ms) <- c("curated_field",
                       "curated_field_completeness",
                       "curated_field_unique_values",
                       "original_field",
                       "original_field_num",
                       "original_field_completeness",
                       "original_field_unique_values")
cbio_ms$curated_field <- gsub("curated_|_source", "", srcCols)

# Import the original cBioPortal metadata
if (!exists(x = "ori")) {
    dir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/source"
    fpath <- file.path(dir, "cBioPortal_all_clinicalData_combined_2023-05-18.rds")
    ori <- readRDS(fpath)
}

# Load the curation-related functions
devtools::load_all("~/OmicsMLRepo/OmicsMLRepoCuration/")

# Completeness/Unique values for source columns -------
for (i in seq_along(curatedAll)) {
    dat <- get(curatedAll[i])
    source_ind <- grep("curated_.*_source", colnames(dat))
    source_cols <- colnames(dat)[source_ind]
    
    for (j in seq_along(source_cols)) {
        curated_field <- gsub("curated_|_source", "", source_cols[j])
        ind <- which(cbio_ms$curated_field == curated_field)
        
        ## Extract original fields used for curation
        ori_field <- dat[, source_cols[j]] %>%
            ## Double-check which deliminators should be included
            tidyr::separate_longer_delim(., colnames(.), "<;>") %>%
            tidyr::separate_longer_delim(., colnames(.), "::") %>%
            tidyr::separate_longer_delim(., colnames(.), ";") %>%
            unique() %>%
            na.omit() %>% 
            .[[colnames(.)]]
        ori_field <- ori_field[ori_field != "NA"]
        ori_field <- gsub("DIAGNOSIS.AGE", "DIAGNOSIS AGE", ori_field) # manual fix of spacing syntax auto-change in Excel
        
        cbio_ms$original_field_num[ind] <- length(ori_field)
        original_field <- paste0(ori_field, collapse = ";") #<<<<<<<<<< double-check deliminators
        cbio_ms$original_field[ind] <- original_field
        
        ## Calculate original fields completeness
        completeness <- checkCurationStats(
            fields_list = original_field,
            check = "completeness",
            DB = ori)
        cbio_ms$original_field_completeness[ind] <- completeness
        
        ## Calculate original fields uniqueness
        unique_values <- checkCurationStats(
            fields_list = original_field,
            check = "unique",
            DB = ori)
        cbio_ms$original_field_unique_values[ind] <- unique_values
    }
}

# Add newly created attributes - `study_design` and `target_condition`.
# These don't have source attributes.
cbio_ms <- add_row(cbio_ms, 
                   curated_field = c("study_design", "target_condition"))


# Completeness/Unique values for curated columns -------
curatedCols <- cbio_ms$curated_field
curatedCols <- curatedCols[-grep("treatment_", curatedCols)] # Exclude treatment_*

for (i in seq_along(curatedCols)) {
    curated_colname <- paste0("curated_", curatedCols[i])
    ind <- which(cbio_ms$curated_field == curatedCols[i])
    
    completeness <- checkCurationStats(
        fields_list = curated_colname,
        check = "completeness",
        DB = curated_all)
    cbio_ms$curated_field_completeness[ind] <- completeness
    
    unique_values <- checkCurationStats(
        fields_list = curated_colname,
        check = "unique",
        DB = curated_all)
    cbio_ms$curated_field_unique_values[ind] <- unique_values
}


# Completeness/Unique values for treatment_* columns -------
## treatment_only metadata table has different dimension than the whole
## metadata table, so we should set the size of universe separately.
trt_dir <- "~/OmicsMLRepo/OmicsMLRepoData/cBioPortalData/cBioPortal_treatment"
trt <- readRDS(file.path(trt_dir, "data/separated_curated_treatment.rds"))
trt_regexpr <- "^curated_treatment_(name|type|dose|number|start|end|frequency|duration|status|reason|group|notes)$"
main_trt_cols <- grep(trt_regexpr, colnames(trt))
main_trt_col_names <- colnames(trt)[main_trt_cols]
main_trt <- trt[c(1, main_trt_cols)]

main_trt[main_trt == "NA"] <- NA
trt_nonNA <- main_trt %>%
    group_by(curation_id) %>%
    ## Sample with no 'real' value will be 0
    summarise(across(main_trt_col_names, ~ any(!is.na(.x)) %>% as.numeric))

univSize <- nrow(ori)
trt_completeness <- round((colSums(trt_nonNA[main_trt_col_names])/univSize)*100, 2)
trt_uniqueness <- main_trt %>%
    summarise(across(main_trt_col_names, ~ unique(.x) %>% na.omit %>% length))

## Add treatment_* columns statistics to the main merging schema
insert_ind <- which(cbio_ms$curated_field %in% gsub("curated_", "", main_trt_col_names))
cbio_ms$curated_field_completeness[insert_ind] <- as.vector(trt_completeness)
cbio_ms$curated_field_unique_values[insert_ind] <- as.numeric(trt_uniqueness)
