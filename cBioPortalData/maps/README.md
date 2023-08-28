### `cBioPortal_disease_curation_schema.csv`
This is the summary table including the different curation categories (`curation_category` column),
the list of potential columns to contribute the given curation categories (`original_columns` column), 
and the number of those original columns (`original_columns_num` column).

```
# A tibble: 32 × 3
   curation_category   original_columns                                                                         original_columns_num
   <chr>               <chr>                                                                                                   <int>
 1 Disease/Cancer Type CANCER_TYPE_DETAILED;CANCER_TYPE;SUBTYPE_DETAILS;SAMPLE_TYPE_DETAIL;SAMPLE_TYPE;INTEGRA…                   75
 2 Cancer/Tumor Stage  STAGE_AT_DIAGNOSIS;PRECRT_AJCC_CLASSIFICATION;STAGE_AT_HCC_DIAGNOSIS;DISEASE_STAGE;M_ST…                   25
 3 Tumor Purity        TUMOR_PURITY;TUMOR_PURTITY;PERCENTAGE_TUMOR_PURITY;TUMOR_PURITY_BYESTIMATE_RNASEQ;ESTIM…                    5
 4 Tumor Type          TUMOR_TYPE;TUMOR_STATUS;TUMOR_MORPHOLOGIC_APPEARANCE_ON_CT;RESIDUAL_TUMOR;PRIMARY_MELAN…                   18
 5 (Diagnosis) Age     DIAGNOSIS AGE;AGE_AT_DIAGNOSIS;YEAR_OF_DIAGNOSIS;AGE_AT_SPECIMEN_DIAGNOSIS;AGE_AT_INITI…                    8
 6 Tumor Grade         GRADE;TUMOR_GRADE;PATIENT_GRADE;WHO_GRADE;BX_GRADE;BX_NUCLEAR_GRADE;DX_GRADE;EDMONDSON_…                   18
 7 # of Tumors         MULTIPLE_TUMORS;TUMOR_NUMBER;NUMBER_OF_TUMORS;NEW_TUMOR_EVENT_MELANOMA_COUNT                                4
 8 Body Site           TUMOR_TISSUE_ORIGIN;PRIMARY_TUMOR_LOCATION;ESOPHAGEAL_TUMOR_LOCATION_INVOLVED;DIAGNOSIS…                   38
 9 Genetic Variant     MUTATION_TYPE;MUT_CANCER_GENE_CENSUS_PROTEIN_CHANGE;MUT_TUMORPORTAL_GENE_PROTEIN_CHANGE                     3
10 Family History      FAMILY_HISTORY_OF_CANCER;FAMILY_HISTORY_ESOPH_GASTIC_CANCER;FAMILY_HISTORY_OTHER_CANCER                     3
# ℹ 22 more rows
# ℹ Use `print(n = ...)` to see more rows
```


### `cBioPortal_disease_curation_summary.csv`
This table shows the summary of 'Disease/Cancer Type' curation work (the first 
row of the `cBioPortal_curation_schema.csv` table). Each of the eight rows are
new 'curated_' columns from different numbers (`original_columns_num` column) 
of original columns (`original_columns` column). This table also contains the 
completeness of original/curated columns and the number of unique values from 
original/curated columns.

```
# A tibble: 8 × 7
  curated_column       original_columns    original_columns_num original_columns_com…¹ curated_column_compl…² original_unique_valu…³
  <chr>                <chr>                              <int> <chr>                                   <dbl>                  <dbl>
1 acronym              CANCER_TYPE_ACRONY…                    2 0.061;0.0053                             0.07                     51
2 cancer_status        PERSON_NEOPLASM_CA…                    1 0.0532                                   0.05                      5
3 cancer_subtype       SUBTYPE;SUBTYPE_AB…                   34 0.21;0.1433;0.011;0.0…                   0.28                   1094
4 cancer_type          CANCER_TYPE;CANCER…                   11 0.9665;0.0021;0.0021;…                   0.97                    446
5 cancer_type_detailed CANCER_TYPE_DETAIL…                    2 0.9704;0.0235                            0.97                    788
6 disease              MDS_TYPE;DISEASE_E…                   19 0.0174;0.0147;0.0122;…                   0.06                    233
7 metastasis           RECURRENT_METASTAT…                    3 0.0051;3e-04;1e-04                       0.01                      4
8 specimen_type        SAMPLE_TYPE;SPECIM…                    3 0.6391;0.1246;0.0028                     0.64                     80
# ℹ abbreviated names: ¹​original_columns_completeness, ²​curated_column_completeness, ³​original_unique_values_num
# ℹ 1 more variable: curated_unique_values_num <dbl>
```


### `cBioPortal_diseases_map.csv`
cBioPortal disease ontology map
```
# A tibble: 2,130 × 4
   original_value                    curated_ontology                                  curated_ontology_term_id curated_ontology_term_db
   <chr>                             <chr>                                             <chr>                    <chr>                   
 1 GCB                               germinal center B cell                            CL:0000844               NCIT                    
 2 FIBROBLAST_LUNG                   fibroblast of lung                                CL:0002553               CL                      
 3 FIBROBLAST_BREAST                 fibroblast of breast                              CL:4006000               CL                      
 4 IMMORTALIZED_EPITHELIAL           immortal epithelial cell line cell                CLO:0000129              CLO                     
 5 IMMORTALIZED_FIBROBLAST           immortal fibroblast cell line cell                CLO:0000161              CLO                     
 6 IMMORTALIZED_EMBRYONIC_FIBROBLAST immortal embryo-derived fibroblast cell line cell CLO:0000193              CLO                     
 7 UNDIFFERENTIATED_SARCOMA          undifferentiated sarcoma                          EFO:0000730              EFO                     
 8 TESTICULAR CARCINOMA              Testicular Carcinoma                              EFO:0005088              EFO                     
 9 NEPHROBLASTOMATOSIS               Nephroblastomatosis                               HP:0008643               HP                      
10 GASTRIC TYPE MUCINOUS CARCINOMA   Mucinous gastric carcinoma                        HP:0031498               HP                      
# ℹ 2,120 more rows
# ℹ Use `print(n = ...)` to see more rows
```


### `cBioPortal_cancer_map.csv`
cBioPortal cancer ontology map
```
# A tibble: 773 × 4
   original_value                       curated_ontology                  curated_ontology_term_id curated_ontology_term_db
   <chr>                                <chr>                             <chr>                    <chr>                   
 1 Adrenocortical Carcinoma             Adrenocortical carcinoma          HP:0006744               HP                      
 2 Skin Cancer, Non-Melanoma            Skin Carcinoma                    NCIT:C4914               NCIT                    
 3 Ampullary Carcinoma                  Ampulla of Vater Carcinoma        NCIT:C3908               NCIT                    
 4 Bladder Urothelial Carcinoma         Bladder Urothelial Carcinoma      NCIT:C39851              NCIT                    
 5 B-Lymphoblastic Leukemia/Lymphoma    B Lymphoblastic Leukemia/Lymphoma NCIT:C8936               NCIT                    
 6 Adenoid Cystic Carcinoma             Adenoid Cystic Carcinoma          NCIT:C2970               NCIT                    
 7 Acute Lymphoid Leukemia              Acute Lymphoblastic Leukemia      NCIT:C3167               NCIT                    
 8 Angiosarcoma                         Angiosarcoma                      NCIT:C3088               NCIT                    
 9 Acute Myeloid Leukemia               Acute Myeloid Leukemia            NCIT:C3171               NCIT                    
10 Benign Phyllodes Tumor of the Breast Benign Breast Phyllodes Tumor     NCIT:C5196               NCIT                    
# ℹ 763 more rows
# ℹ Use `print(n = ...)` to see more rows
```
