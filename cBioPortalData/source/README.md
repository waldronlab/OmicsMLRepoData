## cBioPortal_all_clinicalData_combined_`Sys.Date()`.csv   
A data frame merging all the tables in `cBioPortal_all_clinicalData.rds` file,
where each element are obtained from `clinicalData` function.
```
> dim(cBioPortal_all_clinicalData_combined)
[1] 179771   3536
> cBioPortal_all_clinicalData_combined[1:5, 1:5]
patientId SAMPLE_COUNT        sampleId MUTATION_COUNT     CANCER_TYPE_DETAILED
2 TCGA-OR-A5J1            1 TCGA-OR-A5J1-01             39 Adrenocortical Carcinoma
3 TCGA-OR-A5J2            1 TCGA-OR-A5J2-01             81 Adrenocortical Carcinoma
4 TCGA-OR-A5J3            1 TCGA-OR-A5J3-01             69 Adrenocortical Carcinoma
5 TCGA-OR-A5J4            1 TCGA-OR-A5J4-01            171 Adrenocortical Carcinoma
6 TCGA-OR-A5J5            1 TCGA-OR-A5J5-01            521 Adrenocortical Carcinoma
```

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


## cBioPortal_all_molecularProfiles_`Sys.Date()`.rds   
A list with the length of all the available studies (360 on 10.12.22) in 
cBioPortal. Each element is a data frame of available molecular profiles 
in detail for a given study, obtained from `molecularProfiles` function.
```
> head(cBioPortal_all_molecularProfiles[[1]], 3)
molecularAlterationType   datatype                                         name
1           PROTEIN_LEVEL LOG2-VALUE                    Protein expression (RPPA)
2           PROTEIN_LEVEL    Z-SCORE           Protein expression z-scores (RPPA)
3  COPY_NUMBER_ALTERATION   DISCRETE Putative copy-number alterations from GISTIC
description
1                                                                                                                                       Protein expression measured by reverse-phase protein array
2                                                                                                                            Protein expression, measured by reverse-phase protein array, z-scores
3 Putative copy-number calls on 90 cases determined using GISTIC 2.0. Values: -2 = homozygous deletion; -1 = hemizygous deletion; 0 = neutral / no change; 1 = gain; 2 = high level amplification.
showProfileInAnalysisTab patientLevel    molecularProfileId  studyId
1                    FALSE        FALSE         acc_tcga_rppa acc_tcga
2                     TRUE        FALSE acc_tcga_rppa_Zscores acc_tcga
3                     TRUE        FALSE       acc_tcga_gistic acc_tcga
```

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


