#' Load and Validate ETL Configuration
#'
#' This module provides functions to load and validate the ETL pipeline configuration
#' from the config.yaml file. It handles path expansion and validation.
#'
#' @examples
#' config <- load_config()
#' project_dir <- get_config_path(config, "project_dir")

#' Load Configuration from YAML File
#'
#' @param config_file Path to the configuration YAML file. If NULL, uses default location.
#' @return List containing configuration settings
#' @export
load_config <- function(config_file = NULL) {
    if (!requireNamespace("yaml", quietly = TRUE)) {
        stop("Package 'yaml' is required but not installed. Please install it with: install.packages('yaml')")
    }
    
    if (is.null(config_file)) {
        # Default to config.yaml in ETL directory
        script_dir <- dirname(sys.frame(1)$ofile)
        if (is.null(script_dir) || script_dir == "") {
            # Fallback for interactive sessions
            config_file <- "curatedMetagenomicData/ETL/config.yaml"
        } else {
            config_file <- file.path(dirname(script_dir), "config.yaml")
        }
    }
    
    if (!file.exists(config_file)) {
        stop(sprintf("Configuration file not found: %s", config_file))
    }
    
    config <- yaml::read_yaml(config_file)
    
    # Expand tilde in paths
    config <- expand_config_paths(config)
    
    # Validate configuration
    validate_config(config)
    
    return(config)
}

#' Expand Tilde in Configuration Paths
#'
#' @param config Configuration list
#' @return Configuration list with expanded paths
expand_config_paths <- function(config) {
    if (!is.list(config)) {
        return(config)
    }
    
    for (name in names(config)) {
        if (is.character(config[[name]]) && length(config[[name]]) == 1) {
            # Expand tilde in character strings
            config[[name]] <- path.expand(config[[name]])
        } else if (is.list(config[[name]])) {
            # Recursively process nested lists
            config[[name]] <- expand_config_paths(config[[name]])
        }
    }
    
    return(config)
}

#' Validate Configuration Structure
#'
#' @param config Configuration list
#' @return TRUE if valid, stops with error if invalid
validate_config <- function(config) {
    required_sections <- c("paths", "google_sheets", "output_files", "etl_steps")
    
    for (section in required_sections) {
        if (!section %in% names(config)) {
            stop(sprintf("Missing required configuration section: %s", section))
        }
    }
    
    # Validate paths section
    required_paths <- c("project_dir", "etl_dir", "maps_dir", "output_dir", "script_dir")
    for (path_name in required_paths) {
        if (!path_name %in% names(config$paths)) {
            stop(sprintf("Missing required path in configuration: %s", path_name))
        }
    }
    
    # Validate Google Sheets URLs
    if (!"curation_maps_url" %in% names(config$google_sheets)) {
        stop("Missing curation_maps_url in google_sheets configuration")
    }
    if (!"merging_schema_url" %in% names(config$google_sheets)) {
        stop("Missing merging_schema_url in google_sheets configuration")
    }
    
    return(TRUE)
}

#' Get Configuration Path
#'
#' Retrieves a path from the configuration and ensures it's absolute.
#'
#' @param config Configuration list from load_config()
#' @param path_name Name of the path in the config (e.g., "project_dir")
#' @param create_if_missing Create directory if it doesn't exist
#' @return Absolute path as character string
#' @export
get_config_path <- function(config, path_name, create_if_missing = FALSE) {
    if (!path_name %in% names(config$paths)) {
        stop(sprintf("Path '%s' not found in configuration", path_name))
    }
    
    path <- config$paths[[path_name]]
    
    # Make absolute path if it's relative
    if (!startsWith(path, "/") && !startsWith(path, "~")) {
        project_dir <- config$paths$project_dir
        path <- file.path(project_dir, path)
    }
    
    path <- path.expand(path)
    
    if (create_if_missing && !dir.exists(path)) {
        dir.create(path, recursive = TRUE, showWarnings = FALSE)
    }
    
    return(path)
}

#' Get Full Path for Output File
#'
#' @param config Configuration list from load_config()
#' @param file_key Key name in output_files section
#' @return Full path to the output file
#' @export
get_output_path <- function(config, file_key) {
    if (!file_key %in% names(config$output_files)) {
        stop(sprintf("Output file key '%s' not found in configuration", file_key))
    }
    
    output_dir <- get_config_path(config, "output_dir")
    filename <- config$output_files[[file_key]]
    
    return(file.path(output_dir, filename))
}

#' Get Google Sheets URL
#'
#' @param config Configuration list from load_config()
#' @param sheet_key Key name in google_sheets section
#' @return URL as character string
#' @export
get_sheets_url <- function(config, sheet_key) {
    if (!sheet_key %in% names(config$google_sheets)) {
        stop(sprintf("Google Sheets key '%s' not found in configuration", sheet_key))
    }
    
    return(config$google_sheets[[sheet_key]])
}

#' Print Configuration Summary
#'
#' @param config Configuration list from load_config()
#' @export
print_config_summary <- function(config) {
    cat("=== ETL Configuration Summary ===\n\n")
    
    cat("Project Directory:", config$paths$project_dir, "\n")
    cat("ETL Directory:", get_config_path(config, "etl_dir"), "\n")
    cat("Output Directory:", get_config_path(config, "output_dir"), "\n\n")
    
    cat("ETL Steps:\n")
    for (step in config$etl_steps) {
        cat(sprintf("  %s: %s - %s\n", step$id, step$name, step$description))
    }
    
    cat("\nOutput Files:\n")
    for (name in names(config$output_files)) {
        cat(sprintf("  %s: %s\n", name, config$output_files[[name]]))
    }
}
