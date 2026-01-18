# ETL Pipeline Troubleshooting Guide

## Common Issues and Solutions

### Table of Contents

1. [Pipeline Won't Start](#pipeline-wont-start)
2. [Google Sheets Issues](#google-sheets-issues)
3. [Configuration Problems](#configuration-problems)
4. [Data Validation Failures](#data-validation-failures)
5. [File System Issues](#file-system-issues)
6. [Performance Problems](#performance-problems)
7. [Package and Dependency Issues](#package-and-dependency-issues)
8. [GitHub Actions Failures](#github-actions-failures)

---

## Pipeline Won't Start

### Error: "Command not found: Rscript"

**Symptoms**:
```
bash: Rscript: command not found
```

**Cause**: R is not installed or not in PATH

**Solution**:
```bash
# Check if R is installed
which R

# If not installed, install R
# On Ubuntu/Debian:
sudo apt-get update
sudo apt-get install r-base

# On macOS with Homebrew:
brew install r

# Verify installation
R --version
Rscript --version
```

### Error: "Configuration file not found"

**Symptoms**:
```
Error: Configuration file not found: curatedMetagenomicData/ETL/config.yaml
```

**Cause**: Running from wrong directory or config file missing

**Solution**:
```bash
# Check current directory
pwd

# Should be in repository root
# If not, cd to correct location
cd /path/to/OmicsMLRepoData

# Verify config exists
ls -l curatedMetagenomicData/ETL/config.yaml

# If missing, restore from backup or repository
git checkout curatedMetagenomicData/ETL/config.yaml
```

### Error: "Package 'xyz' is required but not installed"

**Symptoms**:
```
Error: Package 'yaml' is required but not installed.
```

**Cause**: Required R package not installed

**Solution**:
```r
# Install missing package
install.packages("yaml")

# Install all required packages at once
required <- c("readr", "dplyr", "yaml", "googlesheets4", 
              "googledrive", "logger", "jsonlite", "testthat")
install.packages(required)

# Verify installation
sapply(required, require, character.only = TRUE)
```

---

## Google Sheets Issues

### Error: "Can't get Google credentials"

**Symptoms**:
```
Error: Can't get Google credentials.
Are you running googledrive in a non-interactive session?
```

**Cause**: Google authentication not configured

**Solution**:
```r
# Interactive authentication
library(googlesheets4)
library(googledrive)

# Authenticate (opens browser)
gs4_auth()
drive_auth()

# For non-interactive (CI/CD)
# Set up service account or token file
gs4_auth(path = "~/.google_token.json")
```

**For GitHub Actions**:
1. Generate service account token
2. Add as secret: `GOOGLE_SHEETS_TOKEN`
3. Pipeline will use it automatically

### Error: "Sheet not found"

**Symptoms**:
```
Error: Sheet 'xyz' not found in spreadsheet
```

**Cause**: Sheet name changed or deleted in Google Sheets

**Solution**:
1. Open Google Sheets URL from config
2. Check available sheet names
3. Update sheet names in config if changed
4. Or restore deleted sheets

```r
# List available sheets
library(googlesheets4)
url <- "YOUR_GOOGLE_SHEETS_URL"
ss <- googledrive::as_id(url)
googlesheets4::sheet_names(ss)
```

### Error: "Invalid Google Sheets URL"

**Symptoms**:
```
Error: Invalid spreadsheet identifier
```

**Cause**: Malformed URL in config.yaml

**Solution**:
```yaml
# Check URL format in config.yaml
# Should look like:
google_sheets:
  curation_maps_url: "https://docs.google.com/spreadsheets/d/SHEET_ID/edit?usp=sharing"

# Not:
# - Missing https://
# - Truncated ID
# - Extra parameters
```

### Error: "Rate limit exceeded"

**Symptoms**:
```
Error: Rate Limit Exceeded
```

**Cause**: Too many API requests to Google Sheets

**Solution**:
```r
# Add delays between requests
Sys.sleep(2)  # Wait 2 seconds between sheet reads

# Or reduce frequency of syncs
# Run step 01 less frequently

# Check API quota:
# https://console.cloud.google.com/apis/api/sheets.googleapis.com/quotas
```

---

## Configuration Problems

### Error: "Missing required configuration section"

**Symptoms**:
```
Error: Missing required configuration section: paths
```

**Cause**: config.yaml is incomplete or corrupted

**Solution**:
```bash
# Validate YAML syntax
Rscript -e 'yaml::read_yaml("curatedMetagenomicData/ETL/config.yaml")'

# Check required sections exist
grep -E "^(paths|google_sheets|output_files):" curatedMetagenomicData/ETL/config.yaml

# Restore from backup if corrupted
git checkout curatedMetagenomicData/ETL/config.yaml
```

### Error: "Path not found"

**Symptoms**:
```
Error: Maps directory not found: ~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/maps
```

**Cause**: Configured path doesn't exist or is incorrect

**Solution**:
```bash
# Check if path exists (after tilde expansion)
ls -ld ~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/maps

# Create missing directory
mkdir -p ~/OmicsMLRepo/OmicsMLRepoData/curatedMetagenomicData/maps

# Or update config.yaml with correct path
# Use absolute paths if tilde expansion fails
```

### Error: "Invalid YAML syntax"

**Symptoms**:
```
Error: Scanner error
```

**Cause**: YAML syntax error in config.yaml

**Solution**:
```bash
# Check YAML syntax online: https://www.yamllint.com/
# Or use command line
yamllint curatedMetagenomicData/ETL/config.yaml

# Common issues:
# - Missing colon after key
# - Incorrect indentation (use spaces, not tabs)
# - Unquoted strings with special characters
# - Mismatched brackets

# Example fix:
# Wrong:
paths
  project_dir: "~/path"

# Right:
paths:
  project_dir: "~/path"
```

---

## Data Validation Failures

### Error: "All required columns should be present"

**Symptoms**:
```
✗ required_columns
  Error: data is missing required columns: body_site, country
```

**Cause**: Data file missing expected columns

**Solution**:
```r
# Check what columns are present
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")
cat("Available columns:", paste(colnames(curated), collapse = ", "), "\n")

# Re-run assembly step to regenerate
Rscript curatedMetagenomicData/ETL/run_etl_pipeline.R --steps "02"

# Or check source data files
list.files("curatedMetagenomicData/data", pattern = "\\.csv$")
```

### Error: "Duplicate sample_ids found"

**Symptoms**:
```
✗ duplicate_samples
  Found 5 duplicate sample IDs
```

**Cause**: Same sample_id appears multiple times

**Solution**:
```r
# Identify duplicates
library(dplyr)
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")

duplicates <- curated %>%
    group_by(sample_id) %>%
    filter(n() > 1) %>%
    arrange(sample_id)

print(duplicates)

# Check source data for duplicates
# Fix at source and re-run step 02
```

### Error: "Ontology IDs invalid format"

**Symptoms**:
```
✗ ontology_formats
  10 invalid ontology IDs found
```

**Cause**: Ontology term IDs don't match expected format (DB:ID)

**Solution**:
```r
# Find invalid IDs
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")
ontology_cols <- grep("_ontology_term_id$", colnames(curated), value = TRUE)

for (col in ontology_cols) {
    ids <- curated[[col]][!is.na(curated[[col]])]
    invalid <- ids[!grepl("^[A-Z]+:[A-Za-z0-9_]+$", ids)]
    if (length(invalid) > 0) {
        cat("\nInvalid IDs in", col, ":\n")
        print(head(invalid, 10))
    }
}

# Fix in curation maps (Google Sheets)
# Ensure format is: DATABASE:ID (e.g., NCIT:C12345)
# Re-sync maps: --steps "01"
```

### Error: "Data dictionary coverage incomplete"

**Symptoms**:
```
✗ column_coverage
  Missing columns: biomarker, hla, ancestry_detailed
```

**Cause**: Data dictionary missing entries for some columns

**Solution**:
1. Add missing attributes to dictionary builders
2. Update `04_build_data_dictionary.R`
3. Re-run: `--steps "04"`

```r
# Check what's documented
dd <- readr::read_csv("inst/extdata/cMD_data_dictionary.csv")
curated <- readr::read_csv("inst/extdata/cMD_curated_metadata_all.csv")

documented <- dd$ColName
actual <- colnames(curated)

missing <- setdiff(actual, documented)
cat("Missing from dictionary:\n")
print(missing)
```

---

## File System Issues

### Error: "Permission denied"

**Symptoms**:
```
Error: Permission denied: /path/to/file.csv
```

**Cause**: No write permission for output directory

**Solution**:
```bash
# Check permissions
ls -ld inst/extdata

# Fix permissions
chmod 755 inst/extdata
chmod 644 inst/extdata/*.csv

# Or run with sudo (not recommended)
# Better: fix ownership
sudo chown -R $USER:$USER inst/extdata
```

### Error: "Disk quota exceeded"

**Symptoms**:
```
Error: cannot write to connection
Disk quota exceeded
```

**Cause**: Out of disk space

**Solution**:
```bash
# Check disk usage
df -h

# Clean up
# Remove old backups
find inst/extdata -name "*.backup_*" -mtime +7 -delete

# Remove old logs
find curatedMetagenomicData/ETL/logs -name "*.log" -mtime +30 -delete

# Clean R temp files
rm -rf /tmp/R*

# Check sizes
du -sh inst/extdata
du -sh curatedMetagenomicData/ETL/logs
```

### Error: "File not found"

**Symptoms**:
```
Error: File not found: curatedMetagenomicData/data/curated_bodysite.csv
```

**Cause**: Required input file missing

**Solution**:
```bash
# Check if file exists
ls -l curatedMetagenomicData/data/

# List all curated data files
ls curatedMetagenomicData/data/curated_*.csv

# If missing, check:
# 1. Was it renamed?
# 2. Is it in a different location?
# 3. Needs to be generated by previous step?

# Restore from git if deleted
git checkout curatedMetagenomicData/data/
```

---

## Performance Problems

### Issue: Pipeline runs very slowly

**Symptoms**: Pipeline takes hours instead of minutes

**Possible Causes and Solutions**:

1. **Network latency**
```r
# Test Google Sheets connection speed
start <- Sys.time()
gs4_get("YOUR_SHEET_ID")
end <- Sys.time()
cat("Fetch time:", difftime(end, start, units="secs"), "seconds\n")

# Solution: Run during off-peak hours or use caching
```

2. **Large data files**
```r
# Check file sizes
files <- list.files("curatedMetagenomicData/data", pattern="\\.csv$", full.names=TRUE)
sizes <- file.info(files)$size / 1024^2  # MB
names(sizes) <- basename(files)
print(sort(sizes, decreasing=TRUE))

# Solution: Process in chunks or optimize queries
```

3. **Memory issues**
```r
# Check memory usage
cat("Memory used:", pryr::mem_used() / 1024^3, "GB\n")

# Solution: Close other applications or use machine with more RAM
```

### Issue: Step hangs indefinitely

**Symptoms**: Script appears frozen, no output

**Solution**:
```bash
# Check if R process is actually running
ps aux | grep R

# Check if waiting for input
# Look for "Selection:" or similar prompts

# Force quit if truly hung
pkill -9 Rscript

# Re-run with verbose logging
Rscript --verbose curatedMetagenomicData/ETL/run_etl_pipeline.R
```

---

## Package and Dependency Issues

### Error: "there is no package called 'xyz'"

**Symptoms**:
```
Error in library(xyz) : there is no package called 'xyz'
```

**Solution**:
```r
# Install missing package
install.packages("xyz")

# If package is from GitHub
remotes::install_github("author/package")

# Check package version
packageVersion("xyz")
```

### Error: "package 'xyz' is not available"

**Symptoms**:
```
Warning: package 'xyz' is not available for R version X.Y.Z
```

**Solution**:
```r
# Update R to newer version
# Or install from source/archive

# Check CRAN availability
available.packages()["xyz",]

# Install from archive
install.packages("https://cran.r-project.org/src/contrib/Archive/xyz/xyz_1.0.0.tar.gz", 
                 repos=NULL, type="source")
```

### Error: "namespace 'xyz' is already loaded"

**Symptoms**:
```
Error: namespace 'xyz' X.Y is already loaded, but >= X.Z is required
```

**Solution**:
```r
# Restart R session
.rs.restartR()  # In RStudio

# Or from command line
# Exit R and restart

# Update package
remove.packages("xyz")
install.packages("xyz")
```

---

## GitHub Actions Failures

### Error: "GOOGLE_SHEETS_TOKEN not set"

**Symptoms**: GitHub Action shows authentication warning

**Solution**:
1. Generate service account key or OAuth token
2. Go to repository Settings → Secrets and variables → Actions
3. Add secret named `GOOGLE_SHEETS_TOKEN`
4. Paste token JSON content
5. Re-run workflow

### Error: "permission denied" in GitHub Actions

**Symptoms**: Can't push results back to repository

**Solution**:
```yaml
# Ensure workflow has write permissions
# Add to .github/workflows/etl-pipeline.yml

permissions:
  contents: write  # Allow push

# Or use personal access token
- name: Commit and Push
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    git push
```

### Error: "Resource not accessible by integration"

**Symptoms**: GitHub Actions can't access resources

**Solution**:
1. Check repository settings → Actions → General
2. Enable "Read and write permissions"
3. Or use PAT (Personal Access Token) instead

---

## Getting More Help

### Collecting Diagnostic Information

When asking for help, provide:

1. **Error message**:
```bash
# Copy full error from log
cat curatedMetagenomicData/ETL/logs/etl_pipeline_*.log | tail -50
```

2. **System information**:
```r
sessionInfo()
```

3. **Configuration** (redact sensitive info):
```bash
cat curatedMetagenomicData/ETL/config.yaml | grep -v "url:"
```

4. **Recent changes**:
```bash
git log --oneline -10
```

### Useful Debugging Commands

```r
# Check what went wrong
source("curatedMetagenomicData/ETL/R/validation.R")
# Run validation interactively

# Test configuration loading
source("curatedMetagenomicData/ETL/R/config_loader.R")
config <- load_config()
print_config_summary(config)

# Verify paths
config$paths$maps_dir
file.exists(config$paths$maps_dir)

# Test Google Sheets connection
library(googlesheets4)
gs4_get(config$google_sheets$curation_maps_url)
```

### Where to Report Issues

1. **GitHub Issues**: https://github.com/waldronlab/OmicsMLRepoData/issues
2. **Include**:
   - Error message
   - Steps to reproduce
   - System information
   - Log files (if applicable)
3. **Search first**: Issue might already be reported/solved

### Additional Resources

- **R Documentation**: `?function_name`
- **Package Documentation**: `help(package="package_name")`
- **Stack Overflow**: Tag with `[r]` and `[etl]`
- **R-help Mailing List**: https://stat.ethz.ch/mailman/listinfo/r-help
