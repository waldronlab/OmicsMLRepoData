## EDA_cBioPortalData_Molecular.qmd

## EDA_cBioPortalData_Clinical.qmd

## cBioPortal_all_molecularProfile_combined_`Sys.Date()`.rds  
A data frame combining all the tables in `cBioPortal_all_molecularProfiles.rds`
file, which are from `molecularProfiles` function.
```
> class(cBioPortal_all_molecularProfile_combined)
[1] "data.frame"
> dim(cBioPortal_all_molecularProfile_combined)
[1] 1694   11
> colnames(cBioPortal_all_molecularProfile_combined)
 [1] "datatype"                 "description"              "molecularAlterationType"  "molecularProfileId"       "name"         "patientLevel"
 [7] "showProfileInAnalysisTab" "studyId"                  "genericAssayType"         "pivotThreshold"           "sortOrder"
> cBioPortal_all_molecularProfile_combined[1:5, c("datatype", "molecularAlterationType", "molecularProfileId", "name", "patientLevel", "studyId")]
    datatype molecularAlterationType    molecularProfileId                                         name patientLevel  studyId
2 LOG2-VALUE           PROTEIN_LEVEL         acc_tcga_rppa                    Protein expression (RPPA)        FALSE acc_tcga
3    Z-SCORE           PROTEIN_LEVEL acc_tcga_rppa_Zscores           Protein expression z-scores (RPPA)        FALSE acc_tcga
4   DISCRETE  COPY_NUMBER_ALTERATION       acc_tcga_gistic Putative copy-number alterations from GISTIC        FALSE acc_tcga
5 CONTINUOUS  COPY_NUMBER_ALTERATION   acc_tcga_linear_CNA    Capped relative linear copy-number values        FALSE acc_tcga
6        MAF       MUTATION_EXTENDED    acc_tcga_mutations                                    Mutations        FALSE acc_tcga
```

Eight variables are available for all studies.
```
> colSums(is.na(cBioPortal_all_molecularProfile_combined))
                datatype              description  molecularAlterationType 
                       0                        0                        0 
      molecularProfileId                     name             patientLevel 
                       0                        0                        0 
showProfileInAnalysisTab                  studyId         genericAssayType 
                       0                        0                     1569 
          pivotThreshold                sortOrder 
                    1651                     1620 
```


## cBioPortal_all_molecularProfile_table.csv  
A table with two columns: `molecularAlterationType` and `n`. `n` is the number
of studies available with a given type of data (`molecularAlterationType`).
This is a summary of `cBioPortal_all_molecularProfile_combined_{Sys.Date()}.rds` file.


## cBioPortal_all_clinicalData_`Sys.Date()`.rds 
List with the length of all the available studies (360 on 10.12.22) in 
cBioPortal. Each element of this list is a clinical metadata table. This 
is an output from `clinicalData` function.
```
> length(cBioPortal_all_clinicalData)
[1] 360
> head(names(cBioPortal_all_clinicalData), 3)
[1] "acc_tcga"       "bcc_unige_2016" "ampca_bcm_2016"
> dim(cBioPortal_all_clinicalData[[1]])
[1] 92 85
> cBioPortal_all_clinicalData[[1]][1:5, 1:5]
# A tibble: 5 × 5
  patientId    AGE   AJCC_PATHOLOGIC_TUMOR_STAGE ATYPICAL_MITOTIC_FIGURES         CAPSULAR_INVASION                
  <chr>        <chr> <chr>                       <chr>                            <chr>                            
1 TCGA-OR-A5J1 58    Stage II                    Atypical Mitotic Figures Absent  Invasion of Tumor Capsule Absent 
2 TCGA-OR-A5J2 44    Stage IV                    Atypical Mitotic Figures Present Invasion of Tumor Capsule Present
3 TCGA-OR-A5J3 23    Stage III                   Atypical Mitotic Figures Absent  Invasion of Tumor Capsule Absent 
4 TCGA-OR-A5J4 23    Stage IV                    Atypical Mitotic Figures Absent  Invasion of Tumor Capsule Present
5 TCGA-OR-A5J5 30    Stage III                   Atypical Mitotic Figures Present Invasion of Tumor Capsule Present
```
