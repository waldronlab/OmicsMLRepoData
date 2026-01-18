#' Validation Helper Functions for ETL Pipeline
#'
#' This module provides validation utility functions used by the main
#' validation.R module and across ETL scripts.

#' Check for Duplicate Values
#'
#' Identifies duplicate values in a column
#'
#' @param data Data frame
#' @param col_name Column name to check
#' @return List with check results
#' @export
check_duplicates <- function(data, col_name) {
    if (!col_name %in% colnames(data)) {
        return(list(
            passed = FALSE,
            error = "Column not found"
        ))
    }
    
    col <- data[[col_name]]
    col_no_na <- col[!is.na(col)]
    
    duplicates <- col_no_na[duplicated(col_no_na)]
    
    return(list(
        passed = length(duplicates) == 0,
        column = col_name,
        total_values = length(col_no_na),
        unique_values = length(unique(col_no_na)),
        duplicate_count = length(duplicates),
        duplicate_values = head(unique(duplicates), 10)
    ))
}

#' Check for Missing Values
#'
#' Checks for missing/NA values in specified columns
#'
#' @param data Data frame
#' @param col_names Vector of column names to check
#' @param allow_missing Whether missing values are allowed
#' @return List with check results
#' @export
check_missing_values <- function(data, col_names, allow_missing = FALSE) {
    results <- list()
    
    for (col_name in col_names) {
        if (!col_name %in% colnames(data)) {
            results[[col_name]] <- list(
                passed = FALSE,
                error = "Column not found"
            )
            next
        }
        
        col <- data[[col_name]]
        missing_count <- sum(is.na(col))
        
        results[[col_name]] <- list(
            passed = allow_missing || missing_count == 0,
            column = col_name,
            total_rows = length(col),
            missing_count = missing_count,
            missing_pct = (missing_count / length(col)) * 100
        )
    }
    
    return(results)
}

#' Check Column Data Types
#'
#' Verifies that columns have expected data types
#'
#' @param data Data frame
#' @param col_types Named list of column names and expected types
#' @return List with check results
#' @export
check_column_types <- function(data, col_types) {
    results <- list()
    
    for (col_name in names(col_types)) {
        if (!col_name %in% colnames(data)) {
            results[[col_name]] <- list(
                passed = FALSE,
                error = "Column not found"
            )
            next
        }
        
        expected_type <- col_types[[col_name]]
        actual_type <- class(data[[col_name]])[1]
        
        # Handle some common type equivalences
        type_match <- actual_type == expected_type ||
                      (expected_type == "numeric" && actual_type %in% c("integer", "double")) ||
                      (expected_type == "character" && actual_type == "factor")
        
        results[[col_name]] <- list(
            passed = type_match,
            column = col_name,
            expected_type = expected_type,
            actual_type = actual_type
        )
    }
    
    return(results)
}

#' Check Value Ranges
#'
#' Checks if numeric values fall within expected ranges
#'
#' @param data Data frame
#' @param col_name Column name
#' @param min_val Minimum allowed value (NULL for no minimum)
#' @param max_val Maximum allowed value (NULL for no maximum)
#' @return List with check results
#' @export
check_value_range <- function(data, col_name, min_val = NULL, max_val = NULL) {
    if (!col_name %in% colnames(data)) {
        return(list(
            passed = FALSE,
            error = "Column not found"
        ))
    }
    
    col <- data[[col_name]]
    col_numeric <- col[!is.na(col)]
    
    if (!is.numeric(col_numeric)) {
        return(list(
            passed = FALSE,
            error = "Column is not numeric"
        ))
    }
    
    out_of_range <- numeric(0)
    
    if (!is.null(min_val)) {
        out_of_range <- c(out_of_range, col_numeric[col_numeric < min_val])
    }
    
    if (!is.null(max_val)) {
        out_of_range <- c(out_of_range, col_numeric[col_numeric > max_val])
    }
    
    return(list(
        passed = length(out_of_range) == 0,
        column = col_name,
        min_val = min_val,
        max_val = max_val,
        out_of_range_count = length(out_of_range),
        out_of_range_values = head(unique(out_of_range), 10)
    ))
}

#' Check Allowed Values
#'
#' Verifies that column values are from an allowed set
#'
#' @param data Data frame
#' @param col_name Column name
#' @param allowed_values Vector of allowed values (or regex pattern if is_regex=TRUE)
#' @param is_regex Whether allowed_values is a regex pattern
#' @return List with check results
#' @export
check_allowed_values <- function(data, col_name, allowed_values, is_regex = FALSE) {
    if (!col_name %in% colnames(data)) {
        return(list(
            passed = FALSE,
            error = "Column not found"
        ))
    }
    
    col <- data[[col_name]]
    col_clean <- col[!is.na(col) & col != ""]
    
    if (is_regex) {
        # Check against regex pattern
        invalid <- col_clean[!grepl(allowed_values, col_clean)]
    } else {
        # Check against allowed values list
        invalid <- col_clean[!col_clean %in% allowed_values]
    }
    
    return(list(
        passed = length(invalid) == 0,
        column = col_name,
        total_values = length(col_clean),
        invalid_count = length(invalid),
        invalid_values = head(unique(invalid), 10)
    ))
}

#' Check Column Completeness
#'
#' Checks if a column meets a minimum completeness threshold
#'
#' @param data Data frame
#' @param col_name Column name
#' @param min_completeness Minimum completeness (0-1)
#' @return List with check results
#' @export
check_completeness <- function(data, col_name, min_completeness = 0.8) {
    if (!col_name %in% colnames(data)) {
        return(list(
            passed = FALSE,
            error = "Column not found"
        ))
    }
    
    col <- data[[col_name]]
    completeness <- 1 - (sum(is.na(col)) / length(col))
    
    return(list(
        passed = completeness >= min_completeness,
        column = col_name,
        completeness = completeness,
        completeness_pct = completeness * 100,
        min_required = min_completeness,
        missing_count = sum(is.na(col))
    ))
}

#' Validate Curation Map Structure
#'
#' Checks if a curation map has the required structure
#'
#' @param map_data Data frame containing curation map
#' @param map_name Name of the map for error messages
#' @return List with validation results
#' @export
validate_curation_map_structure <- function(map_data, map_name) {
    required_cols <- c("original_value", "curated_ontology_term",
                       "curated_ontology_term_id", "curated_ontology_term_db")
    
    issues <- list()
    
    # Check required columns
    missing_cols <- setdiff(required_cols, colnames(map_data))
    if (length(missing_cols) > 0) {
        issues$missing_columns <- missing_cols
    }
    
    # Check for empty values in key columns
    if ("original_value" %in% colnames(map_data)) {
        empty_originals <- sum(is.na(map_data$original_value) | 
                               map_data$original_value == "")
        if (empty_originals > 0) {
            issues$empty_original_values <- empty_originals
        }
    }
    
    # Check ontology ID format
    if ("curated_ontology_term_id" %in% colnames(map_data)) {
        term_ids <- map_data$curated_ontology_term_id[
            !is.na(map_data$curated_ontology_term_id) &
            map_data$curated_ontology_term_id != ""
        ]
        
        invalid_format <- sum(!grepl("^[A-Z]+:[A-Za-z0-9_]+$", term_ids))
        if (invalid_format > 0) {
            issues$invalid_ontology_format <- invalid_format
        }
    }
    
    return(list(
        passed = length(issues) == 0,
        map_name = map_name,
        issues = issues
    ))
}

#' Create Validation Summary
#'
#' Creates a summary report from validation results
#'
#' @param validation_results List of validation check results
#' @return Data frame with summary
#' @export
create_validation_summary <- function(validation_results) {
    summary_rows <- list()
    
    for (check_name in names(validation_results)) {
        result <- validation_results[[check_name]]
        
        summary_rows[[check_name]] <- data.frame(
            check = check_name,
            passed = result$passed %||% FALSE,
            details = paste(capture.output(str(result)), collapse = " "),
            stringsAsFactors = FALSE
        )
    }
    
    summary_df <- do.call(rbind, summary_rows)
    rownames(summary_df) <- NULL
    
    return(summary_df)
}

#' NULL-coalescing operator
`%||%` <- function(a, b) {
    if (is.null(a)) b else a
}
