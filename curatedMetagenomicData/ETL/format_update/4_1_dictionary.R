## cMD dictionary format updating 06.24.24

##### [Minor] Description for `sequencing_platform` ----------------
newDesc <- "A scientific instrument used to automate the DNA sequencing process"
sf_ind <- which(filled_dd$col.name == "sequencing_platform")
filled_dd[sf_ind,]$description <- newDesc

##### Columns with multiple values (separate using ;)
multiVal <- c("ancestry_details", "curator", "disease", "disease_details",
              "fmt_id", "hla", "treatment", "target_condition")
multiValInd <- which(filled_dd$col.name %in% multiVal)

##### Columns with merged attributes (key:value seperated by <;>)
multiAttr <- c("feces_phenotype", "probing_pocket_depth", "uncurated_metadata",
               "biomarker")
multiAttrInd <- which(filled_dd$col.name %in% multiAttr)

filled_dd$delimiter <- NA
filled_dd$delimiter[multiValInd] <- ";"
filled_dd$delimiter[multiAttrInd] <- "<;>"
