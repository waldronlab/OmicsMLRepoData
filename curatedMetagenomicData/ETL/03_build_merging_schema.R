### Build Merging Schema
### This script imports the cMD merging schema from Google Sheets and assembles
### it into an export form, including completeness and unique values statistics
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
init_logger(config, "03_build_merging_schema")

log_step_start("03_build_merging_schema", 
               "Build merging schema from Google Sheets with statistics")

tryCatch({
    # Check if OmicsMLRepoCuration package is available
    if (!requireNamespace("OmicsMLRepoCuration", quietly = TRUE)) {
        log_warn("OmicsMLRepoCuration package not installed. Continuing without checkCurationStats.")
        use_curation_stats <- FALSE
    } else {
        library(OmicsMLRepoCuration)
        use_curation_stats <- TRUE
    }
    
    # Connect to Google Sheets
    url <- get_sheets_url(config, "merging_schema_url")
    log_info("Connecting to Google Sheets: %s", url)
    
    ss <- googledrive::as_id(url)
    
    # Get sheet names from config
    ms_sheet <- config$google_sheets_sheets$merging_schema_all
    dd_sheet <- config$google_sheets_sheets$data_dictionary_all
    
    log_info("Reading merging schema from sheet: %s", ms_sheet)
    map <- googlesheets4::read_sheet(ss, sheet = ms_sheet)
    
    log_info("Reading data dictionary from sheet: %s", dd_sheet)
    dd <- googlesheets4::read_sheet(ss, sheet = dd_sheet) %>%
        mutate(merge = as.character(merge))
    
    # Summarize consolidated columns as merging schema
    log_info("Processing merging schema mappings")
    
    new_cols <- dd[which(dd$merge == "TRUE"),]$curated_column
    map_to_ms <- map %>%
        dplyr::filter(curated_column %in% new_cols) %>%
        dplyr::group_by(curated_column) %>%
        dplyr::summarise(original_field = paste0(ori_column, collapse = ";")) %>%
        dplyr::rename(curated_field = curated_column)
    
    # Separately handle the 'age' exception
    age_ind <- which(map_to_ms$curated_field == "age;age_unit;age_group")
    if (length(age_ind) > 0) {
        map_to_ms$curated_field[age_ind] <- "age_years;age_group"
    }
    
    log_info("Created %d field mappings", nrow(map_to_ms))
    
    # Load original and curated metadata for statistics
    output_dir <- get_config_path(config, "output_dir")
    
    original_meta_file <- file.path(output_dir, "cMD_sampleMetadata.csv")
    curated_all_file <- get_output_path(config, "curated_all")
    
    # Calculate completeness and uniqueness if files exist
    if (file.exists(original_meta_file) && file.exists(curated_all_file) && use_curation_stats) {
        log_info("Loading metadata for statistics calculation")
        
        originalSampleMetadata <- safe_read_csv(original_meta_file)
        curated_all <- safe_read_csv(curated_all_file)
        
        # Completeness and uniqueness of original fields
        log_info("Calculating original field statistics")
        
        original_field_name <- sapply(map_to_ms$original_field, function(x) {
            strsplit(x, split = ";") %>% 
                unlist %>% 
                paste0(., collapse = ";")
        }) %>% as.vector()
        
        original_field_num <- sapply(original_field_name, 
                                     function(x) {
                                         strsplit(x, ";") %>% unlist %>% na.omit %>% length
                                     }) %>% stack %>%
            dplyr::rename(original_field_num = values,
                          original_field = ind)
        
        original_field_completeness <- checkCurationStats(
            fields_list = original_field_name,
            DB = originalSampleMetadata)
        
        original_field_unique_values <- checkCurationStats(
            fields_list = original_field_name,
            check = "unique",
            DB = originalSampleMetadata)
        
        # Completeness and uniqueness of curated fields
        log_info("Calculating curated field statistics")
        
        # Load release format for curated statistics
        curated_release_file <- get_output_path(config, "curated_release")
        if (file.exists(curated_release_file)) {
            cmd_meta_release <- safe_read_csv(curated_release_file)
        } else {
            # If release version doesn't exist yet, use curated_all
            log_warn("Release file not found, using curated_all for statistics")
            cmd_meta_release <- curated_all
        }
        
        curated_field_name <- map_to_ms$curated_field
        
        curated_field_completeness <- checkCurationStats(
            fields_list = curated_field_name,
            DB = cmd_meta_release)
        
        curated_field_unique_values <- checkCurationStats(
            fields_list = curated_field_name,
            check = "unique",
            DB = cmd_meta_release)
        
        # Add completeness and uniqueness to map_to_ms
        map_to_ms$original_field_completeness <- original_field_completeness
        map_to_ms$curated_field_completeness <- curated_field_completeness
        map_to_ms$original_field_unique_values <- original_field_unique_values
        map_to_ms$curated_field_unique_values <- curated_field_unique_values
        map_to_ms <- dplyr::full_join(map_to_ms, original_field_num, by = "original_field")
        
        # Reorder columns
        map_to_ms <- map_to_ms %>% 
            dplyr::relocate(original_field_num, .after = original_field) %>%
            dplyr::relocate(original_field_completeness, .after = original_field_num) %>%
            dplyr::relocate(curated_field_completeness, .after = curated_field) %>%
            dplyr::relocate(original_field_unique_values, .after = original_field_completeness) %>%
            dplyr::relocate(curated_field_unique_values, .after = curated_field_completeness)
        
        log_info("Added completeness and uniqueness statistics")
    } else {
        if (!use_curation_stats) {
            log_warn("Skipping statistics calculation (OmicsMLRepoCuration not available)")
        } else {
            log_warn("Metadata files not found, skipping statistics calculation")
        }
    }
    
    # Convert empty or NA (character) into NA
    map_to_ms[map_to_ms == ""] <- NA
    map_to_ms[map_to_ms == "NA"] <- NA
    
    # Sort by curated field
    cmd_ms <- arrange(map_to_ms, curated_field)
    
    # Add provenance
    cmd_ms <- add_provenance(cmd_ms, "03_build_merging_schema", config)
    
    # Save output
    output_file <- get_output_path(config, "merging_schema")
    log_info("Writing merging schema to: %s", output_file)
    
    safe_write_csv(cmd_ms, output_file, backup = TRUE)
    
    log_data_summary(cmd_ms, "Final merging schema")
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "03_build_merging_schema", list(
        total_mappings = nrow(cmd_ms),
        has_statistics = exists("original_field_completeness"),
        output_file = output_file
    ))
    
    log_step_complete("03_build_merging_schema")
    
}, error = function(e) {
    log_step_error("03_build_merging_schema", e$message)
    stop(e)
})
