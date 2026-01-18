#' Provenance Tracking Functions for ETL Pipeline
#'
#' This module provides functions to track and record provenance metadata
#' for ETL outputs, including timestamps, versions, and execution context.

#' Add Provenance Metadata to Data Object
#'
#' Attaches provenance information to a data frame as attributes
#'
#' @param data Data frame to add provenance to
#' @param step_name Name of the ETL step that created/modified the data
#' @param config Optional configuration list for additional context
#' @return Data frame with provenance attributes
#' @export
add_provenance <- function(data, step_name, config = NULL) {
    # Timestamp
    attr(data, "etl_timestamp") <- Sys.time()
    
    # ETL step
    attr(data, "etl_step") <- step_name
    
    # Package version
    tryCatch({
        attr(data, "etl_version") <- as.character(packageVersion("OmicsMLRepoData"))
    }, error = function(e) {
        attr(data, "etl_version") <- "unknown"
    })
    
    # Git commit hash
    attr(data, "git_commit") <- get_git_commit()
    
    # User and system info
    attr(data, "user") <- Sys.info()["user"]
    attr(data, "system") <- paste(Sys.info()["sysname"], Sys.info()["release"])
    
    # R version
    attr(data, "r_version") <- paste(R.version$major, R.version$minor, sep = ".")
    
    # Data dimensions
    attr(data, "rows") <- nrow(data)
    attr(data, "columns") <- ncol(data)
    
    return(data)
}

#' Get Git Commit Hash
#'
#' Retrieves the current git commit hash
#'
#' @return Git commit hash as string, or "unknown" if not available
#' @export
get_git_commit <- function() {
    tryCatch({
        commit <- system2("git", args = c("rev-parse", "HEAD"), 
                          stdout = TRUE, stderr = FALSE)
        return(trimws(commit[1]))
    }, error = function(e) {
        return("unknown")
    }, warning = function(w) {
        return("unknown")
    })
}

#' Get Git Branch Name
#'
#' Retrieves the current git branch name
#'
#' @return Git branch name as string, or "unknown" if not available
#' @export
get_git_branch <- function() {
    tryCatch({
        branch <- system2("git", args = c("rev-parse", "--abbrev-ref", "HEAD"),
                          stdout = TRUE, stderr = FALSE)
        return(trimws(branch[1]))
    }, error = function(e) {
        return("unknown")
    }, warning = function(w) {
        return("unknown")
    })
}

#' Extract Provenance from Data Object
#'
#' Extracts provenance attributes from a data frame
#'
#' @param data Data frame with provenance attributes
#' @return List with provenance information
#' @export
get_provenance <- function(data) {
    prov <- list(
        timestamp = attr(data, "etl_timestamp"),
        step = attr(data, "etl_step"),
        version = attr(data, "etl_version"),
        git_commit = attr(data, "git_commit"),
        user = attr(data, "user"),
        system = attr(data, "system"),
        r_version = attr(data, "r_version"),
        rows = attr(data, "rows"),
        columns = attr(data, "columns")
    )
    
    return(prov)
}

#' Write Provenance Log
#'
#' Creates a JSON log file with execution provenance
#'
#' @param output_dir Directory to write the log
#' @param step_name Name of the ETL step
#' @param additional_info Optional list with additional information
#' @export
write_provenance_log <- function(output_dir, step_name, additional_info = NULL) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
        warning("Package 'jsonlite' not installed. Using basic provenance logging.")
        return(write_provenance_log_basic(output_dir, step_name, additional_info))
    }
    
    # Ensure directory exists
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Create provenance record
    provenance <- list(
        step_name = step_name,
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        git_commit = get_git_commit(),
        git_branch = get_git_branch(),
        user = Sys.info()["user"],
        system = paste(Sys.info()["sysname"], Sys.info()["release"]),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        working_directory = getwd()
    )
    
    # Add package version
    tryCatch({
        provenance$package_version <- as.character(packageVersion("OmicsMLRepoData"))
    }, error = function(e) {
        provenance$package_version <- "unknown"
    })
    
    # Add additional info if provided
    if (!is.null(additional_info)) {
        provenance$additional_info <- additional_info
    }
    
    # Write to JSON file
    log_file <- file.path(output_dir, sprintf("provenance_%s_%s.json",
                                               step_name,
                                               format(Sys.time(), "%Y%m%d_%H%M%S")))
    
    tryCatch({
        jsonlite::write_json(provenance, log_file, pretty = TRUE, auto_unbox = TRUE)
        log_info("Provenance log written to: %s", log_file)
    }, error = function(e) {
        log_error("Failed to write provenance log: %s", e$message)
    })
    
    return(invisible(log_file))
}

#' Write Basic Provenance Log
#'
#' Creates a basic text provenance log when jsonlite is not available
#'
#' @param output_dir Directory to write the log
#' @param step_name Name of the ETL step
#' @param additional_info Optional list with additional information
write_provenance_log_basic <- function(output_dir, step_name, additional_info = NULL) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    
    log_file <- file.path(output_dir, sprintf("provenance_%s_%s.txt",
                                               step_name,
                                               format(Sys.time(), "%Y%m%d_%H%M%S")))
    
    lines <- c(
        sprintf("ETL Step: %s", step_name),
        sprintf("Timestamp: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
        sprintf("Git Commit: %s", get_git_commit()),
        sprintf("Git Branch: %s", get_git_branch()),
        sprintf("User: %s", Sys.info()["user"]),
        sprintf("System: %s %s", Sys.info()["sysname"], Sys.info()["release"]),
        sprintf("R Version: %s.%s", R.version$major, R.version$minor),
        sprintf("Working Directory: %s", getwd())
    )
    
    if (!is.null(additional_info)) {
        lines <- c(lines, "", "Additional Information:")
        for (name in names(additional_info)) {
            lines <- c(lines, sprintf("  %s: %s", name, additional_info[[name]]))
        }
    }
    
    writeLines(lines, log_file)
    log_info("Provenance log written to: %s", log_file)
    
    return(invisible(log_file))
}

#' Create Execution Report
#'
#' Creates a detailed execution report for an ETL run
#'
#' @param steps_executed Vector of step names that were executed
#' @param step_durations Named vector of execution times (in seconds) per step
#' @param output_file File path to save the report
#' @param validation_results Optional validation results to include
#' @export
create_execution_report <- function(steps_executed, step_durations, 
                                     output_file, validation_results = NULL) {
    report <- c()
    report <- c(report, "=" %R% 70)
    report <- c(report, "ETL PIPELINE EXECUTION REPORT")
    report <- c(report, sprintf("Generated: %s", Sys.time()))
    report <- c(report, "=" %R% 70)
    report <- c(report, "")
    
    # Execution context
    report <- c(report, "## Execution Context")
    report <- c(report, "-" %R% 70)
    report <- c(report, sprintf("User: %s", Sys.info()["user"]))
    report <- c(report, sprintf("System: %s %s", Sys.info()["sysname"], Sys.info()["release"]))
    report <- c(report, sprintf("R Version: %s.%s", R.version$major, R.version$minor))
    report <- c(report, sprintf("Git Commit: %s", get_git_commit()))
    report <- c(report, sprintf("Git Branch: %s", get_git_branch()))
    report <- c(report, "")
    
    # Steps executed
    report <- c(report, "## Steps Executed")
    report <- c(report, "-" %R% 70)
    
    total_time <- sum(step_durations, na.rm = TRUE)
    
    for (step in steps_executed) {
        duration <- step_durations[step]
        if (is.na(duration)) {
            duration_str <- "N/A"
        } else {
            duration_str <- sprintf("%.2fs", duration)
        }
        report <- c(report, sprintf("  ✓ %s (%s)", step, duration_str))
    }
    
    report <- c(report, "")
    report <- c(report, sprintf("Total execution time: %.2f seconds (%.2f minutes)",
                                total_time, total_time / 60))
    report <- c(report, "")
    
    # Validation results if provided
    if (!is.null(validation_results)) {
        report <- c(report, "## Validation Results")
        report <- c(report, "-" %R% 70)
        
        for (section in names(validation_results)) {
            result <- validation_results[[section]]
            if (is.list(result$overall)) {
                status <- ifelse(result$overall$passed, "PASSED ✓", "FAILED ✗")
                report <- c(report, sprintf("  %s: %s", section, status))
            }
        }
        report <- c(report, "")
    }
    
    report <- c(report, "=" %R% 70)
    report <- c(report, "END OF REPORT")
    report <- c(report, "=" %R% 70)
    
    # Save to file
    dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(report, output_file)
    log_info("Execution report saved to: %s", output_file)
    
    return(report)
}

#' Repeat string operator
`%R%` <- function(str, n) {
    paste(rep(str, n), collapse = "")
}
