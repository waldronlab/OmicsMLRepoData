### The cMD data dictionary undergoes modification across Google Sheet and 
### local R session - the main data entry happens in Google Sheet and data 
### cleaning happens in the local R session. This script puts together the
### initial version of cMD data dictionary. Details on the attribute 
### description are added in Google Sheet.

### After the initial assembly of the cMD data dictionary, Google Sheet version
### stays as a default. 


# Connect to Google Drive
url <- "https://docs.google.com/spreadsheets/d/1xziFB_zBl32BjNarcyEN4GupTYpPtq5aDz0GbRbWvtk/edit?usp=sharing"
ss <- googledrive::as_id(url)

# Import merging schema drafts from Google Sheet ----
map <- read_sheet(ss, sheet = "merging_schema_allCols")
dd <- read_sheet(ss, sheet = "data_dictionary_allCols")
dd$merge <- as.character(dd$merge)

# Load original cMD data dictionary
ori_dd <- read_csv("https://raw.githubusercontent.com/waldronlab/curatedMetagenomicDataCuration/master/inst/extdata/template.csv")

# Data dictionary for non-merging columns ----
cols_to_keep <- dd[which(dd$merge %in% c("FALSE")),]$curated_column # not-affected columns
cols_to_keep_names <- map$ori_column[map$curated_column %in% cols_to_keep]
kept_dd <- dplyr::filter(ori_dd, col.name %in% cols_to_keep_names) # subset of the original data dictionary to be kept

# Data dictionary for to-be-merged columns ----
cols_to_merge <- dd[which(dd$merge %in% c("TRUE", "Uncurated")),]$curated_column %>% strsplit(., ";") %>% unlist
merged_cols_dd <- as.data.frame(matrix(nrow = length(cols_to_merge), ncol = ncol(kept_dd)))
colnames(merged_cols_dd) <- colnames(kept_dd)
merged_cols_dd$col.name <- cols_to_merge

# Combine data dictionary drafts ----
required_cols <- c("study_name", "subject_id", "sample_id", 
                   "target_condition", "control", "country", 
                   "body_site")
id_ind <- which(kept_dd$col.name %in% required_cols)
required_ind <- which(merged_cols_dd$col.name %in% required_cols)
template_dd <- dplyr::bind_rows(merged_cols_dd[-required_ind,],
                                kept_dd[-id_ind,]) %>%
    dplyr::arrange(., col.name) %>% # alphabetical ordering of columns except the ID cols
    dplyr::bind_rows(kept_dd[id_ind,], merged_cols_dd[required_ind,], .) %>%
    dplyr::relocate(description, .after = multiplevalues) %>%
    dplyr::mutate(ontology = NA) # introduce ontology column
