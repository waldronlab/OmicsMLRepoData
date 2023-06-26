library(tidyverse)
library(googlesheets4)
library(janitor)
library(utile.tools)
#library(qdapDictionaries)
#library(cBioPortalData)

#data(GradyAugmented)

# sheet = Potential Treatment Columns
url_1 <- ""
ss <- googledrive::as_id(url_1)

# sheet = Column Groups
url_2 <- ""
tt <- googledrive::as_id(url_2)

# sheet = Shared Treatment Curation Sheet
url_3 <- "https://docs.google.com/spreadsheets/d/1E6Xr1Aa8gxu6MgujOQ7kxarlZ7O8-Iy8XsCp7-0BHXY/edit#gid=1020044523"
uu <- googledrive::as_id(url_3)


#cbio <- cBioPortal()

old_rds_data <- readRDS("cBioPortal_all_clinicalData_combined_2022-10-14.rds")
rds_data <- readRDS("cBioPortal_all_clinicalData_combined_2023-05-18.rds")
#uncombined_rds_data <- readRDS("cBioPortal_all_clinicalData_2022-10-12.rds")

rds_data <- remove_empty(rds_data, which = "cols", quiet = FALSE)
nonNACols <- colnames(rds_data)

#### could use
nonNACol_info <- rds_data[, nonNACols]

unique_data <- apply(nonNACol_info, 2, function(x) unique(na.omit(x)))
####

################ NOT IN USE
# collect approved (and maybe ?) columns
approved_drug <- read_sheet(ss, sheet = "drug_colnames")
approved_dosage <- read_sheet(ss, sheet = "dosage_colnames")
approved_treatment <- read_sheet(ss, sheet = "treatment_colnames")

approved_cols <- unname(unlist(c(approved_drug[approved_drug$relevant == "YES", "drug_colnames"],
                   approved_dosage[approved_dosage$relevant == "YES", "dosage_colnames"],
                   approved_treatment[approved_treatment$relevant == "YES", "treatment_colnames"])))

maybe_cols <- unname(unlist(c(approved_drug[approved_drug$relevant == "MAYBE", "drug_colnames"],
                          approved_dosage[approved_dosage$relevant == "MAYBE", "dosage_colnames"],
                          approved_treatment[approved_treatment$relevant == "MAYBE", "treatment_colnames"])))

empty_cols <- unname(unlist(c(approved_drug[approved_drug$empty == "X", "drug_colnames"],
                              approved_dosage[approved_dosage$empty == "X", "dosage_colnames"],
                              approved_treatment[approved_treatment$empty == "X", "treatment_colnames"])))
#########################

# downloaded drug file from FDA (https://www.fda.gov/drugs/drug-approvals-and-databases/drugsfda-data-files)
fda_drugs <- read.table("Products.txt",
                        sep = "\t",
                        quote = "",
                        header = TRUE,
                        fill = TRUE)

unique_entries <- unique(fda_drugs[, c("DrugName", "ActiveIngredient")])
sheet_write(unique_entries, ss = ss, sheet = "fda_entries")

unique_terms <- unique(c(fda_drugs$DrugName, fda_drugs$ActiveIngredient))

# split on all non-alphanumeric characters except hyphens (including whitespace)
split_terms <- unname(unlist(sapply(unique_terms, function(x) strsplit(x, "[^a-zA-Z0-9-]"))))
# remove empty string and any entirely numeric strings, and get unique strings
unique_split_terms <- unique(split_terms[-grep("^$|^\\d+$", split_terms)])
# remove strings with three or less characters and any mixed-case duplicates
fda_search_terms <- unique_split_terms[nchar(unique_split_terms) > 3] %>%
  toupper() %>%
  unique()

# get custom search terms from Google Sheets
custom_term_map <- read_sheet(ss, sheet = "custom_terms")
custom_search_terms <- custom_term_map$search_string

################## NOT IN USE
# create search pattern
search_pattern <- paste(drug_search_terms, collapse = "|")
# check if search term is also an english word
english_terms <- drug_search_terms[tolower(drug_search_terms) %in% tolower(GradyAugmented)]
##################

detected_cols <- data.frame(colname = NA,
                       search_term = NA,
                       term_source = NA,
                       matched_word = NA)

for (term in fda_search_terms){
  cols <- grep(term, nonNACols, ignore.case = TRUE)
  for (col in cols) {
    colname <- nonNACols[col]
    words <- unlist(strsplit(colname, "[^a-zA-Z0-9-]"))
    matched_word <- paste(unique(words[grep(term, words, ignore.case = TRUE)]), collapse = ";")
    new_row <- c(colname, term, "FDA", matched_word)
    detected_cols <- rbind(detected_cols, new_row)
  }
}

for (term in custom_search_terms){
  cols <- grep(term, nonNACols, ignore.case = TRUE)
  for (col in cols) {
    colname <- nonNACols[col]
    words <- unlist(strsplit(colname, "[^a-zA-Z0-9-]"))
    matched_word <- paste(unique(words[grep(term, words, ignore.case = TRUE)]), collapse = ";")
    new_row <- c(colname, term, "CUSTOM", matched_word)
    detected_cols <- rbind(detected_cols, new_row)
  }
}

cleaned_detected <- detected_cols[-1,]
merged_detected <- merge(cleaned_detected,
                       custom_term_map,
                       by.x = "search_term",
                       by.y = "search_string",
                       all.x = TRUE,
                       all.y = FALSE)

combined_detected <- merged_detected %>%
  group_by(colname) %>%
  transmute(colname = colname,
            search_term = paste(search_term, collapse = ";"),
            term_source = paste(unique(term_source), collapse = ";"),
            custom_target = paste(unique(target_term), collapse = ";", na.rm = TRUE)) %>%
  distinct()

match_info <- merged_detected %>%
  group_by(search_term) %>%
  transmute(search_term = search_term,
            term_source = paste(unique(term_source), collapse = ";"),
            matched_word = paste(unique(unlist(strsplit(matched_word, ";"))), collapse = ";", na.rm = TRUE)) %>%
  distinct() 

term_frequency <- as.data.frame(table(cleaned_detected$search_term)) %>%
  left_join(., custom_term_map, join_by(Var1 == search_string)) %>%
  left_join(., match_info, join_by(Var1 == search_term)) %>%
  arrange(desc(Freq)) %>%
  transmute(search_term = Var1,
            frequency = Freq,
            target_term = target_term,
            term_source = term_source,
            matched_word = matched_word) %>%
  rowwise() %>%
  mutate(target_match = any(tolower(unlist(strsplit(c(search_term, target_term), "[^a-zA-Z0-9-]"))) %in% tolower(unlist(strsplit(matched_word, "[^a-zA-Z0-9-]"))))) %>%
  mutate(notes = NA)

col_review_table <- combined_detected %>%
  transmute(relevant = NA,
            colname = colname,
            search_term = search_term,
            custom_target = custom_target,
            notes = NA)

sheet_write(term_frequency, ss = ss, sheet = "initial_term_frequency")
sheet_write(col_review_table, ss = ss, sheet = "initial_detected_cols")

## 2nd run with adjusted terms
adjusted_terms <- read_sheet(ss, sheet = "adjusted_terms")
general_custom <- adjusted_terms$general_search[!is.na(adjusted_terms$general_search)]
exact_custom <- adjusted_terms$exact_search[!is.na(adjusted_terms$exact_search)]
new_fda <- adjusted_terms$keep_fda[!is.na(adjusted_terms$keep_fda)]

custom_term_map <- adjusted_terms[!is.na(adjusted_terms$general_search), c("general_search", "target_term")]

detected_cols <- data.frame(colname = NA,
                            search_term = NA,
                            term_source = NA,
                            matched_word = NA)

for (term in new_fda){
  exact_term <- paste0("(^|[^a-zA-Z0-9-])", term, "([^a-zA-Z0-9-]|$)")
  cols <- grep(exact_term, nonNACols, ignore.case = TRUE)
  for (col in cols) {
    colname <- nonNACols[col]
    words <- unlist(strsplit(colname, "[^a-zA-Z0-9-]"))
    matched_word <- paste(unique(words[grep(term, words, ignore.case = TRUE)]), collapse = ";")
    new_row <- c(colname, term, "FDA", matched_word)
    detected_cols <- rbind(detected_cols, new_row)
  }
}

for (term in exact_custom){
  exact_term <- paste0("(^|[^a-zA-Z0-9-])", term, "([^a-zA-Z0-9-]|$)")
  cols <- grep(exact_term, nonNACols, ignore.case = TRUE)
  for (col in cols) {
    colname <- nonNACols[col]
    words <- unlist(strsplit(colname, "[^a-zA-Z0-9-]"))
    matched_word <- paste(unique(words[grep(term, words, ignore.case = TRUE)]), collapse = ";")
    new_row <- c(colname, term, "EXACT_CUSTOM", matched_word)
    detected_cols <- rbind(detected_cols, new_row)
  }
}

for (term in general_custom){
  cols <- grep(term, nonNACols, ignore.case = TRUE)
  for (col in cols) {
    colname <- nonNACols[col]
    words <- unlist(strsplit(colname, "[^a-zA-Z0-9-]"))
    matched_word <- paste(unique(words[grep(term, words, ignore.case = TRUE)]), collapse = ";")
    new_row <- c(colname, term, "GENERAL_CUSTOM", matched_word)
    detected_cols <- rbind(detected_cols, new_row)
  }
}

cleaned_detected <- detected_cols[-1,]
merged_detected <- merge(cleaned_detected,
                         custom_term_map,
                         by.x = "search_term",
                         by.y = "general_search",
                         all.x = TRUE,
                         all.y = FALSE)

combined_detected <- merged_detected %>%
  group_by(colname) %>%
  transmute(colname = colname,
            search_term = paste(search_term, collapse = ";"),
            term_source = paste(unique(term_source), collapse = ";"),
            custom_target = paste(unique(target_term), collapse = ";", na.rm = TRUE)) %>%
  distinct()

match_info <- merged_detected %>%
  group_by(search_term) %>%
  transmute(search_term = search_term,
            term_source = paste(unique(term_source), collapse = ";"),
            matched_word = paste(unique(unlist(strsplit(matched_word, ";"))), collapse = ";", na.rm = TRUE)) %>%
  distinct()

term_frequency <- as.data.frame(table(cleaned_detected$search_term)) %>%
  left_join(., custom_term_map, join_by(Var1 == general_search)) %>%
  left_join(., match_info, join_by(Var1 == search_term)) %>%
  arrange(desc(Freq)) %>%
  transmute(search_term = Var1,
            frequency = Freq,
            target_term = target_term,
            term_source = term_source,
            matched_word = matched_word) %>%
  rowwise() %>%
  mutate(target_match = any(tolower(unlist(strsplit(c(search_term, target_term), "[^a-zA-Z0-9-]"))) %in% tolower(unlist(strsplit(matched_word, "[^a-zA-Z0-9-]"))))) %>%
  mutate(notes = NA)

unique_val_map <- data.frame(colname = combined_detected$colname,
                             unique_vals = NA)

for(i in 1:nrow(unique_val_map)) {
  colname <- unique_val_map$colname[i]
  unique_val_map$unique_vals[i] <- paste(unique(na.omit(rds_data[, colname])), collapse = ";")
}

col_review_table <- combined_detected %>%
  left_join(., unique_val_map, by = "colname") %>%
  transmute(information = NA,
            colname = colname,
            unique_vals = str_trunc(unique_vals, 500, "right"),
            search_term = search_term,
            custom_target = custom_target,
            notes = NA)

sheet_write(term_frequency, ss = ss, sheet = "adjusted_term_frequency")
sheet_write(col_review_table, ss = ss, sheet = "adjusted_detected_cols")

# prep for manual review
nonNACol_info <- rds_data[, nonNACols]

unique_data <- apply(nonNACol_info, 2, function(x) unique(na.omit(x)))

# relevant column examination
relevant_col_sheet <- read_sheet(ss, sheet = "relevant_col_data")
relevant_colnames <- relevant_col_sheet$colname

# completeness
relevant_rds <- rds_data[, relevant_colnames]
relevant_completeness <- data.frame(colname = relevant_colnames,
                                    completeness = colSums(!is.na(relevant_rds))/nrow(relevant_rds),
                                    row.names = NULL)

study_list <- readRDS("cBioPortal_all_clinicalData_2023-05-18.rds")

# list of relevant names
study_treat_cols <- list()
for(i in 1:length(study_list)){
  study_treat_cols[[i]] <- colnames(study_list[[i]])[colnames(study_list[[i]]) %in% relevant_colnames]
}
names(study_treat_cols) <- names(study_list)
study_treat_cols <- compact(study_treat_cols)

# list of frames with relevant names and unique values
study_treat_vals <- list()
for(i in 1:length(study_list)){
  study <- study_list[[i]]
  relevant_names <- c()
  unique_values <- c()
  for(j in 1:ncol(study)){
    if(colnames(study[,j]) %in% relevant_colnames){
      relevant_names <- append(relevant_names, colnames(study[,j]))
      unique_values <- append(unique_values, unlist(lapply(study[,j], function(x) paste(unique(na.omit(x)), collapse = ";"))))
    }
  }
  relevant_names <- unname(relevant_names)
  unique_values <- unname(unique_values)
  study_cols <- study[, relevant_names]
  study_treat_vals[[i]] <- data.frame(colname = relevant_names,
                                      unique_values = str_trunc(unique_values, 500, "right"),
                                      study_completeness = colSums(!is.na(study_cols))/nrow(study_cols))
}
names(study_treat_vals) <- names(study_list)
study_treat_vals <- study_treat_vals[lengths(study_treat_vals) > 1]

# convert to frame
study_treat_frame <- bind_rows(study_treat_vals, .id = "study_id")
rownames(study_treat_frame) <- NULL

# clustering study treatment schemas
similarities <- as.data.frame(matrix(nrow = length(study_treat_cols), ncol = length(study_treat_cols)))
colnames(similarities) <- names(study_treat_cols)
rownames(similarities) <- names(study_treat_cols)
for(i in 1:nrow(similarities)){
  for(j in 1:ncol(similarities)){
    row_study_names <- study_treat_cols[[i]]
    col_study_names <- study_treat_cols[[j]]
    target <- mean(c(length(row_study_names), length(col_study_names)))
    num_same <- length(intersect(row_study_names, col_study_names))
    score <- num_same/target
    similarities[i,j] <- 1-score
  }
}

heatmap(as.matrix(similarities))
col_tree <- hclust(dist(similarities))
col_clusters <- data.frame(cutree(col_tree, k = 4))
colnames(col_clusters) <- "cluster"
col_clusters$study <- rownames(col_clusters)
rownames(col_clusters) <- NULL
cluster1 <- col_clusters$study[col_clusters$cluster == 1]
cluster2 <- col_clusters$study[col_clusters$cluster == 2]
cluster3 <- col_clusters$study[col_clusters$cluster == 3]
cluster4 <- col_clusters$study[col_clusters$cluster == 4]

cluster1vals <- study_treat_vals[cluster1]
cluster2vals <- study_treat_vals[cluster2]
cluster3vals <- study_treat_vals[cluster3]
cluster4vals <- study_treat_vals[cluster4]

# get colname frequency info
colname_frequency <- as.data.frame(table(study_treat_frame$colname)) %>%
  rename(colname = Var1,
         num_studies = Freq)

# merge all info for schema review
all_info_frame <- study_treat_frame %>%
  left_join(., relevant_completeness, by = "colname") %>%
  left_join(., colname_frequency, by = "colname") %>%
  left_join(., col_clusters, join_by(study_id == study)) %>%
  rename(overall_completeness = completeness)

sheet_write(all_info_frame, ss = ss, sheet = "study_col_data")

# modify relevant_columns to include overall_completeness/num_studies
mod_relevant_col_sheet <- relevant_col_sheet %>%
  left_join(., relevant_completeness, by = "colname") %>%
  left_join(., colname_frequency, by = "colname") %>%
  rename(overall_completeness = completeness)

sheet_write(mod_relevant_col_sheet, ss = ss, sheet = "relevant_col_data")

# bin relevant columns
name_cols <- relevant_col_sheet$colname[relevant_col_sheet$name == "x"]
name_cols <- name_cols[!is.na(name_cols)]
type_cols <- relevant_col_sheet$colname[relevant_col_sheet$type == "x"]
type_cols <- type_cols[!is.na(type_cols)]
amount_cols <- relevant_col_sheet$colname[relevant_col_sheet$amount == "x"]
amount_cols <- amount_cols[!is.na(amount_cols)]
time_cols <- relevant_col_sheet$colname[relevant_col_sheet$time == "x"]
time_cols <- time_cols[!is.na(time_cols)]
case_cols <- relevant_col_sheet$colname[relevant_col_sheet$case == "x"]
case_cols <- case_cols[!is.na(case_cols)]
note_cols <- relevant_col_sheet$colname[relevant_col_sheet$notes == "x"]
note_cols <- note_cols[!is.na(note_cols)]

max_length <- max(length(name_cols),
                  length(type_cols),
                  length(amount_cols),
                  length(time_cols),
                  length(case_cols),
                  length(note_cols))

length(name_cols) <- max_length
length(type_cols) <- max_length
length(amount_cols) <- max_length
length(time_cols) <- max_length
length(case_cols) <- max_length
length(note_cols) <- max_length

binned_cols <- data.frame(treatment_name = name_cols,
                          treatment_type = type_cols,
                          treatment_amount = amount_cols,
                          treatment_time = time_cols,
                          treatment_case = case_cols,
                          treatment_notes = note_cols)
binned_cols[is.na(binned_cols)] <- ""

sheet_write(binned_cols, ss = ss, sheet = "binned_cols")

# get info for coercion
coercion_info <- mod_relevant_col_sheet %>%
  select(review:unique_vals, overall_completeness:num_studies) %>%
  mutate(coerced_value = "", .after = unique_vals) %>%
  mutate(representative_value = "", .after = unique_vals)

# create coercion tables for each curated_column
coerce_name <- filter(coercion_info, colname %in% name_cols)
coerce_type <- filter(coercion_info, colname %in% type_cols)
coerce_amount <- filter(coercion_info, colname %in% amount_cols)
coerce_time <- filter(coercion_info, colname %in% time_cols)
coerce_case <- filter(coercion_info, colname %in% case_cols)
coerce_notes <- filter(coercion_info, colname %in% note_cols)

# write coercion tables to google sheets for manual classification
sheet_write(coerce_name, ss = ss, sheet = "coerce_name")
sheet_write(coerce_type, ss = ss, sheet = "coerce_type")
sheet_write(coerce_amount, ss = ss, sheet = "coerce_amount")
sheet_write(coerce_time, ss = ss, sheet = "coerce_time")
sheet_write(coerce_case, ss = ss, sheet = "coerce_case")
sheet_write(coerce_notes, ss = ss, sheet = "coerce_notes")

# merge name info
# get info
classed_name_cols <- read_sheet(ss, sheet = "coerce_name") %>%
  select(colname, name:val)

name_in_name <- classed_name_cols %>%
  filter(!is.na(name) & is.na(val)) %>%
  select(colname)

name_in_val <- classed_name_cols %>%
  filter(!is.na(val) & is.na(name)) %>%
  select(colname)

name_in_both <- classed_name_cols %>%
  filter(!is.na(name) & !is.na(val)) %>%
  select(colname)

# only in values
rds_name_in_val <- rds_data %>%
  select(name_in_val$colname)

binary_patterns <- c("^yes$", "^no$", "^none$", "^not reported$", "^0$", "^1$", "^unavailable$") %>%
  paste(collapse = "|")

rds_name_in_val <- rds_name_in_val %>%
  filter(!if_any(everything(), ~ grepl(binary_patterns, ., ignore.case = TRUE)))
    
combined_rds_name_in_val <- rds_name_in_val %>%
  unite(combined, 1:ncol(rds_name_in_val), sep = "//", na.rm = TRUE)

rds_name_in_val_table <- as.data.frame(table(combined_rds_name_in_val$combined))

nonNA_names <- combined_rds_name_in_val$combined[!is.na(combined_rds_name_in_val$combined)]

all_names <- strsplit(nonNA_names, split = "//") %>%
  unlist %>%
  unique

# only in names


# in both

## get relevant_col_data to separate groups
col_data_to_group <- read_sheet(ss, "relevant_col_data")

grouped_col_data <- col_data_to_group %>%
  group_by(name, type, amount, time, case, notes) %>%
  group_split()

names(grouped_col_data) <- c(paste0("group_", 1:length(grouped_col_data)))



for(i in 31:37) {
  sheet_write(as.data.frame(grouped_col_data[[i]]), ss = tt, sheet = names(grouped_col_data)[i])
}

# harmonization_mappings frame
harmonization_mappings <- data.frame(col_group = NA,
                                     colname = NA,
                                     condition = NA,
                                     treatment_name = NA,
                                     treatment_type = NA,
                                     treatment_amount = NA,
                                     treatment_time = NA,
                                     treatment_case = NA,
                                     treatment_notes = NA)
for (i in 1:length(grouped_col_data)) {
  current_group <- grouped_col_data[[i]]
  for (j in 1:nrow(current_group)) {
    current_colname <- current_group$colname[j]
    current_row <- c(i, current_colname, NA, NA, NA, NA, NA, NA, NA)
    harmonization_mappings <- rbind(harmonization_mappings, current_row)
  }
}
harmonization_mappings <- harmonization_mappings[-1,]
rownames(harmonization_mappings) <- NULL

sheet_write(harmonization_mappings, ss = tt, sheet = "harmonization_mappings")

##HARMONIZING########################################################

study_list <- readRDS("cBioPortal_all_clinicalData_2023-05-18.rds")

# list of relevant names
relevant_col_sheet <- read_sheet(ss, sheet = "relevant_col_data")
relevant_colnames <- relevant_col_sheet$colname

study_treat_cols <- list()
for(i in 1:length(study_list)){
  study_treat_cols[[i]] <- colnames(study_list[[i]])[colnames(study_list[[i]]) %in% relevant_colnames]
}
names(study_treat_cols) <- names(study_list)
study_treat_cols <- compact(study_treat_cols)

# get completed harmonization mappings and parsed column names

completed_harmonization_mappings <- read_sheet(tt, sheet = "harmonization_mappings")
parsed_colnames <- read_sheet(tt, sheet = "colname_parsing")

# testing: get a study to test
test_study <- study_list[["gbm_columbia_2019"]]


# get list of columns to harmonize (study_treat_cols)
relevant_colnames <- study_treat_cols[["gbm_columbia_2019"]]
relevant_columns <- test_study[,relevant_colnames]


# create base harmonization frame (will be used for each record)
test_harmonization_frame_columns <- c("colname",
                                      "colvalue",
                                      "condition_ind",
                                      "treatment_name",
                                      "treatment_type",
                                      "treatment_amount",
                                      "treatment_time",
                                      "treatment_case",
                                      "treatment_notes")

# function to return harmonized value based on map value
harmonized_value <- function(name, value, harmonized_type, parsed_value) {
  if (is.na(harmonized_type)) {
    return(NA)
  } else if (harmonized_type == "name") {
    return(parsed_value)
  } else if (harmonized_type == "value") {
    return(value)
  } else if (harmonized_type == "name + value") {
    return(paste(value, parsed_value, sep = "/&/"))
  } else {
    return("!!UNRECOGNIZED_MAPPING_VALUE!!")
  }
}

# loop through records and harmonize each row of the frame based on mappings
# in record: for each column save name and value
# retrieve mapping: for each curated column fill with specified value
# ^ handle name, value, and name+value


current_study <- list()
for (i in 1:nrow(relevant_columns)) { # loop through records
  print(paste0("retrieving record ", i))
  record <- relevant_columns[i,]
  current_record_frame <- data.frame(matrix(nrow = ncol(relevant_columns), ncol = 9, dimnames = list(NULL, test_harmonization_frame_columns)))
  for (j in 1:ncol(record)) { # loop through columns
    print(paste0("harmonizing column ", j))
    name <- colnames(record[j])
    print(name)
    value <- toString(record[j])
    print(value)
    mapping <- completed_harmonization_mappings[completed_harmonization_mappings$colname == name,]
    parsed_values <- parsed_colnames[parsed_colnames$colname == name,]
    current_record_frame$colname[j] <- name
    current_record_frame$colvalue[j] <- value
    current_record_frame$condition_ind[j] <- mapping$condition
    current_record_frame$treatment_name[j] <- harmonized_value(name, value, mapping$treatment_name, parsed_values$treatment_name)
    current_record_frame$treatment_type[j] <- harmonized_value(name, value, mapping$treatment_type, parsed_values$treatment_type)
    current_record_frame$treatment_amount[j] <- harmonized_value(name, value, mapping$treatment_amount, parsed_values$treatment_amount)
    current_record_frame$treatment_time[j] <- harmonized_value(name, value, mapping$treatment_time, parsed_values$treatment_time)
    current_record_frame$treatment_case[j] <- harmonized_value(name, value, mapping$treatment_case, parsed_values$treatment_case)
    current_record_frame$treatment_notes[j] <- harmonized_value(name, value, mapping$treatment_notes, parsed_values$treatment_notes)
  }
  
  current_study[[i]] <- current_record_frame
}

# get "no data" values
no_data_values_frame <- read_sheet(ss, sheet = "no_data_values")
no_data_values <- no_data_values_frame$Values

for (i in 1:length(no_data_values)) {
  no_data_values[i] <- paste0("^", no_data_values[i], "$")
}

no_data_search_term <- paste(no_data_values, collapse = "|")

# filter out "no data" values and save removed columns
filtered_study <- current_study
removed_cols <- list()
for (i in 1:length(current_study)) { # loop through records
  print(paste0("checking record ", i))
  record_frame <- current_study[[i]]
  removed_cols_frame <- data.frame(matrix(nrow = ncol(relevant_columns), ncol = 9, dimnames = list(NULL, test_harmonization_frame_columns)))
  for (j in 1:nrow(record_frame)) { # loop through columns
    print(paste0("checking column ", j))
    harmonized_column_data <- record_frame[j,]
    if (grepl(no_data_search_term, harmonized_column_data$colvalue, ignore.case = TRUE)) {
      filtered_study[[i]][j, c("treatment_name",
                                  "treatment_type",
                                  "treatment_amount",
                                  "treatment_time",
                                  "treatment_case",
                                  "treatment_notes")] <- NA
      removed_cols_frame[j,] <- harmonized_column_data
    }
  }
  removed_cols[[i]] <- removed_cols_frame
}

# search tool
condition <- !is.na(rds_data$TX_GSK923295A)
unique(rds_data$studyId[condition])
length(rds_data$studyId[condition])
check_table <- rds_data[condition, c("studyId", "patientId", "TELOMERE_MAINTENANCE")]

colnames(remove_empty(rds_data[rds_data$studyId %in% unique(rds_data$studyId[condition]),], which = "cols"))
