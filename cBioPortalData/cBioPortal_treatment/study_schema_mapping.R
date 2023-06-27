library(tidyverse)
library(googlesheets4)
library(utile.tools)

######################################################
# establish urls
# sheet = Potential Treatment Columns
url_1 <- ""
ss <- googledrive::as_id(url_1)

# sheet = Column Groups
url_2 <- ""
tt <- googledrive::as_id(url_2)

# sheet = Shared Treatment Curation Sheet
url_3 <- "https://docs.google.com/spreadsheets/d/1E6Xr1Aa8gxu6MgujOQ7kxarlZ7O8-Iy8XsCp7-0BHXY/edit#gid=1020044523"
uu <- googledrive::as_id(url_3)

# sheet = Study Schema Mapping
url_4 <- ""
vv <- googledrive::as_id(url_4)

# get list of studies
study_list <- readRDS("cBioPortal_all_clinicalData_2023-05-18.rds")

# get saved preliminary harmonization data
filtered_study_list <- readRDS("cBP_filtered_list_2023-06-14.rds")
harmonized_study_list <- readRDS("cBP_harmonized_list_2023-06-14.rds")
removed_column_list <- readRDS("cBP_removedcol_list_2023-06-14.rds")

# list of relevant names
relevant_col_sheet <- read_sheet(tt, sheet = "harmonization_mappings")
relevant_colnames <- relevant_col_sheet$colname
relevant_col_mappings <- relevant_col_sheet[, -c(1, 3)]

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
      unique_values <- append(unique_values, unlist(lapply(study[,j], function(x) paste(unique(na.omit(x)), collapse = "<;>"))))
    }
  }
  relevant_names <- unname(relevant_names)
  unique_values <- unname(unique_values)
  study_cols <- study[, relevant_names]
  study_treat_vals[[i]] <- data.frame(colname = relevant_names,
                                      unique_values = str_trunc(unique_values, 25000, "right"),
                                      study_completeness = colSums(!is.na(study_cols))/nrow(study_cols))
}
names(study_treat_vals) <- names(study_list)
study_treat_vals <- study_treat_vals[lengths(study_treat_vals) > 1]

# convert to frame
study_treat_frame <- bind_rows(study_treat_vals, .id = "study_id") %>%
  mutate(group_number = NA, .after = colname)
rownames(study_treat_frame) <- NULL

# write for manual group assignment
sheet_write(study_treat_frame, ss = vv, sheet = "study_col_groupings")

################ MAIN SECTION ###################
# merge mappings with unique values
last_study_name <- "blca_msk_tcga_2020"
current_study_number <- grep(last_study_name, names(study_treat_vals)) + 1
current_study_name <- names(study_treat_vals)[current_study_number]
current_study <- study_treat_vals[[current_study_number]][,-3]
rownames(current_study) <- NULL

current_reference_frame <- current_study %>%
  left_join(relevant_col_mappings, by = "colname") %>%
  mutate(column_id = 1:nrow(.), .before = colname) %>%
  mutate(group = NA, .before = colname) %>%
  mutate(link_map = NA, .before = colname) %>%
  mutate(match_col = NA, .before = colname) %>%
  mutate(split_pattern = NA, .before = colname)

sheet_write(current_reference_frame, ss = vv, sheet = current_study_name)
################################################


# harmonize from filtered_study_list and maps
current_study_number <- 3
current_study_name <- names(filtered_study_list)[current_study_number]
current_filtered_study <- filtered_study_list[[current_study_name]]
current_study_map <- read_sheet(vv, sheet = current_study_name)

current_record_number <- 2
current_record <- master_fstudy_list[[current_study_number]][[current_record_number]]

# split
split_record <- current_record %>%
  mutate(colvalue = strsplit(colvalue, split_pattern)) %>%
  unnest(colvalue)

# map groups based on condition



# get completed harmonization mappings and parsed column names
completed_harmonization_mappings <- read_sheet(vv, sheet = current_study_name)
parsed_colnames <- read_sheet(tt, sheet = "colname_parsing")

# set up blank harmonization frame and function
test_harmonization_frame_columns <- c("group",
                                      "link_id",
                                      "link_map",
                                      "split_pattern",
                                      "colname",
                                      "colvalue",
                                      "treatment_name",
                                      "treatment_type",
                                      "treatment_amount",
                                      "treatment_time",
                                      "treatment_case",
                                      "treatment_notes")

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

# set up values to filter for "no_data"
no_data_values_frame <- read_sheet(ss, sheet = "no_data_values")
no_data_values <- no_data_values_frame$Values

for (i in 1:length(no_data_values)) {
  no_data_values[i] <- paste0("^", no_data_values[i], "$")
}

no_data_search_term <- paste(no_data_values, collapse = "|")

# create master list of harmonized studies, filtered harmonized studies, and filtered columns
master_hstudy_list <- list()
master_fstudy_list <- list()
master_removedcol_list <- list()

# select just the current study
k <- current_study_number

# loop through studies, harmonize, and filter
#for (k in 1:length(study_treat_cols)) {
study_name <- names(study_treat_cols)[k]
h_study <- study_list[[study_name]]
relevant_colnames <- study_treat_cols[[k]]
relevant_columns <- h_study[,relevant_colnames]
id_col <- h_study$patientId

# loop through records in study
current_study <- list()
for (i in 1:nrow(relevant_columns)) { # loop through records
  record <- relevant_columns[i,]
  record_id <- id_col[i]
  current_record_frame <- data.frame(matrix(nrow = ncol(relevant_columns), ncol = 12, dimnames = list(NULL, test_harmonization_frame_columns)))
  for (j in 1:ncol(record)) { # loop through columns
    print(paste0("harmonizing: ", study_name, " (", k, ")", ", record ", i, ", column ", j))
    name <- colnames(record[j])
    #print(name)
    value <- toString(record[j])
    #print(value)
    mapping <- completed_harmonization_mappings[completed_harmonization_mappings$colname == name,]
    parsed_values <- parsed_colnames[parsed_colnames$colname == name,]
    current_record_frame$group[j] <- mapping$group
    current_record_frame$link_id[j] <- mapping$link_id
    current_record_frame$link_map[j] <- mapping$link_map
    current_record_frame$split_pattern[j] <- mapping$split_pattern
    current_record_frame$colname[j] <- name
    current_record_frame$colvalue[j] <- value
    current_record_frame$treatment_name[j] <- harmonized_value(name, value, mapping$treatment_name, parsed_values$treatment_name)
    current_record_frame$treatment_type[j] <- harmonized_value(name, value, mapping$treatment_type, parsed_values$treatment_type)
    current_record_frame$treatment_amount[j] <- harmonized_value(name, value, mapping$treatment_amount, parsed_values$treatment_amount)
    current_record_frame$treatment_time[j] <- harmonized_value(name, value, mapping$treatment_time, parsed_values$treatment_time)
    current_record_frame$treatment_case[j] <- harmonized_value(name, value, mapping$treatment_case, parsed_values$treatment_case)
    current_record_frame$treatment_notes[j] <- harmonized_value(name, value, mapping$treatment_notes, parsed_values$treatment_notes)
  }
  current_study[[i]] <- current_record_frame
  names(current_study)[i] <- record_id
}
master_hstudy_list[[k]] <- current_study
names(master_hstudy_list)[k] <- study_name

# filter out "no data" values and save removed columns
filtered_study <- current_study
removed_cols <- list()
for (i in 1:length(current_study)) { # loop through records
  record_id <- id_col[i]
  record_frame <- current_study[[i]]
  removed_cols_frame <- data.frame(matrix(nrow = ncol(relevant_columns), ncol = 12, dimnames = list(NULL, test_harmonization_frame_columns)))
  for (j in 1:nrow(record_frame)) { # loop through columns
    print(paste0("filtering: ", study_name, " (", k, ")", ", record ", i, ", column ", j))
    harmonized_column_data <- record_frame[j,]
    if (grepl(no_data_search_term, harmonized_column_data$colvalue, ignore.case = TRUE)) {
      filtered_study[[i]] <- filtered_study[[i]][-j,]
      #filtered_study[[i]][j, c("treatment_name",
       #                        "treatment_type",
        #                       "treatment_amount",
         #                      "treatment_time",
          #                     "treatment_case",
           #                    "treatment_notes")] <- NA
      removed_cols_frame[j,] <- harmonized_column_data
    }
  }
  removed_cols[[i]] <- removed_cols_frame
  names(filtered_study)[i] <- record_id
  names(removed_cols)[i] <- record_id
}
master_fstudy_list[[k]] <- filtered_study
master_removedcol_list[[k]] <- removed_cols
names(master_fstudy_list)[k] <- study_name
names(master_removedcol_list)[k] <- study_name
#}



