# Dictionary Builders

This directory contains modular scripts for building data dictionary entries for different categories of attributes in the curatedMetagenomicData ETL pipeline.

## Organization

The dictionary builders are organized by attribute categories:

- **`clinical_attributes.R`**: Clinical/demographic attributes
  - age, age_unit, age_group
  - bmi, weight_kg
  - smoker, alcohol
  - sex

- **`condition_attributes.R`**: Disease and condition attributes
  - disease, disease_details
  - treatment, antibiotics_current_use
  - target_condition
  - control

- **`location_attributes.R`**: Geographic and anatomical location attributes
  - body_site, body_site_details
  - country
  - ancestry, population_ancestry

- **`technical_attributes.R`**: Technical and metadata attributes
  - dna_extraction_kit
  - pmid, pubmed_id
  - ncbi_accession
  - sequencing_platform

- **`specialized_attributes.R`**: Specialized medical attributes
  - biomarker
  - neonatal_*
  - obgyn_*
  - tumor_staging_*

## Usage

Each builder module:
1. Reads relevant curation maps from `mapDir`
2. Creates data dictionary entries with standardized structure
3. Updates the `filled_dd` object via the `fillDataDictionary()` function

### Required Inputs

All builder scripts require:
- `filled_dd`: The data dictionary template to populate
- `mapDir`: Path to curation maps directory
- `dataDir`: Path to curated data directory (for some builders)

### Standard Structure

Each dictionary entry includes:
- `col.name`: Column name
- `col.class`: Data type (character, integer, numeric, logical)
- `uniqueness`: "unique" or "non-unique"
- `requiredness`: "required" or "optional"
- `multiplevalues`: TRUE or FALSE
- `description`: Human-readable description
- `allowedvalues`: Pipe-delimited allowed values or regex pattern
- `ontology`: Pipe-delimited ontology term IDs

## Integration

These builders are called by `04_build_data_dictionary.R` during the ETL pipeline execution.

## Maintenance

When adding new attributes:
1. Determine the appropriate category
2. Add the attribute definition to the relevant builder
3. Ensure curation maps exist in the maps directory
4. Update this README if adding a new category
