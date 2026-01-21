# ETL Pipeline Migration Guide

## Overview

This guide helps users transition from the legacy ETL scripts (0-6, 99) to the new refactored pipeline (01-07).

## Quick Reference: Script Name Mapping

| Legacy Script | New Script | Notes |
|--------------|------------|-------|
| `1_sync_curation_map.R` | `01_sync_curation_maps.R` | Already refactored |
| `0_assemble_curated_metadata.R` | `02_assemble_curated_metadata.R` | New |
| `2_assemble_merging_schema.R` | `03_build_merging_schema.R` | New |
| `3_assemble_data_dictionary_template.R` + `4_populate_data_dictionary.R` + `5_expand_data_dictionary.R` | `04_build_data_dictionary.R` | Consolidated |
| `99_dynamic_enum.R` | `05_add_dynamic_enums.R` | New |
| `6_format_for_release.R` | `06_format_for_release.R` | New |
| N/A | `07_validate_and_export.R` | New functionality |

## What's Changed

### 1. Configuration Management

**Before:**
```r
# Hardcoded paths
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
dataDir <- file.path(dir, "curatedMetagenomicData/data")
```

**After:**
```r
# Centralized configuration
config <- load_config()
data_dir <- get_config_path(config, "data_dir")
```

**Migration:** Update `config.yaml` instead of editing script paths.

### 2. Logging

**Before:**
```r
# Ad-hoc messages
print("Loading data...")
cat("Processing...\n")
```

**After:**
```r
# Structured logging
init_logger(config, "script_name")
log_info("Loading data...")
log_step_start("step_name", "description")
log_step_complete("step_name")
```

**Migration:** Remove print/cat statements; logging is automatic.

### 3. File Operations

**Before:**
```r
# Direct read/write
data <- read_csv(file_path)
write_csv(data, output_path)
```

**After:**
```r
# Safe operations with logging and backups
data <- safe_read_csv(file_path)
safe_write_csv(data, output_path, backup = TRUE)
```

**Migration:** Replace direct file operations with safe_ versions.

### 4. Error Handling

**Before:**
```r
# No consistent error handling
result <- do_something()
```

**After:**
```r
# Comprehensive error handling
tryCatch({
    result <- do_something()
    log_step_complete("step_name")
}, error = function(e) {
    log_step_error("step_name", e$message)
    stop(e)
})
```

**Migration:** Automatic error logging and reporting.

### 5. Provenance Tracking

**Before:**
```r
# No provenance tracking
```

**After:**
```r
# Automatic provenance metadata
data <- add_provenance(data, "step_name", config)
write_provenance_log(log_dir, "step_name", additional_info)
```

**Migration:** Provenance is tracked automatically.

## Running the New Pipeline

### Option 1: Run All Steps
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

This replaces running individual legacy scripts in sequence.

### Option 2: Run Specific Steps
```bash
# Run only steps 1-3
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01,02,03"

# Or by name
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "sync_curation_maps,assemble_curated_metadata"
```

### Option 3: Run Individual Scripts
```bash
# Still works for debugging
Rscript curatedMetagenomicData/ETL/02_assemble_curated_metadata.R
```

## Key Benefits of the New Pipeline

### 1. **Consistency**
All scripts follow the same pattern, making them easier to understand and maintain.

### 2. **Robustness**
- Comprehensive error handling
- Automatic backups before overwriting files
- Validation at each step

### 3. **Observability**
- Structured logging to console and files
- Execution time tracking
- Validation reports
- Provenance metadata

### 4. **Flexibility**
- Run all steps or individual steps
- Validation-only mode
- Custom configuration files
- Easy to extend

### 5. **Safety**
- No hardcoded paths
- Backup files created automatically
- Comprehensive validation before finalizing

## Common Migration Scenarios

### Scenario 1: I was running all scripts in sequence

**Before:**
```bash
Rscript 1_sync_curation_map.R
Rscript 0_assemble_curated_metadata.R
Rscript 2_assemble_merging_schema.R
# ... etc
```

**After:**
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

### Scenario 2: I only run specific steps

**Before:**
```bash
Rscript 2_assemble_merging_schema.R
Rscript 3_assemble_data_dictionary_template.R
```

**After:**
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "03,04"
```

### Scenario 3: I need to customize paths

**Before:**
```r
# Edit script directly
dir <- "~/my/custom/path"
```

**After:**
```yaml
# Edit config.yaml
paths:
  project_dir: "~/my/custom/path"
```

Or use a custom config:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --config my_config.yaml
```

### Scenario 4: I want to validate before running

**Before:**
```r
# No built-in validation
```

**After:**
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only
```

## Configuration Migration

### Update config.yaml

The new pipeline uses a centralized configuration file. Update these sections:

```yaml
# Paths - Update to match your environment
paths:
  project_dir: "~/OmicsMLRepo/OmicsMLRepoData"
  etl_dir: "curatedMetagenomicData/ETL"
  maps_dir: "curatedMetagenomicData/maps"
  data_dir: "curatedMetagenomicData/data"
  output_dir: "inst/extdata"
  script_dir: "curatedMetagenomicData/ETL/R"
  log_dir: "curatedMetagenomicData/ETL/logs"

# Sync targets - Add your target repositories
sync_targets:
  - name: "OmicsMLRepoCuration"
    path: "~/OmicsMLRepo/OmicsMLRepoCuration/inst/extdata"
  - name: "OmicsMLRepoR"
    path: "~/OmicsMLRepo/OmicsMLRepoR/inst/extdata"
```

## Breaking Changes

### 1. Variable Names
Some internal variable names have changed for consistency:
- `curated_all` is now loaded from config paths
- `cmd_ms`, `cmd_dd`, `cmd_meta_release` follow the same pattern

### 2. Outputs
Output files remain the same, but:
- Automatic backups are created (`.backup_TIMESTAMP`)
- Provenance metadata is embedded as attributes
- JSON provenance logs are created in `logs/`

### 3. Dependencies
New dependencies:
- `yaml` (required)
- `logger` (optional, improves logging)
- `jsonlite` (optional, improves provenance logs)

## Troubleshooting

### Issue: "Config file not found"
**Solution:** Ensure you're running from the correct directory or use `--config` to specify the path.

### Issue: "Step script not found"
**Solution:** Verify all numbered scripts (01-07) exist in `curatedMetagenomicData/ETL/`.

### Issue: "Package not installed"
**Solution:** Install required packages:
```r
install.packages(c("readr", "dplyr", "yaml", "googlesheets4", "googledrive"))
```

### Issue: "Old scripts still in directory"
**Solution:** Legacy scripts are kept for reference but should not be used. The orchestrator only runs 01-07.

## Validation

After migration, validate your setup:

```bash
# 1. Check configuration loads
Rscript -e 'source("curatedMetagenomicData/ETL/R/config_loader.R"); config <- load_config(); print_config_summary(config)'

# 2. Run validation only
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only

# 3. Run a single step to test
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01"

# 4. Run full pipeline
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

## Getting Help

1. Check logs in `curatedMetagenomicData/ETL/logs/`
2. Review validation reports
3. Check `TROUBLESHOOTING.md`
4. See examples in `README.md`
5. Open an issue on GitHub

## Timeline

- **Current (PR #115+):** New pipeline fully implemented
- **Transition period:** Legacy scripts remain for reference
- **Future:** Legacy scripts may be moved to `legacy/` directory

## Feedback

If you encounter issues during migration:
1. Document the issue
2. Check if it's a configuration problem
3. Open an issue with details about your use case
4. Suggest improvements to this migration guide

## Summary

The new refactored pipeline provides:
- ✅ Better error handling and logging
- ✅ Centralized configuration
- ✅ Comprehensive validation
- ✅ Provenance tracking
- ✅ Easier maintenance and extension
- ✅ Consistent patterns across all scripts

**Recommended action:** Start using the new pipeline via the orchestrator for all new workflows.
