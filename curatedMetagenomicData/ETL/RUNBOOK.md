# ETL Pipeline Runbook

## Table of Contents

1. [Pre-Flight Checks](#pre-flight-checks)
2. [Running the Pipeline](#running-the-pipeline)
3. [Step-by-Step Execution](#step-by-step-execution)
4. [Manual Execution](#manual-execution)
5. [Validation Procedures](#validation-procedures)
6. [Recovery Procedures](#recovery-procedures)
7. [Maintenance Tasks](#maintenance-tasks)

## Pre-Flight Checks

### Before Running the Pipeline

1. **Verify R Environment**
```bash
R --version  # Should be >= 4.0.0
```

2. **Check Required Packages**
```r
required_packages <- c("readr", "dplyr", "yaml", "googlesheets4", 
                       "googledrive", "logger", "jsonlite")
missing <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
    cat("Missing packages:", paste(missing, collapse = ", "), "\n")
}
```

3. **Verify Configuration**
```bash
# Check config file exists
ls -l curatedMetagenomicData/ETL/config.yaml

# Verify YAML syntax
Rscript -e 'yaml::read_yaml("curatedMetagenomicData/ETL/config.yaml")'
```

4. **Check Google Sheets Access**
```r
library(googlesheets4)
# Test authentication
gs4_auth()
# Try reading a test sheet
gs4_get("YOUR_SHEET_ID")
```

5. **Verify Directory Structure**
```bash
# Check that required directories exist
ls -ld curatedMetagenomicData/ETL
ls -ld curatedMetagenomicData/maps
ls -ld curatedMetagenomicData/data
ls -ld inst/extdata
```

## Running the Pipeline

### Full Pipeline Execution

**Basic Run (All Steps)**:
```bash
cd /path/to/OmicsMLRepoData
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

**With Logging**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R 2>&1 | tee etl_run.log
```

**Dry Run (Validation Only)**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only
```

### Partial Execution

**Run Specific Steps**:
```bash
# Run steps 1-3 only
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01,02,03"

# Run by step name
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "sync_curation_maps"
```

**Custom Configuration**:
```bash
# Use a different config file
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --config custom_config.yaml
```

### Monitoring Execution

**Watch Logs in Real-Time**:
```bash
# In another terminal
tail -f curatedMetagenomicData/ETL/logs/etl_pipeline_*.log
```

**Check Progress**:
```bash
# List log files
ls -lht curatedMetagenomicData/ETL/logs/

# View latest execution report
cat curatedMetagenomicData/ETL/logs/execution_report_*.txt | tail -50
```

## Step-by-Step Execution

### Step 01: Sync Curation Maps

**Purpose**: Download curation maps from Google Sheets

**Prerequisites**:
- Google Sheets authentication configured
- Network connectivity

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01"
```

**Verification**:
```bash
# Check that maps were downloaded
ls -l curatedMetagenomicData/maps/cMD_*_map.csv

# Count map files
ls curatedMetagenomicData/maps/cMD_*_map.csv | wc -l
```

**Expected Output**:
- Multiple `cMD_*_map.csv` files in maps directory
- Log entry: "Successfully synced N maps"

### Step 02: Assemble Curated Metadata

**Purpose**: Combine curated data files into single table

**Prerequisites**:
- Curated data files exist in `curatedMetagenomicData/data/`

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "02"
```

**Verification**:
```bash
# Check output file exists
ls -lh inst/extdata/cMD_curated_metadata_all.csv

# Check row and column counts
Rscript -e 'data <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv", show_col_types=F); cat(nrow(data), "rows,", ncol(data), "columns\n")'
```

**Expected Output**:
- `inst/extdata/cMD_curated_metadata_all.csv` created
- Typically ~20,000+ rows, ~150 columns

### Step 03: Build Merging Schema

**Purpose**: Create schema mapping original to curated columns

**Prerequisites**:
- Google Sheets access to merging schema

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "03"
```

**Verification**:
```bash
# Check output
ls -lh inst/extdata/cMD_merging_schema.csv

# View sample
head -10 inst/extdata/cMD_merging_schema.csv
```

**Expected Output**:
- `inst/extdata/cMD_merging_schema.csv` created
- Contains ori_column and curated_column mappings

### Step 04: Build Data Dictionary

**Purpose**: Build comprehensive data dictionary

**Prerequisites**:
- Curation maps in place
- Dictionary builder templates available

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "04"
```

**Verification**:
```bash
# Check output
ls -lh inst/extdata/cMD_data_dictionary.csv

# Check completeness
Rscript -e 'dd <- readr::read_csv("inst/extdata/cMD_data_dictionary.csv", show_col_types=F); cat("Dictionary has", nrow(dd), "entries\n")'
```

**Expected Output**:
- `inst/extdata/cMD_data_dictionary.csv` created
- One entry per curated column

### Step 05: Add Dynamic Enums

**Purpose**: Add dynamic enumeration nodes for ontology terms

**Prerequisites**:
- Data dictionary exists
- Curated metadata available

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "05"
```

**Verification**:
```bash
# Check that dictionary was updated
Rscript -e 'dd <- readr::read_csv("inst/extdata/cMD_data_dictionary.csv", show_col_types=F); cat("Columns with dynamic enums:", sum(!is.na(dd$DynamicEnum)), "\n")'
```

**Expected Output**:
- Updated data dictionary with DynamicEnum column populated

### Step 06: Format for Release

**Purpose**: Format metadata for user-facing release

**Prerequisites**:
- Curated metadata all file exists

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "06"
```

**Verification**:
```bash
# Check output
ls -lh inst/extdata/cMD_curated_metadata_release.csv

# Verify no internal columns
Rscript -e 'data <- readr::read_csv("inst/extdata/cMD_curated_metadata_release.csv", show_col_types=F); cat("Release columns:", paste(head(colnames(data), 10), collapse=", "), "\n")'
```

**Expected Output**:
- `inst/extdata/cMD_curated_metadata_release.csv` created
- No columns starting with "original_" or ending with "_source"

### Step 07: Validate and Export

**Purpose**: Final validation and export to all targets

**Prerequisites**:
- All previous steps completed
- Sync targets configured and accessible

**Execution**:
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "07"
```

**Verification**:
```bash
# Check validation report
cat curatedMetagenomicData/ETL/logs/validation_report_*.txt | grep "FINAL STATUS"

# Verify synced files
ls -l ~/OmicsMLRepo/OmicsMLRepoCuration/inst/extdata/cMD_*.csv
ls -l ~/OmicsMLRepo/OmicsMLRepoR/inst/extdata/cMD_*.csv
```

**Expected Output**:
- Validation report with PASSED status
- Files synced to all configured targets

## Manual Execution

### Running Individual Scripts

You can run scripts directly without the orchestrator:

```r
# Set up environment
library(readr)
library(dplyr)
library(googlesheets4)

# Source helpers
source("curatedMetagenomicData/ETL/R/config_loader.R")
source("curatedMetagenomicData/ETL/R/utils/logging_helpers.R")

# Run script
source("curatedMetagenomicData/ETL/01_sync_curation_maps.R")
```

### Interactive Debugging

```r
# Start R session
R

# Load required libraries
library(readr)
library(dplyr)

# Source the script but don't execute
# This loads functions without running them
source("curatedMetagenomicData/ETL/01_sync_curation_maps.R", 
       local = new.env())

# Now you can step through code interactively
```

## Validation Procedures

### Pre-Execution Validation

```bash
# Validate configuration
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only
```

### Post-Execution Validation

```bash
# Run validation checks
Rscript -e '
source("curatedMetagenomicData/ETL/R/validation.R")
source("curatedMetagenomicData/ETL/R/config_loader.R")

config <- load_config()

# Validate curated metadata
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")
results <- validate_curated_metadata(curated, config)

if (results$overall$passed) {
  cat("✓ Validation PASSED\n")
} else {
  cat("✗ Validation FAILED\n")
  print(results)
}
'
```

### Manual Validation Checks

```r
# Check for duplicates
library(dplyr)
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")
duplicates <- curated %>% 
    group_by(sample_id) %>% 
    filter(n() > 1)
cat("Duplicate sample_ids:", nrow(duplicates), "\n")

# Check ontology IDs
ontology_cols <- grep("_ontology_term_id$", colnames(curated), value = TRUE)
for (col in ontology_cols) {
    invalid <- sum(!grepl("^[A-Z]+:[A-Za-z0-9_]+$", 
                          curated[[col]][!is.na(curated[[col]])]))
    cat(col, "- Invalid IDs:", invalid, "\n")
}

# Check completeness
required_cols <- c("study_name", "subject_id", "sample_id", "body_site", "country")
for (col in required_cols) {
    missing <- sum(is.na(curated[[col]]))
    cat(col, "- Missing values:", missing, "\n")
}
```

## Recovery Procedures

### Step Failed - Resume from Last Good Step

```bash
# If step 04 failed, resume from step 04
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "04,05,06,07"
```

### Restore from Backup

```bash
# List backups
ls -lht inst/extdata/*.backup_*

# Restore from backup
cp inst/extdata/cMD_curated_metadata_all.csv.backup_TIMESTAMP \
   inst/extdata/cMD_curated_metadata_all.csv
```

### Re-sync from Google Sheets

```bash
# Force re-download of all maps
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "01"

# Re-sync schema
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "03"
```

### Clean Start

```bash
# Backup current state
mkdir -p backups
cp -r inst/extdata backups/extdata_$(date +%Y%m%d_%H%M%S)

# Clear outputs (be careful!)
rm inst/extdata/cMD_*.csv

# Run full pipeline
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R
```

## Maintenance Tasks

### Weekly Tasks

1. **Check Execution Logs**
```bash
# Review recent logs
ls -lt curatedMetagenomicData/ETL/logs/ | head -10
grep ERROR curatedMetagenomicData/ETL/logs/etl_pipeline_*.log
```

2. **Run Validation**
```bash
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --validate-only
```

3. **Clean Old Logs**
```bash
# Remove logs older than 30 days
find curatedMetagenomicData/ETL/logs/ -name "*.log" -mtime +30 -delete
find curatedMetagenomicData/ETL/logs/ -name "*.txt" -mtime +30 -delete
```

### Monthly Tasks

1. **Update Curation Maps**
   - Review Google Sheets for new ontology mappings
   - Run sync to pull latest: `--steps "01"`

2. **Review Data Quality**
   - Check validation reports
   - Identify columns with low completeness
   - Review ontology coverage

3. **Update Documentation**
   - Add new attributes to dictionary
   - Update README with any process changes
   - Document new edge cases

### Quarterly Tasks

1. **Performance Review**
   - Analyze execution times
   - Identify bottlenecks
   - Optimize slow steps

2. **Dependency Updates**
```r
# Check for package updates
update.packages(ask = FALSE)
```

3. **Archive Old Versions**
```bash
# Archive old outputs
tar -czf archive_$(date +%Y%m%d).tar.gz inst/extdata/*.csv
```

## Emergency Procedures

### Pipeline Won't Start

1. Check R version: `R --version`
2. Verify packages: `Rscript -e 'library(yaml); library(readr); library(dplyr)'`
3. Check config syntax: `Rscript -e 'yaml::read_yaml("curatedMetagenomicData/ETL/config.yaml")'`
4. Review error message in logs

### Authentication Failures

1. Re-authenticate with Google:
```r
library(googlesheets4)
gs4_deauth()
gs4_auth()
```

2. Check token file exists: `ls -la ~/.google_token.json`
3. Verify Google Sheets URLs in config are accessible

### Out of Memory

1. Close other R sessions
2. Increase R memory limit:
```r
options(java.parameters = "-Xmx8g")  # 8GB
```
3. Process data in chunks if possible
4. Consider running on a machine with more RAM

### Disk Space Issues

```bash
# Check disk space
df -h

# Clean temporary files
rm -rf /tmp/R*

# Remove old backups
find inst/extdata -name "*.backup_*" -mtime +7 -delete
```

## Best Practices

1. **Always run validation** before considering pipeline complete
2. **Review logs** for warnings even if pipeline succeeds
3. **Test configuration changes** with `--validate-only` first
4. **Keep backups** of working outputs before major changes
5. **Document custom procedures** in comments or local README
6. **Monitor execution time** trends to catch performance issues early
7. **Version control everything** - commit config and script changes

## Getting Help

- Check `TROUBLESHOOTING.md` for common issues
- Review `ARCHITECTURE.md` for system design
- Examine logs in `curatedMetagenomicData/ETL/logs/`
- Open GitHub issue with:
  - Steps to reproduce
  - Error messages
  - Relevant log excerpts
  - System information
