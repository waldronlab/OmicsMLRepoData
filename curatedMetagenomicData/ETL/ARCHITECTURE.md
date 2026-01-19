# ETL Pipeline Architecture

## System Overview

The curatedMetagenomicData ETL pipeline is a modular, configuration-driven system for curating, harmonizing, and validating metadata from metagenomic studies. It integrates data from multiple sources, applies ontology-based standardization, and produces validated outputs for downstream AI/ML applications.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                 Google Sheets (Source)                  │
│  ┌──────────────────┐        ┌───────────────────────┐  │
│  │ Curation Maps    │        │ Merging Schema        │  │
│  │ (Ontology Terms) │        │ (Column Mappings)     │  │
│  └──────────────────┘        └───────────────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│                 ETL Pipeline Orchestrator                      │
│                  (run_etl_pipeline.R)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Configuration Management (config.yaml, config_loader.R) │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                   │
│     ┌──────────────────────┼──────────────────────┐            │
│     ↓                      ↓                      ↓            │
│ ┌─────────┐          ┌──────────┐          ┌──────────┐        │
│ │Logging  │          │Validation│          │Provenance│        │
│ │Helpers  │          │Framework │          │Tracking  │        │
│ └─────────┘          └──────────┘          └──────────┘        │
└────────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ↓                  ↓                  ↓
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  ETL Steps      │ │  Data Helpers   │ │ Dict Builders   │
│  (01-07)        │ │  (Utils)        │ │  (Modules)      │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────┐
│                         Outputs                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │Curated       │  │Merging       │  │Data          │   │
│  │Metadata      │  │Schema        │  │Dictionary    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
         │
         ↓
┌────────────────────────────────────────────────────┐
│                  Sync Targets                      │
│  OmicsMLRepoCuration │ OmicsMLRepoR │ GCS Bucket   │
└────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Configuration Layer

**Purpose**: Centralized configuration management for all ETL operations.

**Components**:
- `config.yaml`: YAML configuration file with paths, URLs, and settings
- `config_loader.R`: Configuration parsing and validation functions

**Key Features**:
- Path management with tilde expansion
- Google Sheets URL configuration
- Sync target definitions
- Step configuration with dependencies
- Validation of configuration structure

### 2. Orchestration Layer

**Purpose**: Coordinates execution of ETL steps with error handling and logging.

**Components**:
- `run_etl_pipeline.R`: Master orchestrator script

**Key Features**:
- Command-line argument parsing
- Sequential step execution
- Error handling and rollback
- Execution time tracking
- Validation-only mode
- Step dependency management

### 3. Core Utilities Layer

**Purpose**: Reusable utility functions for common operations.

**Components**:

#### Logging (`utils/logging_helpers.R`)
- Structured logging with levels (DEBUG, INFO, WARN, ERROR)
- File and console logging
- Step start/complete/error logging
- Integration with `logger` package

#### Data Operations (`utils/data_helpers.R`)
- Safe CSV read/write with backup
- Column validation
- Data joining with logging
- Multi-file loading
- Target synchronization

#### Ontology Operations (`utils/ontology_helpers.R`)
- Ontology ID extraction and validation
- Format checking (DB:ID pattern)
- Ontology database identification
- Coverage analysis

#### Validation (`utils/validation_helpers.R`)
- Duplicate detection
- Missing value checks
- Data type validation
- Value range checking
- Curation map structure validation

### 4. Validation Framework

**Purpose**: Comprehensive validation of all ETL outputs.

**Components**:
- `validation.R`: Validation functions for each output type

**Validation Types**:
- **Curated Metadata**: Required columns, duplicates, ontology formats
- **Merging Schema**: Structure, column coverage
- **Data Dictionary**: Completeness, ontology IDs
- **Curation Maps**: Structure, format, consistency

**Output**: Detailed validation reports with pass/fail status

### 5. Provenance Tracking

**Purpose**: Track execution context and data lineage.

**Components**:
- `provenance.R`: Provenance metadata management

**Tracked Information**:
- Execution timestamp
- Git commit hash and branch
- User and system information
- R version
- Package versions
- Data dimensions
- Step-specific metadata

**Output**: JSON provenance logs for each step

### 6. ETL Steps Layer

**Purpose**: Individual transformation steps executed in sequence.

**Steps**:

1. **01_sync_curation_maps.R**
   - Downloads curation maps from Google Sheets
   - Validates required columns
   - Saves to local maps directory

2. **02_assemble_curated_metadata.R**
   - Loads curated data files
   - Joins datasets by curation_id
   - Combines with original metadata

3. **03_build_merging_schema.R**
   - Loads schema from Google Sheets
   - Generates mapping statistics
   - Validates coverage

4. **04_build_data_dictionary.R**
   - Assembles dictionary template
   - Populates from dictionary builders
   - Adds ontology information

5. **05_add_dynamic_enums.R**
   - Identifies dynamic enumeration attributes
   - Extracts common ontology nodes
   - Updates dictionary

6. **06_format_for_release.R**
   - Removes internal columns
   - Strips prefixes
   - Orders columns
   - Adds metadata

7. **07_validate_and_export.R**
   - Runs all validations
   - Exports to sync targets
   - Uploads to GCS
   - Generates reports

### 7. Dictionary Builders

**Purpose**: Modular construction of data dictionary entries.

**Organization**:
- `clinical_attributes.R`: Demographics, clinical measures
- `condition_attributes.R`: Disease, treatment, control
- `location_attributes.R`: Geographic and anatomical
- `technical_attributes.R`: Technical metadata
- `specialized_attributes.R`: Domain-specific attributes

**Pattern**: Each builder loads maps, defines entries, updates dictionary

## Data Flow

### Input Sources
1. **Google Sheets**: Curation maps and schema definitions
2. **Local CSV Files**: Curated data per attribute
3. **Configuration**: `config.yaml` with settings

### Processing Pipeline
```
Raw Data → Sync → Assemble → Schema → Dictionary → Enums → Format → Validate → Export
```

### Output Destinations
1. **Local**: `inst/extdata/` directory
2. **Package Sync**: OmicsMLRepoCuration, OmicsMLRepoR
3. **Cloud**: Google Cloud Storage bucket
4. **Logs**: Execution and validation reports

## Technology Stack

### Core Technologies
- **Language**: R (>= 4.0.0)
- **Package Manager**: R package system
- **Configuration**: YAML
- **Logging**: logger package (optional)
- **Serialization**: JSON (jsonlite)

### Data Handling
- **CSV I/O**: readr
- **Data Manipulation**: dplyr
- **Google Sheets**: googlesheets4, googledrive

### Testing
- **Framework**: testthat
- **Coverage**: Unit and integration tests

### Automation
- **CI/CD**: GitHub Actions
- **Scheduling**: Cron-based triggers
- **Artifacts**: Log upload and retention

## Design Principles

### 1. Modularity
- Each step is self-contained
- Utility functions are reusable
- Dictionary builders are independent

### 2. Configuration-Driven
- All paths and URLs in config
- No hardcoded values in scripts
- Easy environment switching

### 3. Validation-First
- Validation at multiple stages
- Comprehensive error checking
- Detailed validation reports

### 4. Observability
- Structured logging throughout
- Provenance tracking
- Execution reports

### 5. Backward Compatibility
- Original scripts maintained
- New pipeline runs alongside
- Gradual migration path

### 6. Error Resilience
- Graceful error handling
- Detailed error messages
- Safe file operations with backups

## Security Considerations

### Authentication
- Google Sheets: Token-based auth
- GCS: Service account credentials
- Secrets: GitHub Secrets for CI/CD

### Data Protection
- No credentials in code
- Backup before overwrite
- Git-ignored sensitive files

### Access Control
- Read-only access to source sheets
- Controlled write access to outputs
- Audit trail via provenance logs

## Scalability Considerations

### Current Design
- Single-threaded execution
- Sequential step processing
- Local file operations

### Future Enhancements
- Parallel step execution where safe
- Distributed processing for large datasets
- Cloud-based storage and compute

## Monitoring and Observability

### Logging
- Console output for real-time monitoring
- File logs for historical analysis
- Structured format for parsing

### Metrics
- Execution time per step
- Data volume statistics
- Validation pass rates

### Alerting
- GitHub Actions notifications
- Failed validation reports
- Error logs with stack traces

## Disaster Recovery

### Backup Strategy
- Automatic file backups before overwrite
- Git version control for all code
- Provenance logs for audit trail

### Recovery Procedures
1. Identify failed step from logs
2. Review error message and context
3. Fix issue (data, code, or config)
4. Re-run from failed step
5. Validate outputs

## Performance Characteristics

### Typical Execution Times
- Step 01 (Sync): 1-2 minutes
- Step 02 (Assemble): 2-5 minutes
- Step 03 (Schema): 1-2 minutes
- Step 04 (Dictionary): 3-5 minutes
- Step 05 (Enums): 2-3 minutes
- Step 06 (Format): 1-2 minutes
- Step 07 (Export): 2-3 minutes

**Total**: ~15-25 minutes for full pipeline

### Resource Requirements
- Memory: ~4-8 GB
- Disk: ~1 GB temporary space
- Network: Stable connection for Google Sheets

## Version Control and Deployment

### Version Control
- All code in Git repository
- Branch-based development
- Pull request workflow

### Deployment
- No explicit deployment step
- Clone repository and run
- Configuration file customization

### Release Process
1. Develop in feature branch
2. Test locally
3. Create pull request
4. Review and merge
5. Tag release version
6. Update documentation

## Future Improvements

### Short Term
- Complete remaining refactored scripts (02-07)
- Expand test coverage
- Add performance benchmarks

### Medium Term
- Parallel execution where possible
- Enhanced validation rules
- Dashboard for monitoring

### Long Term
- Web interface for configuration
- Real-time monitoring dashboard
- Automated quality metrics
- Machine learning for validation
