### Add Dynamic Enums
### This script adds dynamic enumeration nodes to the data dictionary
### Refactored version with configuration management and logging

# Load required libraries
suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
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
init_logger(config, "05_add_dynamic_enums")

log_step_start("05_add_dynamic_enums", 
               "Add dynamic enumeration nodes to data dictionary")

tryCatch({
    # Check if OmicsMLRepoCuration package is available
    if (!requireNamespace("OmicsMLRepoCuration", quietly = TRUE)) {
        log_error("OmicsMLRepoCuration package is required for this step")
        stop("OmicsMLRepoCuration package not installed. Please install it to run this step.")
    }
    
    library(OmicsMLRepoCuration)
    
    # Load data dictionary
    data_dict_file <- get_output_path(config, "data_dictionary")
    
    if (!file.exists(data_dict_file)) {
        stop(sprintf("Data dictionary file not found: %s. Run step 04 first.", data_dict_file))
    }
    
    log_info("Loading data dictionary from: %s", data_dict_file)
    enum_dd <- safe_read_csv(data_dict_file)
    
    log_data_summary(enum_dd, "Input data dictionary")
    
    # Define target attributes for dynamic enums
    target_attr <- c("biomarker", "body_site", "disease", "country",
                     "target_condition", "treatment")
    
    log_info("Adding dynamic enums for %d attributes", length(target_attr))
    
    # Apply dynamic enum nodes to each target attribute
    cmd_dd <- enum_dd
    
    for (attr in target_attr) {
        log_debug("Processing dynamic enum for: %s", attr)
        
        tryCatch({
            cmd_dd <- addDynamicEnumNodes(attr, cmd_dd)
            log_debug("  ✓ Added dynamic enum for: %s", attr)
        }, error = function(e) {
            log_warn("  ✗ Failed to add dynamic enum for %s: %s", attr, e$message)
        })
    }
    
    log_info("Dynamic enums added successfully")
    
    # Add provenance
    cmd_dd <- add_provenance(cmd_dd, "05_add_dynamic_enums", config)
    
    # Save updated data dictionary
    output_file <- get_output_path(config, "data_dictionary")
    log_info("Writing updated data dictionary to: %s", output_file)
    
    safe_write_csv(cmd_dd, output_file, backup = TRUE)
    
    log_data_summary(cmd_dd, "Updated data dictionary")
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "05_add_dynamic_enums", list(
        input_rows = nrow(enum_dd),
        output_rows = nrow(cmd_dd),
        target_attributes = paste(target_attr, collapse = ", "),
        output_file = output_file
    ))
    
    log_step_complete("05_add_dynamic_enums")
    
}, error = function(e) {
    log_step_error("05_add_dynamic_enums", e$message)
    stop(e)
})
