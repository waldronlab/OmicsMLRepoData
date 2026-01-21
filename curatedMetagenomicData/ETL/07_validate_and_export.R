### Final Validation and Export
### This script validates all ETL outputs and exports to configured targets
### New script for comprehensive final validation and multi-target sync

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
source(file.path(script_dir, "R/validation.R"))
source(file.path(script_dir, "R/provenance.R"))

# Load configuration
config <- load_config()
init_logger(config, "07_validate_and_export")

log_step_start("07_validate_and_export", "Final validation and export to all targets")

tryCatch({
    # Load all outputs
    log_info("Loading ETL outputs for validation")
    
    curated_all_file <- get_output_path(config, "curated_all")
    curated_release_file <- get_output_path(config, "curated_release")
    merging_schema_file <- get_output_path(config, "merging_schema")
    data_dict_file <- get_output_path(config, "data_dictionary")
    
    # Check which files exist
    files_exist <- c(
        curated_all = file.exists(curated_all_file),
        curated_release = file.exists(curated_release_file),
        merging_schema = file.exists(merging_schema_file),
        data_dict = file.exists(data_dict_file)
    )
    
    log_info("File availability:")
    for (name in names(files_exist)) {
        status <- if (files_exist[name]) "✓" else "✗"
        log_info("  %s %s", status, name)
    }
    
    # Load existing files
    curated_all <- NULL
    curated_release <- NULL
    merging_schema <- NULL
    data_dict <- NULL
    
    if (files_exist["curated_all"]) {
        curated_all <- safe_read_csv(curated_all_file)
    }
    
    if (files_exist["curated_release"]) {
        curated_release <- safe_read_csv(curated_release_file)
    }
    
    if (files_exist["merging_schema"]) {
        merging_schema <- safe_read_csv(merging_schema_file)
    }
    
    if (files_exist["data_dict"]) {
        data_dict <- safe_read_csv(data_dict_file)
    }
    
    # Run all validations
    log_info("=" %R% 60)
    log_info("Running validation checks...")
    log_info("=" %R% 60)
    
    validation_results <- list()
    
    # Validate curated metadata
    if (!is.null(curated_all)) {
        log_info("Validating curated metadata...")
        validation_results$curated_metadata <- validate_curated_metadata(curated_all, config)
    } else {
        log_warn("Skipping curated metadata validation (file not found)")
    }
    
    # Validate merging schema
    if (!is.null(merging_schema)) {
        log_info("Validating merging schema...")
        validation_results$merging_schema <- validate_merging_schema(merging_schema, curated_all)
    } else {
        log_warn("Skipping merging schema validation (file not found)")
    }
    
    # Validate data dictionary
    if (!is.null(data_dict)) {
        log_info("Validating data dictionary...")
        validation_results$data_dictionary <- validate_data_dictionary(data_dict, config, curated_all)
    } else {
        log_warn("Skipping data dictionary validation (file not found)")
    }
    
    # Validate curation maps
    log_info("Validating curation maps...")
    maps_dir <- get_config_path(config, "maps_dir")
    validation_results$curation_maps <- validate_curation_maps(maps_dir, config)
    
    # Generate validation report
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    report_file <- file.path(log_dir, sprintf("validation_report_%s.txt", format(Sys.time(), "%Y%m%d_%H%M%S")))
    
    log_info("=" %R% 60)
    log_info("Generating validation report...")
    report <- generate_validation_report(validation_results, report_file)
    
    # Check if all validations passed
    all_passed <- all(sapply(validation_results, function(x) {
        if (is.list(x$overall)) x$overall$passed else TRUE
    }))
    
    if (!all_passed) {
        log_warn("=" %R% 60)
        log_warn("VALIDATION CHECKS FAILED")
        log_warn("Review report: %s", report_file)
        log_warn("=" %R% 60)
    } else {
        log_info("=" %R% 60)
        log_info("ALL VALIDATION CHECKS PASSED ✓")
        log_info("=" %R% 60)
    }
    
    # Export to sync targets
    log_info("=" %R% 60)
    log_info("Syncing to configured targets...")
    log_info("=" %R% 60)
    
    # Collect files to sync
    files_to_sync <- list()
    
    if (files_exist["curated_all"]) {
        files_to_sync[["curated_all"]] <- curated_all_file
    }
    
    if (files_exist["curated_release"]) {
        files_to_sync[["curated_release"]] <- curated_release_file
    }
    
    if (files_exist["merging_schema"]) {
        files_to_sync[["merging_schema"]] <- merging_schema_file
    }
    
    if (files_exist["data_dict"]) {
        files_to_sync[["data_dict"]] <- data_dict_file
    }
    
    log_info("Files to sync: %d", length(files_to_sync))
    
    sync_success <- TRUE
    synced_count <- 0
    
    if (!is.null(config$sync_targets) && length(config$sync_targets) > 0) {
        log_info("Sync targets configured: %d", length(config$sync_targets))
        
        for (name in names(files_to_sync)) {
            file_path <- files_to_sync[[name]]
            
            if (file.exists(file_path)) {
                log_info("Syncing: %s", basename(file_path))
                
                success <- sync_file_to_targets(file_path, config$sync_targets, create_dirs = TRUE)
                
                if (success) {
                    synced_count <- synced_count + 1
                    log_info("  ✓ Synced to all targets")
                } else {
                    sync_success <- FALSE
                    log_warn("  ✗ Failed to sync to some targets")
                }
            } else {
                log_warn("  ✗ File not found: %s", basename(file_path))
            }
        }
        
        log_info("Successfully synced %d/%d files", synced_count, length(files_to_sync))
    } else {
        log_info("No sync targets configured, skipping file sync")
    }
    
    # GCS upload if configured
    if (!is.null(config$gcs) && !is.null(config$gcs$bucket)) {
        log_info("=" %R% 60)
        log_info("GCS bucket configured: %s", config$gcs$bucket)
        log_info("Note: GCS upload requires manual configuration or separate tooling")
        log_info("=" %R% 60)
    }
    
    # Write provenance
    write_provenance_log(log_dir, "07_validate_and_export", list(
        validation_passed = all_passed,
        files_validated = sum(files_exist),
        files_synced = synced_count,
        sync_targets = length(config$sync_targets %||% list()),
        validation_report = report_file
    ))
    
    # Final summary
    log_info("=" %R% 60)
    log_info("FINAL SUMMARY")
    log_info("=" %R% 60)
    log_info("Validation: %s", if (all_passed) "PASSED ✓" else "FAILED ✗")
    log_info("Files validated: %d", sum(files_exist))
    log_info("Files synced: %d/%d", synced_count, length(files_to_sync))
    log_info("Validation report: %s", report_file)
    log_info("=" %R% 60)
    
    if (!all_passed) {
        log_warn("Pipeline completed with validation warnings. Review the validation report.")
    }
    
    log_step_complete("07_validate_and_export")
    
}, error = function(e) {
    log_step_error("07_validate_and_export", e$message)
    stop(e)
})

#' Repeat string operator
`%R%` <- function(str, n) {
    paste(rep(str, n), collapse = "")
}

#' NULL-coalescing operator
`%||%` <- function(a, b) {
    if (is.null(a)) b else a
}
