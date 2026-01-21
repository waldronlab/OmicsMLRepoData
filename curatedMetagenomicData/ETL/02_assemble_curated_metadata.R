### Assemble Curated Metadata
### This script collects all curated cMD metadata files per attribute
### and combines them into a single `curated_all` table
### Refactored version with configuration management and logging

# Load required libraries
suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
    library(googlesheets4)
    library(googledrive)
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
source(file.path(script_dir, "R/provenance.R"))

# Load configuration
config <- load_config()
init_logger(config, "02_assemble_curated_metadata")

log_step_start("02_assemble_curated_metadata", 
               "Assemble curated metadata from individual files")

tryCatch({
    # Get paths from config
    data_dir <- get_config_path(config, "data_dir")
    output_dir <- get_config_path(config, "output_dir", create_if_missing = TRUE)
    
    log_info("Data directory: %s", data_dir)
    log_info("Output directory: %s", output_dir)
    
    # Import curated/harmonized attributes
    curated_files <- list.files(data_dir, pattern = "\\.csv$", full.names = FALSE)
    
    if (length(curated_files) == 0) {
        stop("No CSV files found in data directory")
    }
    
    log_info("Found %d curated attribute files", length(curated_files))
    
    # Load all curated data files
    curated_data_list <- list()
    for (file in curated_files) {
        file_path <- file.path(data_dir, file)
        name <- tools::file_path_sans_ext(file)
        
        log_debug("Loading: %s", file)
        curated_data_list[[name]] <- safe_read_csv(file_path)
    }
    
    # Connect to Google Sheets for merging schema and data dictionary
    url <- get_sheets_url(config, "merging_schema_url")
    log_info("Connecting to Google Sheets: %s", url)
    
    ss <- googledrive::as_id(url)
    
    # Get sheet names from config
    dd_sheet <- config$google_sheets_sheets$data_dictionary_all
    ms_sheet <- config$google_sheets_sheets$merging_schema_all
    
    log_info("Reading data dictionary from sheet: %s", dd_sheet)
    dd <- googlesheets4::read_sheet(ss, sheet = dd_sheet) %>%
        mutate(merge = as.character(merge))
    
    log_info("Reading merging schema from sheet: %s", ms_sheet)
    ms <- googlesheets4::read_sheet(ss, sheet = ms_sheet)
    
    # Load original sample metadata
    original_meta_file <- file.path(output_dir, "cMD_sampleMetadata.csv")
    
    if (!file.exists(original_meta_file)) {
        log_warn("Original metadata file not found: %s", original_meta_file)
        log_warn("Creating curated_all without original metadata merge")
        sampleMetadata <- NULL
    } else {
        log_info("Loading original sample metadata")
        sampleMetadata <- safe_read_csv(original_meta_file) %>%
            mutate(curation_id = paste(study_name, sample_id, sep = ":"))
    }
    
    # Determine columns to keep from original metadata
    kept_cols <- NULL
    kept_categories <- NULL
    
    if (!is.null(sampleMetadata)) {
        # Individual columns to be kept: `keep_origin == TRUE` in dd
        cols_to_keep <- dd %>%
            filter(keep_origin == TRUE) %>%
            pull(curated_column)
        
        if (length(cols_to_keep) > 0) {
            cols_to_keep_names <- ms %>%
                filter(curated_column %in% cols_to_keep) %>%
                pull(ori_column)
            
            # Only keep columns that exist in sampleMetadata
            cols_to_keep_names <- cols_to_keep_names[cols_to_keep_names %in% colnames(sampleMetadata)]
            cols_to_keep <- cols_to_keep[1:length(cols_to_keep_names)]
            
            if (length(cols_to_keep_names) > 0) {
                kept_cols <- sampleMetadata %>% 
                    select(all_of(c("curation_id", cols_to_keep_names)))
                colnames(kept_cols) <- c("curation_id", cols_to_keep)
                
                log_info("Keeping %d original columns", length(cols_to_keep))
            }
        }
        
        # Categories to be kept: `merge == FALSE` in dd
        categories_to_keep <- dd %>% 
            filter(merge == FALSE) %>% 
            pull(curated_column)
        
        if (length(categories_to_keep) > 0) {
            categories_to_keep_names <- ms %>%
                filter(curated_column %in% categories_to_keep) %>%
                pull(ori_column)
            
            # Only keep columns that exist in sampleMetadata
            categories_to_keep_names <- categories_to_keep_names[categories_to_keep_names %in% colnames(sampleMetadata)]
            
            if (length(categories_to_keep_names) > 0) {
                kept_categories <- sampleMetadata %>% 
                    select(all_of(c("curation_id", categories_to_keep_names)))
                
                log_info("Keeping %d category columns", length(categories_to_keep_names))
            }
        }
    }
    
    # Combine all curated sample metadata
    if (length(curated_data_list) == 0) {
        stop("No curated data loaded")
    }
    
    log_info("Combining %d curated data tables", length(curated_data_list))
    
    curated_all <- curated_data_list[[1]]
    
    if (length(curated_data_list) > 1) {
        for (i in 2:length(curated_data_list)) {
            dat <- curated_data_list[[i]]
            curated_all <- safe_join(curated_all, dat, by = "curation_id", type = "left")
        }
    }
    
    log_data_summary(curated_all, "Combined curated metadata")
    
    # Combine original metadata to be kept
    if (!is.null(kept_cols)) {
        log_info("Merging kept original columns")
        curated_all <- safe_join(curated_all, kept_cols, by = "curation_id", type = "left")
    }
    
    if (!is.null(kept_categories)) {
        log_info("Merging kept category columns")
        curated_all <- safe_join(curated_all, kept_categories, by = "curation_id", type = "left")
    }
    
    # Update format if format script exists
    format_script <- file.path(script_dir, "format_update/0_1_curated_metadata.R")
    if (file.exists(format_script)) {
        log_info("Applying format updates")
        source(format_script)
    }
    
    # Add provenance
    curated_all <- add_provenance(curated_all, "02_assemble_curated_metadata", config)
    
    # Save output
    output_file <- get_output_path(config, "curated_all")
    log_info("Writing curated metadata to: %s", output_file)
    
    safe_write_csv(curated_all, output_file, backup = TRUE)
    
    log_data_summary(curated_all, "Final curated_all")
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "02_assemble_curated_metadata", list(
        curated_files_loaded = length(curated_files),
        total_rows = nrow(curated_all),
        total_columns = ncol(curated_all),
        output_file = output_file
    ))
    
    log_step_complete("02_assemble_curated_metadata")
    
}, error = function(e) {
    log_step_error("02_assemble_curated_metadata", e$message)
    stop(e)
})
