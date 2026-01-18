#' Data Helper Functions for ETL Pipeline
#'
#' This module provides common data manipulation and handling functions
#' used across the ETL pipeline scripts.

#' Safe Read CSV
#'
#' Reads a CSV file with error handling and logging
#'
#' @param file_path Path to CSV file
#' @param ... Additional arguments passed to readr::read_csv
#' @return Data frame or NULL on error
#' @export
safe_read_csv <- function(file_path, ...) {
    if (!file.exists(file_path)) {
        log_error("File not found: %s", file_path)
        return(NULL)
    }
    
    tryCatch({
        data <- readr::read_csv(file_path, show_col_types = FALSE, ...)
        log_data_summary(data, basename(file_path))
        return(data)
    }, error = function(e) {
        log_error("Failed to read %s: %s", file_path, e$message)
        return(NULL)
    })
}

#' Safe Write CSV
#'
#' Writes a CSV file with error handling, logging, and backup
#'
#' @param data Data frame to write
#' @param file_path Path to output CSV file
#' @param backup Create backup of existing file
#' @param ... Additional arguments passed to readr::write_csv
#' @return TRUE on success, FALSE on error
#' @export
safe_write_csv <- function(data, file_path, backup = TRUE, ...) {
    # Create backup if file exists
    if (backup && file.exists(file_path)) {
        backup_path <- sprintf("%s.backup_%s", 
                               file_path,
                               format(Sys.time(), "%Y%m%d_%H%M%S"))
        file.copy(file_path, backup_path)
        log_info("Created backup: %s", basename(backup_path))
    }
    
    tryCatch({
        # Ensure directory exists
        dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)
        
        readr::write_csv(data, file_path, ...)
        log_file_operation("write", file_path)
        log_data_summary(data, basename(file_path))
        return(TRUE)
    }, error = function(e) {
        log_error("Failed to write %s: %s", file_path, e$message)
        return(FALSE)
    })
}

#' Check Required Columns
#'
#' Verifies that a data frame contains all required columns
#'
#' @param data Data frame to check
#' @param required_cols Vector of required column names
#' @param data_name Name/description of the data for error messages
#' @return TRUE if all columns present, stops with error otherwise
#' @export
check_required_columns <- function(data, required_cols, data_name = "data") {
    missing_cols <- setdiff(required_cols, colnames(data))
    
    if (length(missing_cols) > 0) {
        msg <- sprintf("%s is missing required columns: %s", 
                       data_name,
                       paste(missing_cols, collapse = ", "))
        log_error(msg)
        stop(msg)
    }
    
    log_debug("All required columns present in %s", data_name)
    return(TRUE)
}

#' Get Column Summary
#'
#' Generate summary statistics for a data frame column
#'
#' @param data Data frame
#' @param col_name Column name
#' @return List with summary statistics
#' @export
get_column_summary <- function(data, col_name) {
    if (!col_name %in% colnames(data)) {
        return(list(error = "Column not found"))
    }
    
    col <- data[[col_name]]
    
    summary <- list(
        name = col_name,
        type = class(col)[1],
        total = length(col),
        missing = sum(is.na(col)),
        unique = length(unique(col[!is.na(col)])),
        completeness = 1 - (sum(is.na(col)) / length(col))
    )
    
    return(summary)
}

#' Join Data Frames Safely
#'
#' Performs a join operation with logging and validation
#'
#' @param left Left data frame
#' @param right Right data frame
#' @param by Column(s) to join by
#' @param type Join type ("left", "right", "inner", "full")
#' @return Joined data frame
#' @export
safe_join <- function(left, right, by, type = "left") {
    log_debug("Joining data: %d rows (left) + %d rows (right) by '%s'",
              nrow(left), nrow(right), paste(by, collapse = ", "))
    
    result <- switch(type,
                     "left" = dplyr::left_join(left, right, by = by),
                     "right" = dplyr::right_join(left, right, by = by),
                     "inner" = dplyr::inner_join(left, right, by = by),
                     "full" = dplyr::full_join(left, right, by = by),
                     stop(sprintf("Unknown join type: %s", type)))
    
    log_debug("Join result: %d rows", nrow(result))
    
    return(result)
}

#' Load Multiple CSV Files
#'
#' Loads all CSV files from a directory
#'
#' @param dir_path Directory containing CSV files
#' @param pattern Optional pattern to filter files
#' @return Named list of data frames
#' @export
load_csv_directory <- function(dir_path, pattern = "\\.csv$") {
    if (!dir.exists(dir_path)) {
        log_error("Directory not found: %s", dir_path)
        return(list())
    }
    
    files <- list.files(dir_path, pattern = pattern, full.names = TRUE)
    
    if (length(files) == 0) {
        log_warn("No CSV files found in: %s", dir_path)
        return(list())
    }
    
    log_info("Loading %d CSV files from: %s", length(files), dir_path)
    
    data_list <- list()
    for (file in files) {
        name <- tools::file_path_sans_ext(basename(file))
        data_list[[name]] <- safe_read_csv(file)
    }
    
    return(data_list)
}

#' Sync File to Multiple Targets
#'
#' Copies a file to multiple target locations
#'
#' @param source_path Source file path
#' @param targets List of target configurations from config
#' @param create_dirs Create target directories if missing
#' @return TRUE if all syncs successful, FALSE otherwise
#' @export
sync_file_to_targets <- function(source_path, targets, create_dirs = TRUE) {
    if (!file.exists(source_path)) {
        log_error("Source file not found: %s", source_path)
        return(FALSE)
    }
    
    success <- TRUE
    filename <- basename(source_path)
    
    for (target in targets) {
        target_path <- path.expand(target$path)
        
        if (!dir.exists(target_path)) {
            if (create_dirs) {
                dir.create(target_path, recursive = TRUE, showWarnings = FALSE)
                log_info("Created target directory: %s", target_path)
            } else {
                log_warn("Target directory not found (skipping): %s (%s)", 
                         target$name, target_path)
                success <- FALSE
                next
            }
        }
        
        dest_file <- file.path(target_path, filename)
        
        tryCatch({
            file.copy(source_path, dest_file, overwrite = TRUE)
            log_info("Synced to %s: %s", target$name, dest_file)
        }, error = function(e) {
            log_error("Failed to sync to %s: %s", target$name, e$message)
            success <- FALSE
        })
    }
    
    return(success)
}

#' Remove Columns by Pattern
#'
#' Removes columns matching a pattern from a data frame
#'
#' @param data Data frame
#' @param pattern Regular expression pattern
#' @return Data frame with matching columns removed
#' @export
remove_columns_by_pattern <- function(data, pattern) {
    matching_cols <- grep(pattern, colnames(data), value = TRUE)
    
    if (length(matching_cols) > 0) {
        log_debug("Removing %d columns matching '%s': %s",
                  length(matching_cols), pattern,
                  paste(head(matching_cols, 3), collapse = ", "))
        data <- data[, !colnames(data) %in% matching_cols, drop = FALSE]
    }
    
    return(data)
}
