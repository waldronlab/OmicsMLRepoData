### cMD_ETL_1_sampleMetadata
- Update the `sampleMetadata` table in three versions:
    1) Full-version to replace original cMD `sampleMetadata` table with the 
    additional harmonized columns
    2) Compact version with the `uncurated` column combining all the uncurated
    columns
    3) Parquet version of 1) for DuckDB

- Completeness update: calculate the completeness of original and curated 
columns, then save it in Google Sheet.


### cMD_ETL_2_data_dictionary
- Building a schema table from map files and save it at GitHub repo and 
Google Sheet.   
- Also combined with the new schema table with the original data dictionary