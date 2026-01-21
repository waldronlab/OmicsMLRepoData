## ETL Pipeline Tests for curatedMetagenomicData

# Setup test environment
test_data_dir <- tempdir()

# Helper function to create mock data
create_mock_curated_metadata <- function() {
    data.frame(
        study_name = c("Study1", "Study2", "Study3"),
        subject_id = c("S1", "S2", "S3"),
        sample_id = c("Sample1", "Sample2", "Sample3"),
        body_site = c("stool", "skin", "oral"),
        country = c("USA", "Canada", "UK"),
        body_site_ontology_term_id = c("UBERON:0001988", "UBERON:0001003", "UBERON:0000167"),
        stringsAsFactors = FALSE
    )
}

create_mock_merging_schema <- function() {
    data.frame(
        ori_column = c("study", "sample", "bodysite"),
        curated_column = c("study_name", "sample_id", "body_site"),
        stringsAsFactors = FALSE
    )
}

create_mock_data_dictionary <- function() {
    data.frame(
        ColName = c("study_name", "sample_id", "body_site"),
        ColClass = c("character", "character", "character"),
        Description = c("Study identifier", "Sample identifier", "Body site"),
        AllowedValues = c(NA, NA, "stool|skin|oral"),
        stringsAsFactors = FALSE
    )
}

create_mock_curation_map <- function() {
    data.frame(
        original_value = c("feces", "stool", "faeces"),
        curated_ontology_term = c("stool", "stool", "stool"),
        curated_ontology_term_id = c("UBERON:0001988", "UBERON:0001988", "UBERON:0001988"),
        curated_ontology_term_db = c("UBERON", "UBERON", "UBERON"),
        stringsAsFactors = FALSE
    )
}

# Tests for Configuration Management
test_that("Configuration loader works correctly", {
    skip_if_not_installed("yaml")
    
    # Test that config file exists
    config_file <- "curatedMetagenomicData/ETL/config.yaml"
    expect_true(file.exists(config_file), 
                info = "Config file should exist")
})

# Tests for Curated Metadata
test_that("Curated metadata has required columns", {
    mock_data <- create_mock_curated_metadata()
    required_cols <- c("study_name", "subject_id", "sample_id", "body_site", "country")
    
    expect_true(all(required_cols %in% colnames(mock_data)),
                info = "All required columns should be present")
})

test_that("No duplicate sample_ids in curated metadata", {
    mock_data <- create_mock_curated_metadata()
    
    expect_equal(dplyr::n_distinct(mock_data$sample_id), nrow(mock_data),
                 info = "sample_id should be unique")
})

test_that("Ontology IDs follow expected format", {
    mock_data <- create_mock_curated_metadata()
    
    # Test UBERON IDs
    if ("body_site_ontology_term_id" %in% colnames(mock_data)) {
        ontology_ids <- mock_data$body_site_ontology_term_id[!is.na(mock_data$body_site_ontology_term_id)]
        
        # Should match pattern DB:ID
        expect_true(all(grepl("^[A-Z]+:[A-Za-z0-9_]+$", ontology_ids)),
                    info = "Ontology IDs should follow DB:ID format")
    }
})

# Tests for Merging Schema
test_that("Merging schema has required columns", {
    mock_schema <- create_mock_merging_schema()
    required_cols <- c("ori_column", "curated_column")
    
    expect_true(all(required_cols %in% colnames(mock_schema)),
                info = "Merging schema should have required columns")
})

test_that("Merging schema covers curated columns", {
    mock_data <- create_mock_curated_metadata()
    mock_schema <- create_mock_merging_schema()
    
    # At least some curated columns should be in merging schema
    curated_cols <- colnames(mock_data)
    mapped_cols <- mock_schema$curated_column
    
    overlap <- intersect(curated_cols, mapped_cols)
    expect_true(length(overlap) > 0,
                info = "Merging schema should map some curated columns")
})

# Tests for Data Dictionary
test_that("Data dictionary has all required fields", {
    mock_dict <- create_mock_data_dictionary()
    required_fields <- c("ColName", "ColClass", "Description", "AllowedValues")
    
    expect_true(all(required_fields %in% colnames(mock_dict)),
                info = "Data dictionary should have required fields")
})

test_that("Data dictionary covers curated columns", {
    mock_data <- create_mock_curated_metadata()
    mock_dict <- create_mock_data_dictionary()
    
    # Key columns should be documented
    key_cols <- c("study_name", "sample_id", "body_site")
    expect_true(all(key_cols %in% mock_dict$ColName),
                info = "Key columns should be in data dictionary")
})

test_that("Data dictionary descriptions are not empty", {
    mock_dict <- create_mock_data_dictionary()
    
    # Filter out NA values
    descriptions <- mock_dict$Description[!is.na(mock_dict$Description)]
    
    expect_true(all(nchar(descriptions) > 0),
                info = "Descriptions should not be empty strings")
})

# Tests for Curation Maps
test_that("Curation maps have required columns", {
    mock_map <- create_mock_curation_map()
    required_cols <- c("original_value", "curated_ontology_term", 
                       "curated_ontology_term_id", "curated_ontology_term_db")
    
    expect_true(all(required_cols %in% colnames(mock_map)),
                info = "Curation maps should have required columns")
})

test_that("Curation map ontology IDs are valid", {
    mock_map <- create_mock_curation_map()
    
    ontology_ids <- mock_map$curated_ontology_term_id[!is.na(mock_map$curated_ontology_term_id)]
    
    expect_true(all(grepl("^[A-Z]+:[A-Za-z0-9_]+$", ontology_ids)),
                info = "Ontology IDs should follow standard format")
})

test_that("Curation map databases match ID prefixes", {
    mock_map <- create_mock_curation_map()
    
    for (i in 1:nrow(mock_map)) {
        if (!is.na(mock_map$curated_ontology_term_id[i]) && 
            !is.na(mock_map$curated_ontology_term_db[i])) {
            
            id_prefix <- strsplit(mock_map$curated_ontology_term_id[i], ":")[[1]][1]
            expected_db <- mock_map$curated_ontology_term_db[i]
            
            expect_equal(id_prefix, expected_db,
                         info = sprintf("Database prefix should match for row %d", i))
        }
    }
})

# Tests for Helper Functions
test_that("Ontology helper functions work correctly", {
    skip_if_not_installed("yaml")
    
    # Source the helper
    source("curatedMetagenomicData/ETL/R/utils/ontology_helpers.R")
    
    # Test get_ontology_db
    expect_equal(get_ontology_db("NCIT:C12345"), "NCIT")
    expect_equal(get_ontology_db("UBERON:0001988"), "UBERON")
    expect_true(is.na(get_ontology_db("invalid")))
    
    # Test validate_ontology_id
    expect_true(validate_ontology_id("NCIT:C12345"))
    expect_true(validate_ontology_id("UBERON:0001988"))
    expect_false(validate_ontology_id("invalid"))
    expect_false(validate_ontology_id(""))
})

test_that("Validation helper functions work correctly", {
    skip_if_not_installed("yaml")
    
    # Source the helper
    source("curatedMetagenomicData/ETL/R/utils/validation_helpers.R")
    
    # Test check_duplicates
    test_data <- data.frame(id = c(1, 2, 2, 3))
    result <- check_duplicates(test_data, "id")
    
    expect_false(result$passed)
    expect_equal(result$duplicate_count, 1)
})

# Integration Tests
test_that("ETL pipeline config can be loaded", {
    skip_if_not_installed("yaml")
    
    source("curatedMetagenomicData/ETL/R/config_loader.R")
    
    config_file <- "curatedMetagenomicData/ETL/config.yaml"
    if (file.exists(config_file)) {
        expect_error(load_config(config_file), NA,
                     info = "Config should load without errors")
    } else {
        skip("Config file not found")
    }
})

test_that("Validation functions can be sourced", {
    expect_error({
        source("curatedMetagenomicData/ETL/R/validation.R")
    }, NA, info = "Validation module should load without errors")
})

test_that("Provenance functions can be sourced", {
    expect_error({
        source("curatedMetagenomicData/ETL/R/provenance.R")
    }, NA, info = "Provenance module should load without errors")
})
