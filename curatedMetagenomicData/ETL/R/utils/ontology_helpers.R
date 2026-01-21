#' Ontology Helper Functions for ETL Pipeline
#'
#' This module provides functions for working with ontology terms and IDs
#' used in the curation process.

#' Extract Ontology Database from Term ID
#'
#' Extracts the ontology database name from a term ID (e.g., "NCIT:C12345" -> "NCIT")
#'
#' @param term_id Ontology term ID
#' @return Ontology database name
#' @export
get_ontology_db <- function(term_id) {
    if (is.na(term_id) || term_id == "") {
        return(NA)
    }
    
    parts <- strsplit(term_id, ":")[[1]]
    if (length(parts) >= 2) {
        return(parts[1])
    }
    
    return(NA)
}

#' Extract Multiple Ontology Databases
#'
#' Extracts ontology databases from a pipe-delimited string of term IDs
#'
#' @param term_ids_string Pipe-delimited string of ontology term IDs
#' @return Character vector of unique ontology databases
#' @export
get_ontologies <- function(term_ids_string) {
    if (is.na(term_ids_string) || term_ids_string == "") {
        return(character(0))
    }
    
    term_ids <- strsplit(term_ids_string, "\\|")[[1]]
    dbs <- sapply(term_ids, get_ontology_db, USE.NAMES = FALSE)
    dbs <- unique(dbs[!is.na(dbs)])
    
    return(dbs)
}

#' Validate Ontology Term ID Format
#'
#' Checks if an ontology term ID follows expected format (DB:ID)
#'
#' @param term_id Ontology term ID to validate
#' @param allowed_dbs Optional vector of allowed database names
#' @return TRUE if valid, FALSE otherwise
#' @export
validate_ontology_id <- function(term_id, allowed_dbs = NULL) {
    if (is.na(term_id) || term_id == "") {
        return(FALSE)
    }
    
    # Check basic format: DB:ID
    if (!grepl("^[A-Z]+:[A-Za-z0-9_]+$", term_id)) {
        return(FALSE)
    }
    
    # Check against allowed databases if provided
    if (!is.null(allowed_dbs)) {
        db <- get_ontology_db(term_id)
        if (!db %in% allowed_dbs) {
            return(FALSE)
        }
    }
    
    return(TRUE)
}

#' Validate Multiple Ontology Term IDs
#'
#' Validates a pipe-delimited string of ontology term IDs
#'
#' @param term_ids_string Pipe-delimited string of ontology term IDs
#' @param allowed_dbs Optional vector of allowed database names
#' @return List with validation results
#' @export
validate_ontology_ids <- function(term_ids_string, allowed_dbs = NULL) {
    if (is.na(term_ids_string) || term_ids_string == "") {
        return(list(valid = TRUE, invalid_ids = character(0)))
    }
    
    term_ids <- strsplit(term_ids_string, "\\|")[[1]]
    invalid_ids <- character(0)
    
    for (term_id in term_ids) {
        if (!validate_ontology_id(term_id, allowed_dbs)) {
            invalid_ids <- c(invalid_ids, term_id)
        }
    }
    
    return(list(
        valid = length(invalid_ids) == 0,
        invalid_ids = invalid_ids
    ))
}

#' Format Ontology Term for Display
#'
#' Removes the ontology database prefix for user-facing display
#'
#' @param term_with_id Full ontology term with ID (e.g., "NCIT:C12345")
#' @return Term without database prefix
#' @export
format_ontology_term <- function(term_with_id) {
    if (is.na(term_with_id) || term_with_id == "") {
        return(NA)
    }
    
    # Remove database prefix if present
    term <- gsub("^[A-Z]+:", "", term_with_id)
    return(term)
}

#' Extract Ontology Summary
#'
#' Creates a summary of ontologies used in a column
#'
#' @param ontology_column Character vector of ontology term IDs
#' @return Named vector with counts per ontology database
#' @export
summarize_ontologies <- function(ontology_column) {
    all_dbs <- character(0)
    
    for (term_ids_string in ontology_column) {
        if (!is.na(term_ids_string) && term_ids_string != "") {
            dbs <- get_ontologies(term_ids_string)
            all_dbs <- c(all_dbs, dbs)
        }
    }
    
    summary <- table(all_dbs)
    return(sort(summary, decreasing = TRUE))
}

#' Common Ontology Databases
#'
#' Returns a vector of commonly used ontology databases in cMD
#'
#' @return Character vector of ontology database names
#' @export
get_common_ontologies <- function() {
    c("NCIT", "SNOMED", "EFO", "UBERON", "MONDO", "HP", "DOID", 
      "CHEBI", "FOODON", "GAZ", "NCBITAXON", "OBI")
}

#' Check Ontology Coverage
#'
#' Checks what percentage of values have ontology annotations
#'
#' @param data Data frame
#' @param ontology_id_col Name of column containing ontology IDs
#' @return List with coverage statistics
#' @export
check_ontology_coverage <- function(data, ontology_id_col) {
    if (!ontology_id_col %in% colnames(data)) {
        return(list(error = "Column not found"))
    }
    
    total <- nrow(data)
    with_ontology <- sum(!is.na(data[[ontology_id_col]]) & 
                         data[[ontology_id_col]] != "")
    
    return(list(
        total_rows = total,
        with_ontology = with_ontology,
        without_ontology = total - with_ontology,
        coverage_pct = (with_ontology / total) * 100
    ))
}

#' Split Ontology Terms
#'
#' Splits a pipe-delimited string of ontology terms into a vector
#'
#' @param term_string Pipe-delimited string
#' @return Character vector of individual terms
#' @export
split_ontology_terms <- function(term_string) {
    if (is.na(term_string) || term_string == "") {
        return(character(0))
    }
    
    terms <- strsplit(term_string, "\\|")[[1]]
    terms <- trimws(terms)
    terms <- terms[terms != ""]
    
    return(terms)
}

#' Join Ontology Terms
#'
#' Joins a vector of ontology terms into a pipe-delimited string
#'
#' @param terms Character vector of terms
#' @return Pipe-delimited string
#' @export
join_ontology_terms <- function(terms) {
    if (length(terms) == 0) {
        return(NA)
    }
    
    terms <- unique(terms[!is.na(terms) & terms != ""])
    
    if (length(terms) == 0) {
        return(NA)
    }
    
    return(paste(terms, collapse = "|"))
}

#' Clean Ontology Term ID
#'
#' Cleans and standardizes an ontology term ID
#'
#' @param term_id Ontology term ID
#' @return Cleaned term ID
#' @export
clean_ontology_id <- function(term_id) {
    if (is.na(term_id) || term_id == "") {
        return(NA)
    }
    
    # Remove whitespace
    term_id <- trimws(term_id)
    
    # Ensure uppercase database prefix
    parts <- strsplit(term_id, ":")[[1]]
    if (length(parts) == 2) {
        term_id <- paste0(toupper(parts[1]), ":", parts[2])
    }
    
    return(term_id)
}
