#' Validation Functions for ETL Pipeline
#'
#' This module provides comprehensive validation functions for ETL outputs.
#' It validates curated metadata, merging schemas, data dictionaries, and curation maps.

# Source helper functions
source_helpers <- function() {
    script_dir <- dirname(sys.frame(1)$ofile)
    if (is.null(script_dir) || script_dir == "") {
        script_dir <- "curatedMetagenomicData/ETL/R"
    }
    
    source(file.path(script_dir, "utils/validation_helpers.R"))
    source(file.path(script_dir, "utils/ontology_helpers.R"))
    source(file.path(script_dir, "utils/logging_helpers.R"))
}

#' Validate Curated Metadata
#'
#' Performs comprehensive validation of the curated metadata table
#'
#' @param data Curated metadata data frame
#' @param config Configuration list from load_config()
#' @return List with validation results
#' @export
validate_curated_metadata <- function(data, config) {
    log_info("Validating curated metadata...")
    
    results <- list()
    
    # Check required columns
    required_cols <- config$required_columns$curated_metadata
    results$required_columns <- tryCatch({
        check_required_columns(data, required_cols, "curated_metadata")
        list(passed = TRUE, message = "All required columns present")
    }, error = function(e) {
        list(passed = FALSE, message = e$message)
    })
    
    # Check for duplicate sample_ids
    results$duplicate_samples <- check_duplicates(data, "sample_id")
    
    # Check for missing values in critical columns
    critical_cols <- c("study_name", "subject_id", "sample_id")
    results$critical_nulls <- check_missing_values(data, critical_cols, allow_missing = FALSE)
    
    # Check ontology ID formats for key columns
    ontology_cols <- grep("_ontology_term_id$", colnames(data), value = TRUE)
    results$ontology_formats <- list()
    
    for (col in ontology_cols) {
        term_ids <- data[[col]][!is.na(data[[col]]) & data[[col]] != ""]
        
        if (length(term_ids) > 0) {
            # Check each term ID (may be pipe-delimited)
            invalid_count <- 0
            for (term_string in term_ids) {
                validation <- validate_ontology_ids(term_string)
                if (!validation$valid) {
                    invalid_count <- invalid_count + 1
                }
            }
            
            results$ontology_formats[[col]] <- list(
                passed = invalid_count == 0,
                column = col,
                total_checked = length(term_ids),
                invalid_count = invalid_count
            )
        }
    }
    
    # Check data types
    expected_types <- list(
        study_name = "character",
        subject_id = "character",
        sample_id = "character"
    )
    results$data_types <- check_column_types(data, expected_types)
    
    # Overall validation status
    all_passed <- all(sapply(results, function(x) {
        if (is.list(x) && "passed" %in% names(x)) {
            return(x$passed)
        } else if (is.list(x)) {
            return(all(sapply(x, function(y) y$passed %||% TRUE)))
        }
        return(TRUE)
    }))
    
    results$overall <- list(
        passed = all_passed,
        total_rows = nrow(data),
        total_columns = ncol(data)
    )
    
    if (all_passed) {
        log_info("Curated metadata validation PASSED")
    } else {
        log_warn("Curated metadata validation FAILED - see details")
    }
    
    return(results)
}

#' Validate Merging Schema
#'
#' Validates the merging schema structure and content
#'
#' @param merging_schema Merging schema data frame
#' @param curated_data Optional curated metadata to verify coverage
#' @return List with validation results
#' @export
validate_merging_schema <- function(merging_schema, curated_data = NULL) {
    log_info("Validating merging schema...")
    
    results <- list()
    
    # Check required columns in merging schema
    required_cols <- c("ori_column", "curated_column")
    results$required_columns <- tryCatch({
        check_required_columns(merging_schema, required_cols, "merging_schema")
        list(passed = TRUE, message = "All required columns present")
    }, error = function(e) {
        list(passed = FALSE, message = e$message)
    })
    
    # Check for duplicates in column mappings
    results$duplicate_mappings <- check_duplicates(merging_schema, "ori_column")
    
    # Check coverage of curated columns if curated_data provided
    if (!is.null(curated_data)) {
        curated_cols <- colnames(curated_data)
        mapped_cols <- unique(merging_schema$curated_column)
        
        unmapped_cols <- setdiff(curated_cols, mapped_cols)
        
        results$column_coverage <- list(
            passed = length(unmapped_cols) == 0,
            curated_columns = length(curated_cols),
            mapped_columns = length(mapped_cols),
            unmapped_columns = unmapped_cols
        )
    }
    
    # Overall validation
    all_passed <- all(sapply(results, function(x) x$passed %||% TRUE))
    results$overall <- list(passed = all_passed)
    
    if (all_passed) {
        log_info("Merging schema validation PASSED")
    } else {
        log_warn("Merging schema validation FAILED - see details")
    }
    
    return(results)
}

#' Validate Data Dictionary
#'
#' Validates the data dictionary completeness and structure
#'
#' @param data_dict Data dictionary data frame
#' @param config Configuration list from load_config()
#' @param curated_data Optional curated metadata to verify coverage
#' @return List with validation results
#' @export
validate_data_dictionary <- function(data_dict, config, curated_data = NULL) {
    log_info("Validating data dictionary...")
    
    results <- list()
    
    # Check required fields
    required_fields <- config$required_columns$data_dictionary
    results$required_fields <- tryCatch({
        check_required_columns(data_dict, required_fields, "data_dictionary")
        list(passed = TRUE, message = "All required fields present")
    }, error = function(e) {
        list(passed = FALSE, message = e$message)
    })
    
    # Check for duplicate column definitions
    results$duplicate_columns <- check_duplicates(data_dict, "ColName")
    
    # Check completeness of key fields
    results$description_completeness <- check_completeness(data_dict, "Description", min_completeness = 0.9)
    results$allowed_values_completeness <- check_completeness(data_dict, "AllowedValues", min_completeness = 0.5)
    
    # Check coverage of curated columns if provided
    if (!is.null(curated_data)) {
        curated_cols <- grep("^curated_", colnames(curated_data), value = TRUE)
        dict_cols <- data_dict$ColName
        
        missing_cols <- setdiff(curated_cols, dict_cols)
        
        results$column_coverage <- list(
            passed = length(missing_cols) == 0,
            curated_columns = length(curated_cols),
            documented_columns = sum(curated_cols %in% dict_cols),
            missing_columns = missing_cols
        )
    }
    
    # Check ontology IDs in data dictionary
    if ("ontology" %in% colnames(data_dict)) {
        ontology_entries <- data_dict$ontology[!is.na(data_dict$ontology) & 
                                                data_dict$ontology != ""]
        
        invalid_count <- 0
        for (ont_string in ontology_entries) {
            validation <- validate_ontology_ids(ont_string)
            if (!validation$valid) {
                invalid_count <- invalid_count + 1
            }
        }
        
        results$ontology_ids <- list(
            passed = invalid_count == 0,
            total_checked = length(ontology_entries),
            invalid_count = invalid_count
        )
    }
    
    # Overall validation
    all_passed <- all(sapply(results, function(x) x$passed %||% TRUE))
    results$overall <- list(passed = all_passed)
    
    if (all_passed) {
        log_info("Data dictionary validation PASSED")
    } else {
        log_warn("Data dictionary validation FAILED - see details")
    }
    
    return(results)
}

#' Validate Curation Maps
#'
#' Validates all curation maps in a directory
#'
#' @param maps_dir Directory containing curation map CSV files
#' @param config Configuration list from load_config()
#' @return List with validation results for each map
#' @export
validate_curation_maps <- function(maps_dir, config) {
    log_info("Validating curation maps in: %s", maps_dir)
    
    if (!dir.exists(maps_dir)) {
        log_error("Maps directory not found: %s", maps_dir)
        return(list(overall = list(passed = FALSE, error = "Directory not found")))
    }
    
    map_files <- list.files(maps_dir, pattern = "^cMD_.*_map\\.csv$", full.names = TRUE)
    
    if (length(map_files) == 0) {
        log_warn("No curation map files found in: %s", maps_dir)
        return(list(overall = list(passed = TRUE, warning = "No maps found")))
    }
    
    log_info("Found %d curation maps to validate", length(map_files))
    
    results <- list()
    
    for (map_file in map_files) {
        map_name <- tools::file_path_sans_ext(basename(map_file))
        
        tryCatch({
            map_data <- readr::read_csv(map_file, show_col_types = FALSE)
            
            # Validate structure
            validation <- validate_curation_map_structure(map_data, map_name)
            results[[map_name]] <- validation
            
            if (validation$passed) {
                log_debug("  ✓ %s", map_name)
            } else {
                log_warn("  ✗ %s: %d issues", map_name, length(validation$issues))
            }
            
        }, error = function(e) {
            log_error("  ✗ %s: Failed to load - %s", map_name, e$message)
            results[[map_name]] <- list(
                passed = FALSE,
                map_name = map_name,
                error = e$message
            )
        })
    }
    
    # Overall validation
    all_passed <- all(sapply(results, function(x) x$passed))
    results$overall <- list(
        passed = all_passed,
        total_maps = length(map_files),
        passed_maps = sum(sapply(results, function(x) x$passed)),
        failed_maps = sum(sapply(results, function(x) !x$passed))
    )
    
    if (all_passed) {
        log_info("All curation maps validation PASSED")
    } else {
        log_warn("Some curation maps validation FAILED")
    }
    
    return(results)
}

#' Generate Validation Report
#'
#' Creates a comprehensive validation report from all validation results
#'
#' @param validation_results List of validation results from various checks
#' @param output_file Optional file path to save report
#' @return Character vector with report lines
#' @export
generate_validation_report <- function(validation_results, output_file = NULL) {
    report <- c()
    report <- c(report, "=" %R% 70)
    report <- c(report, "ETL VALIDATION REPORT")
    report <- c(report, sprintf("Generated: %s", Sys.time()))
    report <- c(report, "=" %R% 70)
    report <- c(report, "")
    
    for (section_name in names(validation_results)) {
        report <- c(report, sprintf("## %s", toupper(section_name)))
        report <- c(report, "-" %R% 70)
        
        section_results <- validation_results[[section_name]]
        
        if (is.list(section_results)) {
            overall_status <- section_results$overall$passed %||% "UNKNOWN"
            report <- c(report, sprintf("Status: %s", 
                                        ifelse(overall_status, "PASSED ✓", "FAILED ✗")))
            
            # Add details
            for (key in names(section_results)) {
                if (key != "overall") {
                    result <- section_results[[key]]
                    if (is.list(result) && "passed" %in% names(result)) {
                        status <- ifelse(result$passed, "✓", "✗")
                        report <- c(report, sprintf("  %s %s", status, key))
                        
                        if (!result$passed && "message" %in% names(result)) {
                            report <- c(report, sprintf("     Error: %s", result$message))
                        }
                    }
                }
            }
        }
        
        report <- c(report, "")
    }
    
    # Overall summary
    report <- c(report, "=" %R% 70)
    report <- c(report, "OVERALL SUMMARY")
    report <- c(report, "=" %R% 70)
    
    total_checks <- sum(sapply(validation_results, function(x) {
        if (is.list(x$overall)) 1 else 0
    }))
    
    passed_checks <- sum(sapply(validation_results, function(x) {
        if (is.list(x$overall)) x$overall$passed %||% FALSE else FALSE
    }))
    
    report <- c(report, sprintf("Total validation sections: %d", total_checks))
    report <- c(report, sprintf("Passed: %d", passed_checks))
    report <- c(report, sprintf("Failed: %d", total_checks - passed_checks))
    
    all_passed <- passed_checks == total_checks
    report <- c(report, "")
    report <- c(report, sprintf("FINAL STATUS: %s", 
                                ifelse(all_passed, "PASSED ✓", "FAILED ✗")))
    report <- c(report, "=" %R% 70)
    
    # Save to file if requested
    if (!is.null(output_file)) {
        dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
        writeLines(report, output_file)
        log_info("Validation report saved to: %s", output_file)
    }
    
    return(report)
}

#' Repeat string operator
`%R%` <- function(str, n) {
    paste(rep(str, n), collapse = "")
}

#' NULL-coalescing operator
`%||%` <- function(a, b) {
    if (is.null(a)) b else a
}
