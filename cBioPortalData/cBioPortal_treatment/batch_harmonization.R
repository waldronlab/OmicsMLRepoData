library(tidyverse)
library(googlesheets4)
library(googledrive)
library(readxl)
library(utile.tools)

# Load list of harmonized studies
new_harmonized_studies <- readRDS("cBP_new_harmonized_studies_2023-05-18.rds")

# Save harmonized study to list of harmonized studies and backup
#new_harmonized_studies[[current_study_number]] <- harmonized_study
#names(new_harmonized_studies)[current_study_number] <- study_name
saveRDS(new_harmonized_studies, file = "cBP_new_harmonized_studies_2023-05-18.rds")

# Note: ~30 seconds/100 records

# establish urls
# sheet = Potential Treatment Columns
url_1 <- "https://docs.google.com/spreadsheets/d/1WoqAH3GUA4BCVC6KAZJaqrZZi9f0U9xpWEpqTdl4Y0c/edit#gid=0"
ss <- as_id(url_1)

# sheet = Column Groups
url_2 <- "https://docs.google.com/spreadsheets/d/1Yi6wgSAJXwsaTzSVZpSenjtgn7-U1Qb_c48RsZC62eY/edit#gid=0"
tt <- as_id(url_2)

# sheet = Shared Treatment Curation Sheet
url_3 <- "https://docs.google.com/spreadsheets/d/1E6Xr1Aa8gxu6MgujOQ7kxarlZ7O8-Iy8XsCp7-0BHXY/edit#gid=1020044523"
uu <- as_id(url_3)

# sheet = Study Schema Mapping
url_4 <- "https://docs.google.com/spreadsheets/d/1zrBTatxxJXjg1HWoSmGR08weAYgg6HlDNWn_SOmoZF8/edit#gid=1181529872"
vv <- as_id(url_4)


# get list of studies
study_list <- readRDS("cBioPortal_all_clinicalData_2023-05-18.rds")

# get harmonization maps
map_sheet <- drive_get(id = vv)
map_sheet_file <- drive_download(map_sheet, type = "xlsx", overwrite = TRUE)
map_sheet_path <- paste0(map_sheet$name, ".xlsx")

# list of relevant names
relevant_col_sheet <- read_sheet(tt, sheet = "harmonization_mappings")
relevant_colnames <- relevant_col_sheet$colname
relevant_col_mappings <- relevant_col_sheet[, -c(1, 3)]

# get relevant studies
study_treat_cols <- list()
for(i in 1:length(study_list)){
  study_treat_cols[[i]] <- colnames(study_list[[i]])[colnames(study_list[[i]]) %in% relevant_colnames]
}
names(study_treat_cols) <- names(study_list)
study_treat_cols <- compact(study_treat_cols)

# Separate "no_data" values into different ontology definitions and get negative columns
no_data_values_frame <- read_sheet(ss, sheet = "no_data_values")
no_vals <- na.omit(no_data_values_frame$No)
na_vals <- na.omit(no_data_values_frame$Not_Applicable)
nc_vals <- na.omit(no_data_values_frame$Not_Collected)
np_vals <- na.omit(no_data_values_frame$Not_Provided)
negative_cols <- na.omit(no_data_values_frame$Negative_Columns)
ymn_vals <- na.omit(no_data_values_frame$yes_means_no)

for (i in 1:length(no_vals)) {
  no_vals[i] <- paste0("^", no_vals[i], "$")
}
no_vals_search_term <- paste(no_vals, collapse = "|")

for (i in 1:length(na_vals)) {
  na_vals[i] <- paste0("^", na_vals[i], "$")
}
na_vals_search_term <- paste(na_vals, collapse = "|")

for (i in 1:length(nc_vals)) {
  nc_vals[i] <- paste0("^", nc_vals[i], "$")
}
nc_vals_search_term <- paste(nc_vals, collapse = "|")

for (i in 1:length(np_vals)) {
  np_vals[i] <- paste0("^", np_vals[i], "$")
}
np_vals_search_term <- paste(np_vals, collapse = "|")

for (i in 1:length(ymn_vals)) {
  ymn_vals[i] <- paste0("^", ymn_vals[i], "$")
}
ymn_vals_search_term <- paste(ymn_vals, collapse = "|")

# function to return correct value based on map
harmonized_value <- function(value, harmonized_type) {
  if (is.na(harmonized_type)) {
    return(NA)
  } else if (harmonized_type == "value") {
    return(value)
  } else if (startsWith(harmonized_type, "value + ")) {
    return(str_replace(harmonized_type, "value \\+ ", value))
  } else if (endsWith(harmonized_type, " + value")) {
    return(str_replace(harmonized_type, " \\+ value", value))
  } else {
    return(harmonized_type)
  }
}

##### Set up batch #########################################################

# vector of study names to harmonize
batch_names <- names(study_treat_cols)[c(95, 98)] # aml - 7/199, other 56; c(1:4, 6, 8:10, 12, 56); cesc - 20; long 95/98

# list to save harmonized studies
new_harmonized_studies <- list()

# save stats
elapsed_times <- c()
rates <- c()
batch_start_time <- Sys.time()

# save errors
all_errors <- c()

for (g in 1:length(batch_names)) {
  tryCatch({
    ####### Loop through batch list ################
    # 0. Select study and load map
    step <- 0
    start_time <- Sys.time()
    
    study_name <- batch_names[g]
    current_study_number <- grep(paste0("^", study_name, "$"), names(study_treat_cols))
    
    # get completed harmonization mappings and parsed column names
      completed_harmonization_mappings <- try(read_excel(map_sheet_path, sheet = study_name))
      if ("try-error" %in% class(completed_harmonization_mappings)) {
        print("Error in .xlsx file, pulling from Google Sheet")
        completed_harmonization_mappings <- read_sheet(vv, sheet = study_name)
      }
    #completed_harmonization_mappings <- read_sheet(vv, sheet = study_name)
    #parsed_colnames <- read_sheet(tt, sheet = "colname_parsing")
    
    # 1. Get template study map and save relevant column names
    step <- 1
    original_harmonization_map <- completed_harmonization_mappings %>%
      select(-unique_values) %>%
      mutate(colvalue = NA, .after = colname) %>%
      rename(link_id = column_id) %>%
      mutate(match_id = link_id, .after = link_id)
    
    # 2. Get study from study_list and set up final frame
    step <- 2
    current_study_data <- study_list[[study_name]]
    harmonized_study <- data.frame(matrix(nrow = nrow(current_study_data),
                                          ncol = 12,
                                          dimnames = list(c(),
                                                          c("patientId",
                                                            "sampleId",
                                                            "treatment_name",
                                                            "treatment_type",
                                                            "treatment_amount",
                                                            "treatment_time",
                                                            "treatment_case",
                                                            "treatment_notes",
                                                            "treatment_no",
                                                            "treatment_not_applicable",
                                                            "treatment_not_collected",
                                                            "treatment_not_provided"))))
    
    ######## Loop through current study ####################################
    
    for (h in 1:nrow(current_study_data)) { # loop through records
      print(paste0(study_name, " (study ", g, " of ", length(batch_names), "): ", nrow(original_harmonization_map), " column(s), record ", h, "/", nrow(current_study_data)))
      harmonization_map <- original_harmonization_map
      original_record <- current_study_data[h,]
      patient_ID <- original_record$patientId
      sample_ID <- original_record$sampleId
      
      # 3. For each row in map, populate column value
      step <- 3
      for (i in 1:nrow(harmonization_map)) {
        harmonization_map$colvalue[i] <- original_record[1, harmonization_map$colname[i]]
      }
      harmonization_map$colvalue <- as.character(harmonization_map$colvalue)
      
      # 4. Split any columns with multiple values and save split order when relevant
      step <- 4
      harmonization_map <- harmonization_map %>%
        mutate(colvalue = strsplit(as.character(colvalue), split_pattern, perl = TRUE)) %>%
        mutate(colvalue = map(colvalue, ~ data.frame(colvalue = .x, split_index = seq_along(.x)))) %>%
        unnest(colvalue) %>%
        relocate(split_index, .after = split_pattern) %>%
        mutate(colvalue = str_trim(colvalue))
      
      harmonization_map$split_index[is.na(harmonization_map$split_pattern)] <- NA
      
      harmonization_map <- harmonization_map %>%
        mutate(split_order = case_when(!is.na(group) & !is.na(split_index) ~split_index), .after = split_index)
      
      # 5. Filter out any columns with no/NA values and save name--value values for later storage
      step <- 5
      no_names_values <- c()
      na_names_values <- c()
      nc_names_values <- c()
      np_names_values <- c()
      for (i in 1:nrow(harmonization_map)) {
        if (harmonization_map$colname[i] %in% negative_cols) {
          definitive_vals_search_term <- ymn_vals_search_term
          if (grepl(definitive_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE)) {
            saved_name <- paste0(harmonization_map$colname[i], "-", harmonization_map$colvalue[i])
          } else {
            saved_name <- harmonization_map$colname[i]
          }
        } else {
          definitive_vals_search_term <- no_vals_search_term
          saved_name <- harmonization_map$colname[i]
        }
        #print(i)
        #print(harmonization_map$colvalue[i])
        #print(grepl(no_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE))
        #print(grepl(na_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE))
        #print(grepl(nc_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE))
        #print(grepl(np_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE))
        #print(is.na(harmonization_map$colvalue[i]))
        #print(is.null(harmonization_map$colvalue[i]))
        if (grepl(definitive_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE)) {
          #print("definitive")
          no_names_values <- c(no_names_values, saved_name)
          harmonization_map[i, ] <- NA
        } else if (grepl(na_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE) | is.na(harmonization_map$colvalue[i]) | is.null(harmonization_map$colvalue[i])) {
          #print("na")
          na_names_values <- c(na_names_values, saved_name)
          harmonization_map[i, ] <- NA
        } else if (grepl(nc_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE)) {
          #print("nc")
          nc_names_values <- c(nc_names_values, saved_name)
          harmonization_map[i, ] <- NA
        } else if (grepl(np_vals_search_term, harmonization_map$colvalue[i], ignore.case = TRUE)) {
          #print("np")
          np_names_values <- c(np_names_values, saved_name)
          harmonization_map[i, ] <- NA
        }
      }
      no_names_values <- paste(no_names_values, collapse = "<;>")
      na_names_values <- paste(na_names_values, collapse = "<;>")
      nc_names_values <- paste(nc_names_values, collapse = "<;>")
      np_names_values <- paste(np_names_values, collapse = "<;>")
      harmonization_map <- harmonization_map[rowSums(is.na(harmonization_map)) != ncol(harmonization_map),]
      if (nrow(harmonization_map) == 0) {
        harmonized_row <- c(patient_ID, sample_ID, NA, NA, NA, NA, NA, NA, no_names_values, na_names_values, nc_names_values, np_names_values)
        harmonized_study[h,] <- harmonized_row
        next
      }
      
      # 6. Use parsed column names and map names/values to treatment_ columns
      step <- 6
      for (i in 1:nrow(harmonization_map)) {
        current_row <- harmonization_map[i,]
        #name <- current_row$colname
        value <- current_row$colvalue
        #parsed_values <- parsed_colnames[parsed_colnames$colname == name,]
        harmonization_map$treatment_name[i] <- harmonized_value(value, current_row$treatment_name)
        harmonization_map$treatment_type[i] <- harmonized_value(value, current_row$treatment_type)
        harmonization_map$treatment_amount[i] <- harmonized_value(value, current_row$treatment_amount)
        harmonization_map$treatment_time[i] <- harmonized_value(value, current_row$treatment_time)
        harmonization_map$treatment_case[i] <- harmonized_value(value, current_row$treatment_case)
        harmonization_map$treatment_notes[i] <- harmonized_value(value, current_row$treatment_notes)
      }
      
      harmonization_map[harmonization_map == "yes" | harmonization_map == "YES" | harmonization_map == "Yes"] <- NA
      
      # 7. For each row with a condition, set its link_id to its target link_id and save in merge_links
      step <- 7
      harmonization_map <- harmonization_map %>%
        mutate(match_marker = NA, .after = match_id)
      match_marker_counter <- 1
      
      merge_links <- c()
      for (i in 1:nrow(harmonization_map)) { # loop through rows
        current_row <- harmonization_map[i,]
        link_map <- current_row$link_map
        if (!is.na(link_map)) { # if there is a link map
          named_vector <- eval(parse(text = link_map))
          value <- current_row$colvalue
          for (j in 1:length(named_vector)) { # loop through values that map to links
            #print(j)
            #print(grepl(names(named_vector)[j], value, ignore.case = TRUE))
            if (grepl(names(named_vector)[j], value, ignore.case = TRUE)) { # if the current mapping value is found in the actual column value
              #target <- unname(named_vector[grep(names(named_vector)[j], value, ignore.case = TRUE)])
              target <- unname(named_vector[j])
              #print(target)
              #target <- unname(named_vector[value])
              harmonization_map$link_id[i] <- target
              #harmonization_map$split_index <- NA
              #merge_links <- unique(c(merge_links, target))
            }
          }
        }
      }
      
      # for matches
      for (i in 1:nrow(harmonization_map)) { # loop through rows
        current_row <- harmonization_map[i,]
        match_col <- current_row$match_col
        #print(match_col)
        if (!is.na(match_col)) { # if there is a column to test matching
          value <- current_row$colvalue
          #print(value)
          test_col_values <- harmonization_map$colvalue[harmonization_map$match_id == match_col]
          #print(test_col_values)
          if (length(test_col_values) > 0) {
            for (j in 1:length(test_col_values)) {
              if(!is.na(value) & !is.na(test_col_values[j])) {
                if (value == test_col_values[j]) { # if the values match
                  #print(value == test_col_values[j])
                  #print(harmonization_map[i,])
                  matched_row <- harmonization_map[(harmonization_map$match_id == match_col) & (harmonization_map$colvalue == test_col_values[j]),]
                  final_id <- matched_row$link_id
                  final_match_marker <- matched_row$match_marker
                  if (is.na(final_match_marker)) {
                    harmonization_map$match_marker[(harmonization_map$match_id == match_col) & (harmonization_map$colvalue == test_col_values[j])] <- match_marker_counter
                    harmonization_map$match_marker[i] <- match_marker_counter
                    match_marker_counter <- match_marker_counter + 1
                  } else {
                    harmonization_map$match_marker[i] <- final_match_marker
                  }
                  harmonization_map$link_id[i] <- final_id
                  #harmonization_map$split_index[i] <- NA
                  #print(harmonization_map[i,])
                  merge_links <- unique(c(merge_links, final_id))
                }   
              }
            } 
          }
        }
      }
      
      # follow up with link_maps with changed single match_col parents
      # note: it is assumed that the link_map has no children and the parent does not circularly reference the link_map. This is specified in the documentation.
      for (i in 1:nrow(harmonization_map)) {
        current_row <- harmonization_map[i,]
        if ((!is.na(current_row$link_map)) & (current_row$match_id != current_row$link_id)) {
          link_to_follow <- current_row$link_id
          if (link_to_follow %in% harmonization_map$match_id) {
            parent_to_follow <- harmonization_map[harmonization_map$match_id == link_to_follow,]
            if(nrow(parent_to_follow) == 1) {
              if (parent_to_follow$match_id != parent_to_follow$link_id) {
                harmonization_map$link_id[i] <- parent_to_follow$link_id
              } 
            }
          }
          merge_links <- unique(c(merge_links, harmonization_map$link_id[i]))
        }
      }
      
      # 8. Collapse frame by link_id AND SPLIT_INDEX (prevents multiple split_index values when merging groups)
      step <- 8
      rows_without_links <- harmonization_map %>%
        filter(!link_id %in% merge_links)
      
      if (length(merge_links) > 0) {
        for (i in 1:length(merge_links)) {
          current_link <- merge_links[i]
          
          #### ALSO TESTING ####
          group_rows <- harmonization_map %>%
            filter(link_id == current_link)
          
          #### TESTING ####
          group_rows <- group_rows %>%
            mutate(old_split_index = split_index, .after = split_index)
          
          original_col_ids <- unlist(strsplit(as.character(group_rows$match_id), split = "::"))
          id_freq <- as.data.frame(table(original_col_ids))
          
          duplicate_ids <- as.character(id_freq$original_col_ids[id_freq$Freq > 1])
          
          if(length(duplicate_ids) > 0) {
            for (i in 1:length(duplicate_ids)) {
              duplicate_ids[i] <- paste0("(^|:)", duplicate_ids[i], "($|:)")
            }
            duplicate_ids <- paste(duplicate_ids, collapse = "|")
            group_rows <- group_rows %>%
              mutate(split_index = case_when(grepl(duplicate_ids, match_id) ~split_index,
                                             !grepl(duplicate_ids, match_id) ~NA))
            
          } else {
            group_rows$split_index <- NA
          }
          #### TESTING ####
          
          #print(paste0("current link: ", current_link))
          merge_split_indices <- unique(filter(group_rows, !is.na(split_index))$split_index)
          if (length(merge_split_indices) == 0) {
            #print("0 unique non-NA indices")
            merged_rows <- group_rows %>%
              filter(link_id == current_link) %>%
              group_by(link_id) %>%
              summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
              mutate(split_index = old_split_index) %>%
              select(-old_split_index)
            #print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_links"))
            #print(paste0("rows_without_links rows before rbind: ", nrow(rows_without_links)))
            rows_without_links <- rbind(rows_without_links, merged_rows)
            #print(paste0("rows_without_links rows after rbind: ", nrow(rows_without_links)))
          } else {
            #print("some unique non-NA indices found")
            for (j in 1:length(merge_split_indices)) {
              current_index <- merge_split_indices[j]
              #print(paste0("current index: ", current_index))
              merged_rows <- group_rows %>%
                filter((split_index == current_index)|(is.na(split_index)))
              if (any(is.na(merged_rows$match_marker)) & any(!is.na(merged_rows$match_marker))) {
                merged_rows <- merged_rows %>%
                  filter(is.na(match_marker))
              }
              merged_rows <- merged_rows %>%
                #group_by(link_id) %>%
                summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
                mutate(split_index = old_split_index) %>%
                select(-old_split_index)
              #print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_links"))
              #print(paste0("rows_without_links rows before rbind: ", nrow(rows_without_links)))
              rows_without_links <- rbind(rows_without_links, merged_rows)
              #print(paste0("rows_without_links rows after rbind: ", nrow(rows_without_links)))
            }
          }
        }
      }
      
      harmonization_map <- rows_without_links
      harmonization_map[harmonization_map == ""] <- NA
      
      # 9. Collapse frame by group and split_index
      step <- 9
      #harmonization_map <- harmonization_map %>%
      #  mutate(row_index = rownames(harmonization_map), .before = group)
      
      #row_indices <- harmonization_map$row_index
      
      rows_without_groups <- harmonization_map %>%
        filter(is.na(group))
      
      rows_to_group <- harmonization_map %>%
        filter(!is.na(group)) %>%
        mutate(group = as.character(group)) %>%
        mutate(group = strsplit(group, split = "::")) %>%
        mutate(current_bool = NA, .before = group)
      
      if (nrow(rows_to_group) > 0) {
        
        merge_groups <- unique(unlist(rows_to_group$group))
        merge_groups <- merge_groups[!is.na(merge_groups)]
        
        for (i in 1:length(merge_groups)) {
          current_group <- merge_groups[i]
          #print(paste0("current group: ", current_group))
          for (j in 1:length(rows_to_group$group)) {
            #print(current_group)
            #print(rows_to_group$group[[j]])
            #print(current_group %in% rows_to_group$group[[j]])
            rows_to_group$current_bool[j] <- current_group %in% rows_to_group$group[[j]]
          }
          group_rows <- filter(rows_to_group, current_bool == TRUE) %>%
            rowwise() %>%
            mutate(group = list(paste(group, collapse = "::"))) %>%
            ungroup()
          
          #### TESTING ####
          group_rows <- group_rows %>%
            mutate(old_split_index = split_index, .after = split_index)
          
          original_col_ids <- unlist(strsplit(as.character(group_rows$match_id), split = "::"))
          id_freq <- as.data.frame(table(original_col_ids))
          
          duplicate_ids <- as.character(id_freq$original_col_ids[id_freq$Freq > 1])
          
          if(length(duplicate_ids) > 0) {
            for (i in 1:length(duplicate_ids)) {
              duplicate_ids[i] <- paste0("(^|:)", duplicate_ids[i], "($|:)")
            }
            duplicate_ids <- paste(duplicate_ids, collapse = "|")
            group_rows <- group_rows %>%
              mutate(split_index = case_when(grepl(duplicate_ids, match_id) ~split_index,
                                             !grepl(duplicate_ids, match_id) ~NA))
          } else {
            group_rows$split_index <- NA
          }
          
          group_rows <- group_rows %>%
            mutate(split_index = case_when(!is.na(split_order) ~split_order))
          
          #### TESTING ####
          
          merge_split_indices <- unique(filter(group_rows, current_bool == TRUE & !is.na(split_index))$split_index)
          #print(paste0("unique indices: ", paste(merge_split_indices, collapse = "::")))
          if (length(merge_split_indices) == 0) {
            #print("0 unique non-NA indices")
            merged_rows <- group_rows %>%
              #filter(!is.na(group) & current_group %in% group) %>%
              #group_by(group) %>%
              summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
              mutate(split_index = old_split_index) %>%
              select(-current_bool, -old_split_index)
            #print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_groups"))
            #print(paste0("rows_without_groups rows before rbind: ", nrow(rows_without_groups)))
            rows_without_groups <- rbind(rows_without_groups, merged_rows)
            #print(paste0("rows_without_groups rows after rbind: ", nrow(rows_without_groups)))
          } else {
            #print("some unique non-NA indices found")
            for (j in 1:length(merge_split_indices)) {
              current_index <- merge_split_indices[j]
              #print(paste0("current index: ", current_index))
              merged_rows <- group_rows %>%
                #filter(!is.na(group) & current_group %in% group) %>%
                filter((split_index == current_index)|(is.na(split_index))) %>%
                #group_by(group) %>%
                summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
                mutate(split_index = old_split_index) %>%
                select(-current_bool, -old_split_index)
              #print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_groups"))
              #print(paste0("rows_without_groups rows before rbind: ", nrow(rows_without_groups)))
              rows_without_groups <- rbind(rows_without_groups, merged_rows)
              #print(paste0("rows_without_groups rows after rbind: ", nrow(rows_without_groups)))
            }
          }
        }
      }
      
      harmonization_map <- rows_without_groups
      harmonization_map[harmonization_map == ""] <- NA
      harmonization_map <- harmonization_map %>%
        rowwise() %>%
        mutate(across(everything(), ~paste(sort(unique(unlist(strsplit(as.character(.), split = "::")))), collapse = "::"))) %>%
        ungroup()
      harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
      
      #new_rows_without_groups <- harmonization_map %>%
      #  filter(is.na(group))
      
      #new_rows_to_group <- harmonization_map %>%
      #  filter(!is.na(group)) %>%
      #  summarise(across(everything(), ~paste(na.omit(.), collapse = "::")), .by = c(group, split_index))
      
      #harmonization_map <- rbind(new_rows_without_groups, new_rows_to_group)
      #harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
      
      # 10. Combine rows with the same values
      step <- 10
      harmonization_map <- harmonization_map %>%
        select(treatment_name:treatment_notes) %>%
        rowwise() %>%
        mutate(across(everything(), ~paste(unique(unlist(strsplit(as.character(.), split = "::"))), collapse = "::")))
      
      harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
      
      # value merging
      #original_map <- harmonization_map
      #for (i in 1:nrow(harmonization_map)) {
      #  #print(paste0("row ", i))
      #  potential_merges <- data.frame(matrix(nrow = ncol(harmonization_map), ncol = 2, dimnames = list(colnames(harmonization_map), c("exists", "cellwise_merges"))))
      #  for (j in 1:ncol(harmonization_map)) {
      #    #print(paste0("column ", j))
      #    current_cell <- unlist(strsplit(as.character(harmonization_map[i,j]), split = "::"))
      #    #print(current_cell)
      #    if(!is.na(harmonization_map[i,j])) {
      #      #print(!is.na(harmonization_map[i,j]))
      #      potential_merges$exists[j] <- TRUE
      #      cellwise_merges <- c()
      #      for (k in 1:nrow(harmonization_map)) {
      #        if (k != i) {
      #          #print(paste0("testing against row ", k))
      #          test_cell <- unlist(strsplit(as.character(harmonization_map[k, j]), split = "::"))
      #          #print(test_cell)
      #          #print(intersect(current_cell, test_cell))
      #          #print(length(intersect(current_cell, test_cell)))
      #          if (length(intersect(current_cell, test_cell)) > 0) {
      #            cellwise_merges <- c(cellwise_merges, k)
      #            #print(paste0("cellwise_merges: ", cellwise_merges))
      #          }
      #        }
      #      } 
      #      if(length(cellwise_merges) > 0) {
      #        potential_merges$cellwise_merges[j] <- list(cellwise_merges)
      #      } else {
      #        potential_merges$cellwise_merges[j] <- list(c(0))
      #      }
      #    } else {
      #      potential_merges$exists[j] <- FALSE
      #    }
      #  }
      #  if (!all(is.na(potential_merges$cellwise_merges))) {
      #    merged_rows <- list()
      #    final_merges_frame <- potential_merges %>%
      #      filter(exists == TRUE)
      #    final_merges <- Reduce(intersect, final_merges_frame$cellwise_merges)
      #    if (length(final_merges) > 0) {
      #      for (l in 1:length(final_merges)) {
      #        current_fmerge <- final_merges[l]
      #        merged_row <- as.data.frame(harmonization_map) %>%
      #          slice(c(i, current_fmerge)) %>%
      #          summarise(across(everything(), ~paste(na.omit(.), collapse = "::")))
      #        merged_rows[[l]] <- merged_row
      #      }
      #      harmonization_map <- as.data.frame(harmonization_map) %>%
      #        slice(-c(i, final_merges)) %>%
      #        bind_rows(merged_rows)
      #    }
      #  }
      #}
      
      #harmonization_map <- harmonization_map %>%
      #  rowwise() %>%
      #  mutate(across(everything(), ~paste(unique(unlist(strsplit(., split = "::"))), collapse = "::")))
      
      #harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
      
      # 11. Collapse entire frame into <;> delimited row, fill no/na/nc/np columns, and add to harmonized_study
      step <- 11
      harmonization_map[is.na(harmonization_map)] <- "NA"
      harmonized_row <- harmonization_map %>%
        ungroup() %>%
        summarise(across(everything(), ~paste(., collapse = "<;>"))) %>%
        mutate(patientId = patient_ID, .before = treatment_name) %>%
        mutate(sampleId = sample_ID, .before = treatment_name) %>%
        mutate(treatment_no_values = no_names_values) %>%
        mutate(treatment_na_values = na_names_values) %>%
        mutate(treatment_nc_values = nc_names_values) %>%
        mutate(treatment_np_values = np_names_values)
      
      harmonized_study[h,] <- harmonized_row
    }
    
    harmonized_study[harmonized_study == ""] <- NA
    
    # 12. Add "source_columns" column for all records in frame
    step <- 12
    harmonized_study <- harmonized_study %>%
      mutate(treatment_source = paste(original_harmonization_map$colname, collapse = ";"))
    
    # 13. Save harmonized study
    step <- 13
    new_harmonized_studies[[current_study_number]] <- harmonized_study
    names(new_harmonized_studies)[current_study_number] <- study_name
    
    elapsed_time <- difftime(Sys.time(), start_time, units = "secs")
    elapsed_times <- c(elapsed_times, elapsed_time)
    print(paste0("elapsed time: ", elapsed_time, " ", attributes(elapsed_time)$units))
    time_per_100_records <- elapsed_time / nrow(current_study_data) * 100
    rates <- c(rates, time_per_100_records)
    print(paste0("time/100 records: ", time_per_100_records, " ", attributes(time_per_100_records)$units)) 
  }, error = function(e) {
    error_message <- paste0("\nError in ", study_name, " (", current_study_number, ")",
                            ", record ", h,
                            ", step ", step, ":\n",
                            "g = ", g, "\n",
                            "h = ", h, "\n",
                            "i = ", i, "\n",
                            "j = ", j, "\n",
                            "k = ", k, "\n",
                            "l = ", l, "\n",
                            e, "\n")
    all_errors <<- c(all_errors, error_message)
    print("ERROR: proceeding to next study")
  })
}

batch_total_time <- Sys.time() - batch_start_time
cat(paste0("Batch Stats:\n",
           "total batch time: ", batch_total_time, " ", attributes(batch_total_time)$units, "\n",
           "average elapsed time: ", mean(elapsed_times), " secs\n",
           "average time/100 records: ", mean(rates), " secs\n",
           "longest time for single study: ", max(elapsed_times), " secs, ", batch_names[which.max(elapsed_times)], "\n",
           "shortest time for single study: ", min(elapsed_times), " secs, ", batch_names[which.min(elapsed_times)], "\n",
           "fastest study rate: ", min(rates), ", ", batch_names[which.min(rates)], " secs/100 records\n",
           "slowest study rate: ", max(rates), ", ", batch_names[which.max(rates)], " secs/100 records\n"),
    all_errors)

library(beepr)
beep("facebook")


