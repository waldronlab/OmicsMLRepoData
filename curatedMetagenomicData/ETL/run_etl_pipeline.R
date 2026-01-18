#!/usr/bin/env Rscript

#' Master ETL Pipeline Orchestrator for curatedMetagenomicData
#'
#' This script orchestrates the entire ETL pipeline, executing steps in sequence
#' with proper logging, validation, and error handling.
#'
#' Usage:
#'   Rscript run_etl_pipeline.R [--steps STEPS] [--config CONFIG_FILE] [--validate-only]
#'
#' Examples:
#'   # Run all steps
#'   Rscript run_etl_pipeline.R
#'
#'   # Run specific steps
#'   Rscript run_etl_pipeline.R --steps "01,02,03"
#'
#'   # Run with custom config
#'   Rscript run_etl_pipeline.R --config my_config.yaml
#'
#'   # Validation only (no execution)
#'   Rscript run_etl_pipeline.R --validate-only

suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
})

# Source required modules
script_dir <- dirname(sys.frame(1)$ofile)
if (is.null(script_dir) || script_dir == "") {
    script_dir <- "curatedMetagenomicData/ETL"
}

source(file.path(script_dir, "R/config_loader.R"))
source(file.path(script_dir, "R/utils/logging_helpers.R"))
source(file.path(script_dir, "R/utils/data_helpers.R"))
source(file.path(script_dir, "R/validation.R"))
source(file.path(script_dir, "R/provenance.R"))

#' Parse Command Line Arguments
parse_args <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    parsed <- list(
        steps = "all",
        config_file = NULL,
        validate_only = FALSE
    )
    
    i <- 1
    while (i <= length(args)) {
        if (args[i] == "--steps") {
            parsed$steps <- args[i + 1]
            i <- i + 2
        } else if (args[i] == "--config") {
            parsed$config_file <- args[i + 1]
            i <- i + 2
        } else if (args[i] == "--validate-only") {
            parsed$validate_only <- TRUE
            i <- i + 1
        } else if (args[i] == "--help" || args[i] == "-h") {
            cat("Usage: Rscript run_etl_pipeline.R [OPTIONS]\n\n")
            cat("Options:\n")
            cat("  --steps STEPS        Comma-separated step IDs to run (default: all)\n")
            cat("  --config FILE        Path to config YAML file\n")
            cat("  --validate-only      Only run validation, don't execute steps\n")
            cat("  --help, -h           Show this help message\n\n")
            cat("Examples:\n")
            cat("  Rscript run_etl_pipeline.R\n")
            cat("  Rscript run_etl_pipeline.R --steps 01,02,03\n")
            cat("  Rscript run_etl_pipeline.R --validate-only\n")
            quit(status = 0)
        } else {
            i <- i + 1
        }
    }
    
    return(parsed)
}

#' Get Steps to Execute
get_steps_to_execute <- function(config, steps_arg) {
    all_steps <- config$etl_steps
    
    if (steps_arg == "all") {
        return(all_steps)
    }
    
    # Parse comma-separated step IDs
    requested_ids <- strsplit(steps_arg, ",")[[1]]
    requested_ids <- trimws(requested_ids)
    
    # Filter steps
    selected_steps <- list()
    for (step in all_steps) {
        if (step$id %in% requested_ids || step$name %in% requested_ids) {
            selected_steps[[length(selected_steps) + 1]] <- step
        }
    }
    
    if (length(selected_steps) == 0) {
        stop(sprintf("No valid steps found for: %s", steps_arg))
    }
    
    return(selected_steps)
}

#' Execute Single ETL Step
execute_step <- function(step, config) {
    step_id <- step$id
    step_name <- step$name
    script_file <- step$script
    
    log_step_start(step_name, step$description)
    
    start_time <- Sys.time()
    
    tryCatch({
        # Build script path
        script_path <- file.path(get_config_path(config, "etl_dir"), script_file)
        
        if (!file.exists(script_path)) {
            log_error("Script not found: %s", script_path)
            return(list(
                success = FALSE,
                error = sprintf("Script not found: %s", script_path),
                duration = 0
            ))
        }
        
        # Execute script
        log_info("Executing: %s", script_path)
        source(script_path, local = TRUE)
        
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
        
        log_step_complete(step_name, duration)
        
        # Write provenance
        log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
        write_provenance_log(log_dir, step_name, list(
            step_id = step_id,
            script = script_file,
            duration_seconds = duration
        ))
        
        return(list(
            success = TRUE,
            duration = duration
        ))
        
    }, error = function(e) {
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
        
        log_step_error(step_name, e$message)
        
        return(list(
            success = FALSE,
            error = e$message,
            duration = duration
        ))
    })
}

#' Run Validation Only
run_validation <- function(config) {
    log_info("Running validation checks...")
    
    validation_results <- list()
    
    # Validate curated metadata
    curated_file <- get_output_path(config, "curated_all")
    if (file.exists(curated_file)) {
        log_info("Validating curated metadata...")
        curated_data <- safe_read_csv(curated_file)
        if (!is.null(curated_data)) {
            validation_results$curated_metadata <- validate_curated_metadata(curated_data, config)
        }
    } else {
        log_warn("Curated metadata file not found: %s", curated_file)
    }
    
    # Validate merging schema
    ms_file <- get_output_path(config, "merging_schema")
    if (file.exists(ms_file)) {
        log_info("Validating merging schema...")
        ms_data <- safe_read_csv(ms_file)
        if (!is.null(ms_data)) {
            validation_results$merging_schema <- validate_merging_schema(ms_data)
        }
    } else {
        log_warn("Merging schema file not found: %s", ms_file)
    }
    
    # Validate data dictionary
    dd_file <- get_output_path(config, "data_dictionary")
    if (file.exists(dd_file)) {
        log_info("Validating data dictionary...")
        dd_data <- safe_read_csv(dd_file)
        if (!is.null(dd_data)) {
            validation_results$data_dictionary <- validate_data_dictionary(dd_data, config)
        }
    } else {
        log_warn("Data dictionary file not found: %s", dd_file)
    }
    
    # Validate curation maps
    maps_dir <- get_config_path(config, "maps_dir")
    validation_results$curation_maps <- validate_curation_maps(maps_dir, config)
    
    # Generate validation report
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    report_file <- file.path(log_dir, sprintf("validation_report_%s.txt",
                                               format(Sys.time(), "%Y%m%d_%H%M%S")))
    
    report <- generate_validation_report(validation_results, report_file)
    
    # Print summary to console
    cat("\n")
    cat(paste(report, collapse = "\n"))
    cat("\n")
    
    # Return overall status
    all_passed <- all(sapply(validation_results, function(x) {
        if (is.list(x$overall)) x$overall$passed %||% FALSE else FALSE
    }))
    
    return(all_passed)
}

#' Main Pipeline Function
run_etl_pipeline <- function(steps = "all", config_file = NULL, validate_only = FALSE) {
    # Load configuration
    config <- load_config(config_file)
    
    # Initialize logging
    init_logger(config, "etl_pipeline")
    
    log_info("=" %R% 70)
    log_info("curatedMetagenomicData ETL Pipeline")
    log_info("=" %R% 70)
    
    print_config_summary(config)
    
    # Validation-only mode
    if (validate_only) {
        log_info("Running in validation-only mode")
        success <- run_validation(config)
        
        if (success) {
            log_info("Validation PASSED")
            return(0)
        } else {
            log_error("Validation FAILED")
            return(1)
        }
    }
    
    # Get steps to execute
    steps_to_run <- get_steps_to_execute(config, steps)
    
    log_info("Steps to execute: %d", length(steps_to_run))
    for (step in steps_to_run) {
        log_info("  - %s: %s", step$id, step$name)
    }
    log_info("")
    
    # Track execution
    step_results <- list()
    step_durations <- c()
    all_success <- TRUE
    
    # Execute steps
    for (step in steps_to_run) {
        result <- execute_step(step, config)
        step_results[[step$name]] <- result
        step_durations[step$name] <- result$duration
        
        if (!result$success) {
            log_error("Step '%s' failed: %s", step$name, result$error)
            all_success <- FALSE
            
            # Stop on error
            log_error("Pipeline stopped due to error")
            break
        }
    }
    
    # Generate execution report
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    report_file <- file.path(log_dir, sprintf("execution_report_%s.txt",
                                               format(Sys.time(), "%Y%m%d_%H%M%S")))
    
    executed_steps <- names(step_results[sapply(step_results, function(x) x$success)])
    
    create_execution_report(
        steps_executed = executed_steps,
        step_durations = step_durations,
        output_file = report_file
    )
    
    # Final summary
    log_info("")
    log_info("=" %R% 70)
    if (all_success) {
        log_info("Pipeline completed SUCCESSFULLY")
        log_info("Total time: %.2f seconds", sum(step_durations))
    } else {
        log_error("Pipeline completed with ERRORS")
    }
    log_info("=" %R% 70)
    
    return(ifelse(all_success, 0, 1))
}

#' Repeat string operator
`%R%` <- function(str, n) {
    paste(rep(str, n), collapse = "")
}

#' NULL-coalescing operator
`%||%` <- function(a, b) {
    if (is.null(a)) b else a
}

# Main execution
if (!interactive()) {
    args <- parse_args()
    
    exit_code <- tryCatch({
        run_etl_pipeline(
            steps = args$steps,
            config_file = args$config_file,
            validate_only = args$validate_only
        )
    }, error = function(e) {
        cat(sprintf("FATAL ERROR: %s\n", e$message), file = stderr())
        1
    })
    
    quit(status = exit_code)
}
