### Format for Release
### This script creates a user-facing release version of the curated metadata
### with only curated attributes (no legacy/source columns, no ontology term IDs)
### Refactored version with configuration management and logging

# Load required libraries
suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
})

# Source helper modules
get_script_dir <- function() {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    
    if (length(file_arg) > 0) {
        script_path <- sub("^--file=", "", file_arg)
        return(dirname(normalizePath(script_path)))
    }
    
    return("curatedMetagenomicData/ETL")
}

script_dir <- get_script_dir()

source(file.path(script_dir, "R/config_loader.R"))
source(file.path(script_dir, "R/utils/logging_helpers.R"))
source(file.path(script_dir, "R/utils/data_helpers.R"))
source(file.path(script_dir, "R/provenance.R"))

# Load configuration
config <- load_config()
init_logger(config, "06_format_for_release")

log_step_start("06_format_for_release", 
               "Format curated metadata for user-facing release")

tryCatch({
    # Load curated_all table
    curated_all_file <- get_output_path(config, "curated_all")
    
    if (!file.exists(curated_all_file)) {
        stop(sprintf("Curated metadata file not found: %s. Run step 02 first.", curated_all_file))
    }
    
    log_info("Loading curated metadata from: %s", curated_all_file)
    curated_all <- safe_read_csv(curated_all_file)
    
    log_data_summary(curated_all, "Input curated metadata")
    
    # Remove accessory columns
    log_info("Removing accessory columns for release")
    
    # Remove `original_` columns
    ori_ind <- grep("^original_", colnames(curated_all))
    if (length(ori_ind) > 0) {
        log_info("Removing %d 'original_' columns", length(ori_ind))
        curated_all_cleaned <- curated_all[, -ori_ind, drop = FALSE]
    } else {
        curated_all_cleaned <- curated_all
    }
    
    # Remove `_source` columns
    source_ind <- grep("_source$", colnames(curated_all_cleaned))
    if (length(source_ind) > 0) {
        log_info("Removing %d '_source' columns", length(source_ind))
        curated_all_cleaned <- curated_all_cleaned[, -source_ind, drop = FALSE]
    }
    
    # Remove `curated_` prefix
    log_info("Removing 'curated_' prefix from column names")
    updated_col_names <- gsub("^curated_", "", colnames(curated_all_cleaned))
    colnames(curated_all_cleaned) <- updated_col_names
    
    # Add metadata attributes
    log_info("Adding package and timestamp metadata")
    curated_all_cleaned$package <- "cMD"
    curated_all_cleaned$last_updated <- Sys.time()
    
    # Apply format updates if script exists
    format_script <- file.path(script_dir, "format_update/6_1_release.R")
    if (file.exists(format_script)) {
        log_info("Applying format updates from 6_1_release.R")
        tryCatch({
            source(format_script)
        }, error = function(e) {
            log_warn("Format update script failed: %s", e$message)
        })
    }
    
    # Organize columns in proper order
    log_info("Organizing column order")
    
    allCols <- colnames(curated_all_cleaned)
    
    # Define column groups
    required_cols <- c(
        "study_name", "subject_id", "sample_id", "curation_id", 
        "target_condition", "target_condition_ontology_term_id",
        "control", "control_ontology_term_id", 
        "country", "country_ontology_term_id", 
        "body_site", "body_site_ontology_term_id",
        "body_site_details", "body_site_details_ontology_term_id"
    )
    
    annot_cols <- c("package", "last_updated")
    
    # Filter to only existing columns
    required_cols <- required_cols[required_cols %in% allCols]
    annot_cols <- annot_cols[annot_cols %in% allCols]
    
    optional_cols <- allCols[!allCols %in% c(required_cols, annot_cols)]
    optional_cols <- sort(optional_cols)
    
    col_order <- c(required_cols, optional_cols, annot_cols)
    
    # Reorder columns
    cmd_meta_release <- curated_all_cleaned[, col_order, drop = FALSE]
    
    log_info("Final column count: %d (required: %d, optional: %d, annotation: %d)",
             ncol(cmd_meta_release), length(required_cols), 
             length(optional_cols), length(annot_cols))
    
    # Add provenance
    cmd_meta_release <- add_provenance(cmd_meta_release, "06_format_for_release", config)
    
    # Save output
    output_file <- get_output_path(config, "curated_release")
    log_info("Writing release metadata to: %s", output_file)
    
    safe_write_csv(cmd_meta_release, output_file, backup = TRUE)
    
    log_data_summary(cmd_meta_release, "Release metadata")
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "06_format_for_release", list(
        input_rows = nrow(curated_all),
        input_columns = ncol(curated_all),
        output_rows = nrow(cmd_meta_release),
        output_columns = ncol(cmd_meta_release),
        required_columns = length(required_cols),
        optional_columns = length(optional_cols),
        output_file = output_file
    ))
    
    log_step_complete("06_format_for_release")
    
}, error = function(e) {
    log_step_error("06_format_for_release", e$message)
    stop(e)
})
