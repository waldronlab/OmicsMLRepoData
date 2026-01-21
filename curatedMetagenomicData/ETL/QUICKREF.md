# ETL Pipeline Quick Reference

## Running the Pipeline

### All Steps
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

### Specific Steps
```bash
# By step ID
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01,02,03"

# By step name
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "sync_curation_maps"
```

### Validation Only
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only
```

### Custom Config
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --config my_config.yaml
```

### Help
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --help
```

## Pipeline Steps

| ID | Script | Description |
|----|--------|-------------|
| 01 | `01_sync_curation_maps.R` | Sync curation maps from Google Sheets |
| 02 | `02_assemble_curated_metadata.R` | Assemble curated metadata from files |
| 03 | `03_build_merging_schema.R` | Build merging schema with statistics |
| 04 | `04_build_data_dictionary.R` | Build comprehensive data dictionary |
| 05 | `05_add_dynamic_enums.R` | Add dynamic enumeration nodes |
| 06 | `06_format_for_release.R` | Format for user-facing release |
| 07 | `07_validate_and_export.R` | Validate and export to targets |

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `cMD_curated_metadata_all.csv` | `inst/extdata/` | Complete curated metadata |
| `cMD_curated_metadata_release.csv` | `inst/extdata/` | User-facing release |
| `cMD_merging_schema.csv` | `inst/extdata/` | Column mapping schema |
| `cMD_data_dictionary.csv` | `inst/extdata/` | Data dictionary |
| `cMD4_data_dictionary.csv` | `inst/extdata/` | Expanded dictionary |

## Log Files

| File Pattern | Location | Description |
|-------------|----------|-------------|
| `etl_pipeline_*.log` | `curatedMetagenomicData/ETL/logs/` | Execution logs |
| `validation_report_*.txt` | `curatedMetagenomicData/ETL/logs/` | Validation reports |
| `execution_report_*.txt` | `curatedMetagenomicData/ETL/logs/` | Execution summaries |
| `provenance_*_*.json` | `curatedMetagenomicData/ETL/logs/` | Provenance metadata |

## Script Template

```r
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
init_logger(config, "script_name")

log_step_start("step_name", "description")

tryCatch({
    # Main logic here
    # Use: safe_read_csv(), safe_write_csv()
    # Use: get_config_path(), get_output_path()
    # Use: log_info(), log_warn(), log_error()
    
    # Add provenance
    data <- add_provenance(data, "step_name", config)
    
    # Save output
    safe_write_csv(data, output_file, backup = TRUE)
    
    # Write provenance log
    log_dir <- get_config_path(config, "log_dir", create_if_missing = TRUE)
    write_provenance_log(log_dir, "step_name", list(
        key_metrics = "values"
    ))
    
    log_step_complete("step_name")
    
}, error = function(e) {
    log_step_error("step_name", e$message)
    stop(e)
})
```

## Configuration Helpers

```r
# Load config
config <- load_config()
config <- load_config("custom_config.yaml")

# Get paths
path <- get_config_path(config, "data_dir")
path <- get_config_path(config, "log_dir", create_if_missing = TRUE)

# Get output file paths
file <- get_output_path(config, "curated_all")
file <- get_output_path(config, "data_dictionary")

# Get Google Sheets URLs
url <- get_sheets_url(config, "curation_maps_url")
url <- get_sheets_url(config, "merging_schema_url")
```

## Logging Helpers

```r
# Initialize logger
init_logger(config, "script_name")

# Log messages
log_info("Information message with %s", variable)
log_warn("Warning message")
log_error("Error message")
log_debug("Debug message (only shown at DEBUG level)")

# Log step lifecycle
log_step_start("step_name", "description")
log_step_complete("step_name", duration_seconds)
log_step_error("step_name", error_message)

# Log data summaries
log_data_summary(data, "data_name")
log_file_operation("read", file_path)
```

## Data Helpers

```r
# Safe file operations
data <- safe_read_csv(file_path)
success <- safe_write_csv(data, file_path, backup = TRUE)

# Column checks
check_required_columns(data, c("col1", "col2"), "data_name")

# Data loading
data_list <- load_csv_directory(dir_path, pattern = "\\.csv$")

# Joins
result <- safe_join(left, right, by = "id", type = "left")

# Sync to targets
success <- sync_file_to_targets(file_path, config$sync_targets, create_dirs = TRUE)
```

## Validation Helpers

```r
# Validate curated metadata
results <- validate_curated_metadata(data, config)

# Validate merging schema
results <- validate_merging_schema(schema, curated_data)

# Validate data dictionary
results <- validate_data_dictionary(dict, config, curated_data)

# Validate curation maps
results <- validate_curation_maps(maps_dir, config)

# Generate report
report <- generate_validation_report(validation_results, output_file)
```

## Provenance Helpers

```r
# Add provenance to data
data <- add_provenance(data, "step_name", config)

# Write provenance log
write_provenance_log(log_dir, "step_name", list(
    metric1 = value1,
    metric2 = value2
))

# Get provenance from data
prov <- get_provenance(data)

# Create execution report
create_execution_report(steps, durations, output_file)
```

## Troubleshooting

### Check logs
```bash
ls -lht curatedMetagenomicData/ETL/logs/ | head
tail -100 curatedMetagenomicData/ETL/logs/etl_pipeline_*.log
```

### Verify config
```r
source("curatedMetagenomicData/ETL/R/config_loader.R")
config <- load_config()
print_config_summary(config)
```

### Test individual script
```bash
Rscript curatedMetagenomicData/ETL/01_sync_curation_maps.R
```

### Run with debug logging
Edit `config.yaml`:
```yaml
logging:
  level: "DEBUG"
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Config file not found | Run from repo root or use `--config` |
| Package not installed | `install.packages(c("readr", "dplyr", "yaml"))` |
| Permission denied | Check file permissions in output directories |
| Google Sheets auth | Run `googledrive::drive_auth()` interactively first |
| Step fails | Check logs in `curatedMetagenomicData/ETL/logs/` |

## Dependencies

### Required
- R >= 4.0.0
- readr
- dplyr
- yaml
- googlesheets4
- googledrive

### Optional
- logger (better logging)
- jsonlite (JSON provenance logs)
- OmicsMLRepoCuration (statistics and dynamic enums)

### Install
```r
install.packages(c("readr", "dplyr", "yaml", "googlesheets4", 
                   "googledrive", "logger", "jsonlite"))

# Optional
remotes::install_github("waldronlab/OmicsMLRepoCuration")
```

## Resources

- **Full Documentation**: `README.md`
- **Migration Guide**: `MIGRATION.md`
- **Architecture**: `ARCHITECTURE.md`
- **Runbook**: `RUNBOOK.md`
- **Troubleshooting**: `TROUBLESHOOTING.md`
- **Tests**: `tests/testthat/test-etl.R`
- **Config**: `config.yaml`
