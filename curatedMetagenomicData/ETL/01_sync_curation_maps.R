### Sync Curation Maps from Google Sheets
### This script imports cMD curation maps from Google Sheets and saves them locally
### Refactored version with configuration management and logging

# Load required libraries
suppressPackageStartupMessages({
    library(googlesheets4)
    library(readr)
    library(dplyr)
})

# Source helper modules
script_dir <- dirname(sys.frame(1)$ofile)
if (is.null(script_dir) || script_dir == "") {
    script_dir <- "curatedMetagenomicData/ETL"
}

source(file.path(script_dir, "R/config_loader.R"))
source(file.path(script_dir, "R/utils/logging_helpers.R"))
source(file.path(script_dir, "R/utils/data_helpers.R"))
source(file.path(script_dir, "R/provenance.R"))

# Load configuration
config <- load_config()
init_logger(config, "01_sync_curation_maps")

log_step_start("01_sync_curation_maps", "Sync curation maps from Google Sheets")

# Get paths from config
maps_dir <- get_config_path(config, "maps_dir", create_if_missing = TRUE)
log_info("Maps directory: %s", maps_dir)

# Get Google Sheets URL from config
url <- get_sheets_url(config, "curation_maps_url")
log_info("Connecting to Google Sheets: %s", url)

tryCatch({
    # Connect to Google Sheets
    ss <- googledrive::as_id(url)
    all_sheets <- googlesheets4::sheet_names(ss)
    attributes <- all_sheets[grep("cMD_", all_sheets)]
    
    log_info("Found %d curation maps to sync", length(attributes))
    
    # Required columns for curation maps
    map_colnames <- config$required_columns$curation_maps
    
    # Download each map
    maps_synced <- 0
    maps_failed <- 0
    
    for (attribute in attributes) {
        tryCatch({
            log_debug("Syncing: %s", attribute)
            
            # Read from Google Sheets
            res <- googlesheets4::read_sheet(ss, sheet = attribute)
            
            # Validate required columns
            if (!all(map_colnames %in% colnames(res))) {
                missing_cols <- setdiff(map_colnames, colnames(res))
                log_warn("Skipping %s - missing columns: %s", 
                         attribute, paste(missing_cols, collapse = ", "))
                maps_failed <- maps_failed + 1
                next
            }
            
            # Save to file
            fname <- paste0(attribute, ".csv")
            fpath <- file.path(maps_dir, fname)
            
            safe_write_csv(res, fpath, backup = TRUE)
            
            maps_synced <- maps_synced + 1
            
        }, error = function(e) {
            log_error("Failed to sync %s: %s", attribute, e$message)
            maps_failed <- maps_failed + 1
        })
    }
    
    log_info("Successfully synced %d maps", maps_synced)
    if (maps_failed > 0) {
        log_warn("Failed to sync %d maps", maps_failed)
    }
    
    # Write provenance
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "01_sync_curation_maps", list(
        maps_synced = maps_synced,
        maps_failed = maps_failed,
        google_sheets_url = url
    ))
    
    log_step_complete("01_sync_curation_maps")
    
}, error = function(e) {
    log_step_error("01_sync_curation_maps", e$message)
    stop(e)
})
