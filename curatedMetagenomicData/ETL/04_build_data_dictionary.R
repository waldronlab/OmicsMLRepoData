### Build Data Dictionary
### This script consolidates data dictionary assembly, population, and expansion
### Combines functionality from scripts 3, 4, and 5
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
init_logger(config, "04_build_data_dictionary")

log_step_start("04_build_data_dictionary", 
               "Build comprehensive data dictionary (assemble, populate, expand)")

tryCatch({
    # Check for required package
    if (!requireNamespace("OmicsMLRepoCuration", quietly = TRUE)) {
        log_warn("OmicsMLRepoCuration package not installed. Some functionality may be limited.")
        use_curation_package <- FALSE
    } else {
        library(OmicsMLRepoCuration)
        use_curation_package <- TRUE
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
    dd <- googlesheets4::read_sheet(ss, sheet = dd_sheet)
    dd$merge <- as.character(dd$merge)
    
    # ==== STEP 1: Assemble Data Dictionary Template ====
    log_info("Step 1: Assembling data dictionary template")
    
    # Load original cMD data dictionary template
    template_source <- file.path(dirname(script_dir), "source/template.csv")
    
    if (!file.exists(template_source)) {
        log_warn("Template source not found at: %s", template_source)
        log_info("Creating minimal template structure")
        
        # Create minimal template structure
        ori_dd <- data.frame(
            col.name = character(),
            uniqueness = character(),
            requiredness = character(),
            multiplevalues = logical(),
            stringsAsFactors = FALSE
        )
    } else {
        log_info("Loading original data dictionary template")
        ori_dd <- safe_read_csv(template_source)
    }
    
    # Data dictionary for non-merging columns
    cols_to_keep <- dd[which(dd$merge %in% c("FALSE")),]$curated_column
    
    if (nrow(ori_dd) > 0 && "col.name" %in% colnames(ori_dd)) {
        cols_to_keep_names <- map$ori_column[map$curated_column %in% cols_to_keep]
        kept_dd <- dplyr::filter(ori_dd, col.name %in% cols_to_keep_names)
    } else {
        kept_dd <- data.frame()
    }
    
    # Data dictionary for to-be-merged columns
    cols_to_merge <- dd[which(dd$merge %in% c("TRUE", "Uncurated")),]$curated_column %>% 
        strsplit(., ";") %>% 
        unlist()
    
    # Create template for merged columns
    if (nrow(ori_dd) > 0) {
        merged_cols_dd <- as.data.frame(matrix(nrow = length(cols_to_merge), ncol = ncol(ori_dd)))
        colnames(merged_cols_dd) <- colnames(ori_dd)
    } else {
        # Minimal structure
        merged_cols_dd <- data.frame(
            col.name = cols_to_merge,
            uniqueness = NA,
            requiredness = NA,
            multiplevalues = NA,
            stringsAsFactors = FALSE
        )
    }
    
    merged_cols_dd$col.name <- cols_to_merge
    
    # Combine data dictionary drafts
    template_dd <- dplyr::bind_rows(merged_cols_dd, kept_dd)
    
    # Add required columns if missing
    if (!"description" %in% colnames(template_dd)) {
        template_dd$description <- NA
    }
    if (!"ontology" %in% colnames(template_dd)) {
        template_dd$ontology <- NA
    }
    
    # Relocate columns
    if ("multiplevalues" %in% colnames(template_dd)) {
        template_dd <- template_dd %>%
            dplyr::relocate(description, .after = multiplevalues)
    }
    
    log_info("Template created with %d columns", nrow(template_dd))
    
    # ==== STEP 2: Populate Data Dictionary ====
    log_info("Step 2: Populating data dictionary attributes")
    
    filled_dd <- template_dd
    
    # Get paths for template scripts
    maps_dir <- get_config_path(config, "maps_dir")
    
    # Source template population scripts if they exist
    template_scripts <- c(
        "template_age.R",
        "template_bodysite.R", 
        "template_condition.R",
        "template_minor.R",
        "template_others.R",
        "template_sub_cols.R",
        "template_treatment.R",
        "template_ppd.R"
    )
    
    populated_count <- 0
    for (template_script in template_scripts) {
        template_path <- file.path(script_dir, "R", template_script)
        
        if (file.exists(template_path)) {
            log_debug("Sourcing template: %s", template_script)
            tryCatch({
                # Set required variables for template scripts
                mapDir <- maps_dir
                scriptDir <- file.path(script_dir, "R")
                
                source(template_path)
                populated_count <- populated_count + 1
            }, error = function(e) {
                log_warn("Failed to source %s: %s", template_script, e$message)
            })
        }
    }
    
    log_info("Populated using %d template scripts", populated_count)
    
    # Order col.name column
    required_cols <- c("study_name", "subject_id", "sample_id", 
                      "target_condition", "control", "country", 
                      "body_site")
    
    required_ind <- c()
    for (col in required_cols) {
        ind <- which(filled_dd$col.name == col)
        if (length(ind) > 0) {
            required_ind <- c(required_ind, ind)
        }
    }
    
    if (length(required_ind) > 0) {
        filled_dd <- filled_dd[-required_ind,] %>%
            dplyr::arrange(., col.name) %>%
            dplyr::bind_rows(filled_dd[required_ind, ], .)
    } else {
        filled_dd <- dplyr::arrange(filled_dd, col.name)
    }
    
    # Add summary of ontologies used (ontoDB column)
    if ("ontology" %in% colnames(filled_dd) && use_curation_package) {
        log_info("Adding ontology database summary")
        
        ontologies <- lapply(filled_dd$ontology, 
                            function(x) {
                                if (is.na(x) || x == "") {
                                    return(NA)
                                }
                                x %>% strsplit(., "\\|") %>% 
                                    unlist %>% 
                                    get_ontologies(.) %>% 
                                    table %>% 
                                    sort(decreasing = TRUE) %>% 
                                    names %>% 
                                    paste(., collapse = "|")
                            }) %>% unlist()
        
        ontologies[ontologies == ""] <- NA
        filled_dd$ontoDB <- ontologies
    }
    
    # Apply format updates if script exists
    format_script <- file.path(script_dir, "format_update/4_1_dictionary.R")
    if (file.exists(format_script)) {
        log_info("Applying format updates from 4_1_dictionary.R")
        tryCatch({
            source(format_script)
        }, error = function(e) {
            log_warn("Format update script failed: %s", e$message)
        })
    }
    
    # ==== STEP 3: Expand Data Dictionary (if needed) ====
    log_info("Step 3: Expanding data dictionary for new attributes")
    
    expanded_dd <- filled_dd
    
    # Source expansion template if it exists
    expansion_script <- file.path(script_dir, "R", "template_new_attrs.R")
    if (file.exists(expansion_script)) {
        log_info("Applying attribute expansion")
        tryCatch({
            mapDir <- maps_dir
            scriptDir <- file.path(script_dir, "R")
            
            source(expansion_script)
            
            # Re-order after expansion
            required_ind <- c()
            for (col in required_cols) {
                ind <- which(expanded_dd$col.name == col)
                if (length(ind) > 0) {
                    required_ind <- c(required_ind, ind)
                }
            }
            
            if (length(required_ind) > 0) {
                expanded_dd <- expanded_dd[-required_ind,] %>%
                    dplyr::arrange(., col.name) %>%
                    dplyr::bind_rows(expanded_dd[required_ind, ], .)
            }
            
        }, error = function(e) {
            log_warn("Expansion script failed: %s", e$message)
        })
    }
    
    # ==== Save Outputs ====
    
    # Save main data dictionary
    output_file <- get_output_path(config, "data_dictionary")
    log_info("Writing data dictionary to: %s", output_file)
    
    cmd_dd <- filled_dd
    cmd_dd <- add_provenance(cmd_dd, "04_build_data_dictionary", config)
    safe_write_csv(cmd_dd, output_file, backup = TRUE)
    
    log_data_summary(cmd_dd, "Final data dictionary")
    
    # Save expanded version if different
    if (!identical(filled_dd, expanded_dd)) {
        expanded_file <- get_output_path(config, "expanded_dictionary")
        log_info("Writing expanded data dictionary to: %s", expanded_file)
        
        expanded_dd <- add_provenance(expanded_dd, "04_build_data_dictionary", config)
        safe_write_csv(expanded_dd, expanded_file, backup = TRUE)
        
        log_data_summary(expanded_dd, "Expanded data dictionary")
    }
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "04_build_data_dictionary", list(
        template_columns = nrow(template_dd),
        populated_scripts = populated_count,
        final_columns = nrow(cmd_dd),
        output_file = output_file
    ))
    
    log_step_complete("04_build_data_dictionary")
    
}, error = function(e) {
    log_step_error("04_build_data_dictionary", e$message)
    stop(e)
})
