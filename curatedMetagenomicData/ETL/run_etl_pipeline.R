#!/usr/bin/env Rscript

# ETL Pipeline Orchestrator for curatedMetagenomicData
# This script orchestrates all ETL steps with proper error handling and logging

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default values
steps_to_run <- "all"
config_file <- NULL
validate_only <- FALSE

# Parse arguments
if (length(args) > 0) {
    i <- 1
    while (i <= length(args)) {
        if (args[i] == "--steps") {
            steps_to_run <- args[i + 1]
            i <- i + 2
        } else if (args[i] == "--config") {
            config_file <- args[i + 1]
            i <- i + 2
        } else if (args[i] == "--validate-only") {
            validate_only <- TRUE
            i <- i + 1
        } else if (args[i] %in% c("--help", "-h")) {
            cat("Usage: Rscript run_etl_pipeline.R [OPTIONS]\n\n")
            cat("Options:\n")
            cat("  --steps STEPS        Comma-separated step IDs or 'all' (default: all)\n")
            cat("  --config FILE        Path to config file (default: config.yaml)\n")
            cat("  --validate-only      Run validation without executing steps\n")
            cat("  --help, -h           Show this help message\n\n")
            cat("Examples:\n")
            cat("  Rscript run_etl_pipeline.R\n")
            cat("  Rscript run_etl_pipeline.R --steps \"01,02,03\"\n")
            cat("  Rscript run_etl_pipeline.R --validate-only\n")
            quit(save = "no", status = 0)
        } else {
            i <- i + 1
        }
    }
}

# Source required modules
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

# Load configuration and helpers
suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
})

source(file.path(script_dir, "R/config_loader.R"))
source(file.path(script_dir, "R/utils/logging_helpers.R"))
source(file.path(script_dir, "R/validation.R"))
source(file.path(script_dir, "R/provenance.R"))

# Load configuration
config <- load_config(config_file)
init_logger(config, "etl_pipeline")

log_info("=== ETL Pipeline Starting ===")
log_info("Steps to run: %s", steps_to_run)
log_info("Validate only: %s", validate_only)

# Validation only mode
if (validate_only) {
    log_info("Running validation checks...")
    
    # Load data if exists
    curated_file <- get_output_path(config, "curated_all")
    validation_results <- list()
    
    if (file.exists(curated_file)) {
        curated_data <- readr::read_csv(curated_file, show_col_types = FALSE)
        validation_results$curated_metadata <- validate_curated_metadata(curated_data, config)
    } else {
        log_warn("Curated metadata file not found: %s", curated_file)
    }
    
    # Generate report
    report_file <- file.path(get_config_path(config, "log_dir", create_if_missing = TRUE),
                            sprintf("validation_report_%s.txt", format(Sys.time(), "%Y%m%d_%H%M%S")))
    generate_validation_report(validation_results, report_file)
    
    log_info("Validation complete. Report: %s", report_file)
    quit(save = "no", status = 0)
}

# Determine which steps to run
if (steps_to_run == "all") {
    steps <- sapply(config$etl_steps, function(x) x$id)
} else {
    steps <- strsplit(steps_to_run, ",")[[1]]
    steps <- trimws(steps)
}

log_info("Executing %d steps: %s", length(steps), paste(steps, collapse = ", "))

# Execute steps
step_durations <- c()
steps_executed <- c()
overall_success <- TRUE

for (step_id in steps) {
    # Find step configuration
    step_config <- NULL
    for (s in config$etl_steps) {
        if (s$id == step_id || s$name == step_id) {
            step_config <- s
            break
        }
    }
    
    if (is.null(step_config)) {
        log_error("Step '%s' not found in configuration", step_id)
        overall_success <- FALSE
        next
    }
    
    log_step_start(step_config$name, step_config$description)
    
    step_start_time <- Sys.time()
    
    tryCatch({
        # Execute step script
        step_script <- file.path(script_dir, step_config$script)
        
        if (!file.exists(step_script)) {
            stop(sprintf("Step script not found: %s", step_script))
        }
        
        source(step_script, local = new.env())
        
        step_duration <- as.numeric(difftime(Sys.time(), step_start_time, units = "secs"))
        step_durations[step_config$name] <- step_duration
        steps_executed <- c(steps_executed, step_config$name)
        
        log_step_complete(step_config$name, step_duration)
        
    }, error = function(e) {
        log_step_error(step_config$name, e$message)
        overall_success <- FALSE
    })
}

# Generate execution report
log_info("=== Pipeline Execution Complete ===")
log_info("Total steps executed: %d", length(steps_executed))
log_info("Total execution time: %.2f seconds", sum(step_durations))

report_file <- file.path(get_config_path(config, "log_dir", create_if_missing = TRUE),
                        sprintf("execution_report_%s.txt", format(Sys.time(), "%Y%m%d_%H%M%S")))
create_execution_report(steps_executed, step_durations, report_file)

if (overall_success) {
    log_info("✓ Pipeline completed successfully")
    quit(save = "no", status = 0)
} else {
    log_error("✗ Pipeline completed with errors")
    quit(save = "no", status = 1)
}