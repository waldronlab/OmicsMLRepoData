#' Logging Helper Functions for ETL Pipeline
#'
#' This module provides structured logging functions for the ETL pipeline.
#' It uses the logger package for consistent, formatted logging across all scripts.

#' Initialize Logger
#'
#' Sets up the logger with appropriate configuration from config
#'
#' @param config Configuration list from load_config()
#' @param script_name Name of the calling script for log identification
#' @export
init_logger <- function(config, script_name = NULL) {
    if (!requireNamespace("logger", quietly = TRUE)) {
        warning("Package 'logger' not installed. Using basic logging.")
        options(etl_use_basic_logging = TRUE)
        return(invisible(NULL))
    }
    
    options(etl_use_basic_logging = FALSE)
    
    # Set log level
    log_level <- toupper(config$logging$level %||% "INFO")
    logger::log_threshold(log_level)
    
    # Configure log format
    if (!is.null(script_name)) {
        logger::log_formatter(logger::formatter_sprintf)
        logger::log_layout(logger::layout_glue_generator(
            format = paste0('[{time}] [{level}] [', script_name, '] {msg}')
        ))
    }
    
    # Setup file logging if configured
    if (isTRUE(config$logging$file)) {
        log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
        log_file <- file.path(log_dir, sprintf("%s_%s.log", 
                                               script_name %||% "etl",
                                               format(Sys.time(), "%Y%m%d_%H%M%S")))
        
        logger::log_appender(logger::appender_tee(log_file))
    }
    
    return(invisible(NULL))
}

#' Log Info Message
#'
#' @param msg Message to log
#' @param ... Additional arguments passed to sprintf
#' @export
log_info <- function(msg, ...) {
    if (isTRUE(getOption("etl_use_basic_logging"))) {
        cat(sprintf("[INFO] %s\n", sprintf(msg, ...)))
    } else {
        logger::log_info(msg, ...)
    }
}

#' Log Warning Message
#'
#' @param msg Message to log
#' @param ... Additional arguments passed to sprintf
#' @export
log_warn <- function(msg, ...) {
    if (isTRUE(getOption("etl_use_basic_logging"))) {
        cat(sprintf("[WARN] %s\n", sprintf(msg, ...)))
    } else {
        logger::log_warn(msg, ...)
    }
}

#' Log Error Message
#'
#' @param msg Message to log
#' @param ... Additional arguments passed to sprintf
#' @export
log_error <- function(msg, ...) {
    if (isTRUE(getOption("etl_use_basic_logging"))) {
        cat(sprintf("[ERROR] %s\n", sprintf(msg, ...)))
    } else {
        logger::log_error(msg, ...)
    }
}

#' Log Debug Message
#'
#' @param msg Message to log
#' @param ... Additional arguments passed to sprintf
#' @export
log_debug <- function(msg, ...) {
    if (isTRUE(getOption("etl_use_basic_logging"))) {
        if (getOption("etl_debug", FALSE)) {
            cat(sprintf("[DEBUG] %s\n", sprintf(msg, ...)))
        }
    } else {
        logger::log_debug(msg, ...)
    }
}

#' Log Step Start
#'
#' @param step_name Name of the ETL step
#' @param step_description Description of what the step does
#' @export
log_step_start <- function(step_name, step_description = NULL) {
    msg <- sprintf("Starting step: %s", step_name)
    if (!is.null(step_description)) {
        msg <- sprintf("%s - %s", msg, step_description)
    }
    log_info(msg)
    log_info(paste(rep("=", 60), collapse = ""))
}

#' Log Step Complete
#'
#' @param step_name Name of the ETL step
#' @param duration Optional duration in seconds
#' @export
log_step_complete <- function(step_name, duration = NULL) {
    msg <- sprintf("Completed step: %s", step_name)
    if (!is.null(duration)) {
        msg <- sprintf("%s (%.2f seconds)", msg, duration)
    }
    log_info(msg)
    log_info(paste(rep("=", 60), collapse = ""))
}

#' Log Step Error
#'
#' @param step_name Name of the ETL step
#' @param error_msg Error message
#' @export
log_step_error <- function(step_name, error_msg) {
    log_error("Step '%s' failed: %s", step_name, error_msg)
}

#' Log Data Summary
#'
#' Logs a summary of a data frame (rows, columns, etc.)
#'
#' @param data Data frame to summarize
#' @param data_name Name/description of the data
#' @export
log_data_summary <- function(data, data_name) {
    log_info("%s: %d rows, %d columns", data_name, nrow(data), ncol(data))
}

#' Log File Operation
#'
#' @param operation Operation type (e.g., "read", "write")
#' @param file_path Path to file
#' @export
log_file_operation <- function(operation, file_path) {
    log_info("%s file: %s", tools::toTitleCase(operation), file_path)
}

#' NULL-coalescing operator
#'
#' @param a First value
#' @param b Default value if a is NULL
#' @return a if not NULL, otherwise b
`%||%` <- function(a, b) {
    if (is.null(a)) b else a
}
