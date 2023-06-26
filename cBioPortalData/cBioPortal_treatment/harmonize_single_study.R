library(tidyverse)
library(googlesheets4)
library(utile.tools)

# Note: ~1 min/100 records

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

# choose study
study_name <- "acc_tcga"

# get completed harmonization mappings and parsed column names
completed_harmonization_mappings <- read_sheet(vv, sheet = study_name)
parsed_colnames <- read_sheet(tt, sheet = "colname_parsing")

# get list of studies
study_list <- readRDS("cBioPortal_all_clinicalData_2023-05-18.rds")

# set up values to filter for "no_data"
no_data_values_frame <- read_sheet(ss, sheet = "no_data_values")
no_data_values <- no_data_values_frame$Values

for (i in 1:length(no_data_values)) {
  no_data_values[i] <- paste0("^", no_data_values[i], "$")
}

no_data_search_term <- paste(no_data_values, collapse = "|")

# function to return correct value based on map
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

####### ABOVE IS GENERAL SETUP: BELOW TAKES SINGLE STUDY ################

# 1. Get template study map
original_harmonization_map <- completed_harmonization_mappings %>%
  select(-unique_values) %>%
  mutate(colvalue = NA, .after = colname) %>%
  rename(link_id = column_id) %>%
  mutate(match_id = link_id, .after = link_id)

# 2. Get study from study_list and set up final frame
current_study_data <- study_list[[study_name]]
harmonized_study <- data.frame(matrix(nrow = nrow(current_study_data),
                                      ncol = 7,
                                      dimnames = list(c(),
                                                      c("patientId",
                                                        "treatment_name",
                                                        "treatment_type",
                                                        "treatment_amount",
                                                        "treatment_time",
                                                        "treatment_case",
                                                        "treatment_notes"))))

######## THE REST IS A LOOP ####################################

for (h in 1:nrow(current_study_data)) { # loop through records
  print(paste0("##################################### Harmonizing Record ", h, " #####################################"))
  harmonization_map <- original_harmonization_map
  original_record <- current_study_data[h,]
  patient_ID <- original_record$patientId
  
  # 3. For each row in map, populate column value
  for (i in 1:nrow(harmonization_map)) {
    harmonization_map$colvalue[i] <- original_record[1, harmonization_map$colname[i]]
  }
  harmonization_map$colvalue <- as.character(harmonization_map$colvalue)
  
  # 4. Filter out any columns with "no_data" values
  for (i in 1:nrow(harmonization_map)) {
    print(i)
    print(harmonization_map$colvalue[i])
    print(grepl(no_data_search_term, harmonization_map$colvalue[i], ignore.case = TRUE))
    print(is.na(harmonization_map$colvalue[i]))
    print(is.null(harmonization_map$colvalue[i]))
    if (grepl(no_data_search_term, harmonization_map$colvalue[i], ignore.case = TRUE) | is.na(harmonization_map$colvalue[i]) | is.null(harmonization_map$colvalue[i])) {
      #harmonization_map <- harmonization_map[-i,]
      harmonization_map[i,] <- NA
      print(nrow(harmonization_map))
    }
  }
  harmonization_map <- harmonization_map[rowSums(is.na(harmonization_map)) != ncol(harmonization_map),]
  if (nrow(harmonization_map) == 0) {
    harmonized_row <- c(patient_ID, NA, NA, NA, NA, NA, NA)
    harmonized_study[h,] <- harmonized_row
    next
  }
  
  # 5. Split any columns with multiple values
  harmonization_map <- harmonization_map %>%
    mutate(colvalue = strsplit(as.character(colvalue), split_pattern)) %>%
    mutate(colvalue = map(colvalue, ~ data.frame(colvalue = .x, split_index = seq_along(.x)))) %>%
    unnest(colvalue) %>%
    relocate(split_index, .after = split_pattern) %>%
    mutate(colvalue = str_trim(colvalue))
  
  harmonization_map$split_index[is.na(harmonization_map$split_pattern)] <- NA
  
  # 6. Use parsed column names and map names/values to treatment_ columns
  for (i in 1:nrow(harmonization_map)) {
    current_row <- harmonization_map[i,]
    name <- current_row$colname
    value <- current_row$colvalue
    parsed_values <- parsed_colnames[parsed_colnames$colname == name,]
    harmonization_map$treatment_name[i] <- harmonized_value(name, value, current_row$treatment_name, parsed_values$treatment_name)
    harmonization_map$treatment_type[i] <- harmonized_value(name, value, current_row$treatment_type, parsed_values$treatment_type)
    harmonization_map$treatment_amount[i] <- harmonized_value(name, value, current_row$treatment_amount, parsed_values$treatment_amount)
    harmonization_map$treatment_time[i] <- harmonized_value(name, value, current_row$treatment_time, parsed_values$treatment_time)
    harmonization_map$treatment_case[i] <- harmonized_value(name, value, current_row$treatment_case, parsed_values$treatment_case)
    harmonization_map$treatment_notes[i] <- harmonized_value(name, value, current_row$treatment_notes, parsed_values$treatment_notes)
  }
  
  # 7. For each row with a condition, set its link_id to its target link_id and save in merge_links
  
  merge_links <- c()
  for (i in 1:nrow(harmonization_map)) { # loop through rows
    current_row <- harmonization_map[i,]
    link_map <- current_row$link_map
    if (!is.na(link_map)) { # if there is a link map
      named_vector <- eval(parse(text = link_map))
      value <- current_row$colvalue
      for (j in 1:length(named_vector)) { # loop through values that map to links
        if (grepl(names(named_vector)[j], value, ignore.case = TRUE)) { # if the current mapping value is found in the actual column value
          target <- unname(named_vector[grep(names(named_vector)[j], value, ignore.case = TRUE)])
          #target <- unname(named_vector[value])
          harmonization_map$link_id[i] <- target
          merge_links <- unique(c(merge_links, target))
        }
      }
    }
  }
  
  # for matches
  for (i in 1:nrow(harmonization_map)) { # loop through rows
    current_row <- harmonization_map[i,]
    match_col <- current_row$match_col
    print(match_col)
    if (!is.na(match_col)) { # if there is a column to test matching
      value <- current_row$colvalue
      print(value)
      test_col_values <- harmonization_map$colvalue[harmonization_map$match_id == match_col]
      print(test_col_values)
      for (j in 1:length(test_col_values)) {
        if(!is.na(value) & !is.na(test_col_values[j])) {
          if (value == test_col_values[j]) { # if the values match
            print(value == test_col_values[j])
            test_row_final_id <- harmonization_map$link_id[(harmonization_map$match_id == match_col) & (harmonization_map$colvalue == test_col_values[j])]
            harmonization_map$link_id[i] <- test_row_final_id
            merge_links <- unique(c(merge_links, test_row_final_id))
          }   
        }
      }
    }
  }
  
  # 8. Collapse frame by link_id AND SPLIT_INDEX (prevents multiple split_index values when merging groups)
  rows_without_links <- harmonization_map %>%
    filter(!link_id %in% merge_links)
  
  if (length(merge_links) > 0) {
    for (i in 1:length(merge_links)) {
      current_link <- merge_links[i]
      print(paste0("current link: ", current_link))
      merge_split_indices <- unique(filter(harmonization_map, link_id == current_link & !is.na(split_index))$split_index)
      if (length(merge_split_indices) == 0) {
        print("0 unique non-NA indices")
        merged_rows <- harmonization_map %>%
          filter(link_id == current_link) %>%
          group_by(link_id) %>%
          summarise(across(everything(), ~paste(na.omit(.), collapse = "::")))
        print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_links"))
        print(paste0("rows_without_links rows before rbind: ", nrow(rows_without_links)))
        rows_without_links <- rbind(rows_without_links, merged_rows)
        print(paste0("rows_without_links rows after rbind: ", nrow(rows_without_links)))
      } else {
        print("some unique non-NA indices found")
        for (j in 1:length(merge_split_indices)) {
          current_index <- merge_split_indices[j]
          print(paste0("current index: ", current_index))
          merged_rows <- harmonization_map %>%
            filter(link_id == current_link & ((split_index == current_index)|(is.na(split_index)))) %>%
            group_by(link_id) %>%
            summarise(across(everything(), ~paste(na.omit(.), collapse = "::")))
          print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_links"))
          print(paste0("rows_without_links rows before rbind: ", nrow(rows_without_links)))
          rows_without_links <- rbind(rows_without_links, merged_rows)
          print(paste0("rows_without_links rows after rbind: ", nrow(rows_without_links)))
        }
      }
    }
  }
  
  harmonization_map <- rows_without_links
  harmonization_map[harmonization_map == ""] <- NA
  
  # 9. Collapse frame by group and split_index
  
  harmonization_map <- harmonization_map %>%
    mutate(row_index = rownames(harmonization_map), .before = group)
  
  row_indices <- harmonization_map$row_index
  
  rows_without_groups <- harmonization_map %>%
    filter(is.na(group))
  
  rows_to_group <- harmonization_map %>%
    filter(!is.na(group)) %>%
    mutate(group = as.character(group)) %>%
    mutate(group = strsplit(group, split = "::")) %>%
    mutate(current_bool = NA, .before = group)
  
  merge_groups <- unique(unlist(rows_to_group$group))
  merge_groups <- merge_groups[!is.na(merge_groups)]
  
  for (i in 1:length(merge_groups)) {
    current_group <- merge_groups[i]
    print(paste0("current group: ", current_group))
    for (j in 1:length(rows_to_group$group)) {
      print(current_group)
      print(rows_to_group$group[[j]])
      print(current_group %in% rows_to_group$group[[j]])
      rows_to_group$current_bool[j] <- current_group %in% rows_to_group$group[[j]]
    }
    group_rows <- filter(rows_to_group, current_bool == TRUE)
    merge_split_indices <- unique(filter(rows_to_group, current_bool == TRUE & !is.na(split_index))$split_index)
    print(paste0("unique indices: ", paste(merge_split_indices, collapse = "::")))
    if (length(merge_split_indices) == 0) {
      print("0 unique non-NA indices")
      merged_rows <- group_rows %>%
        #filter(!is.na(group) & current_group %in% group) %>%
        #group_by(group) %>%
        summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
        select(-current_bool)
      print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_groups"))
      print(paste0("rows_without_groups rows before rbind: ", nrow(rows_without_groups)))
      rows_without_groups <- rbind(rows_without_groups, merged_rows)
      print(paste0("rows_without_groups rows after rbind: ", nrow(rows_without_groups)))
    } else {
      print("some unique non-NA indices found")
      for (j in 1:length(merge_split_indices)) {
        current_index <- merge_split_indices[j]
        print(paste0("current index: ", current_index))
        merged_rows <- group_rows %>%
          #filter(!is.na(group) & current_group %in% group) %>%
          filter((split_index == current_index)|(is.na(split_index))) %>%
          #group_by(group) %>%
          summarise(across(everything(), ~paste(na.omit(.), collapse = "::"))) %>%
          select(-current_bool)
        print(paste0("adding ", nrow(merged_rows), " row(s) to rows_without_groups"))
        print(paste0("rows_without_groups rows before rbind: ", nrow(rows_without_groups)))
        rows_without_groups <- rbind(rows_without_groups, merged_rows)
        print(paste0("rows_without_groups rows after rbind: ", nrow(rows_without_groups)))
      }
    }
  }
  
  harmonization_map <- rows_without_groups
  harmonization_map[harmonization_map == ""] <- NA
  
  index_frequencies <- as.data.frame(table(unlist(strsplit(harmonization_map$row_index, split = "::"))))
  need_to_merge <- as.character(index_frequencies$Var1[index_frequencies$Freq > 1])
  
  if (length(need_to_merge) > 0) {
    group_by_index <- harmonization_map %>%
      mutate(row_index = strsplit(row_index, split = "::")) %>%
      mutate(current_bool = NA, .before = row_index)
    
    for (i in 1:length(need_to_merge)) {
      print(i)
      current_row_index <- need_to_merge[i]
      print(current_row_index)
      for (j in 1:length(group_by_index$row_index)) {
        print(current_row_index)
        print(group_by_index$row_index[[j]])
        print(current_row_index %in% group_by_index$row_index[[j]])
        group_by_index$current_bool[j] <- current_row_index %in% group_by_index$row_index[[j]]
      }
      single_index_row <- group_by_index %>%
        filter(current_bool == TRUE) %>%
        summarise(across(everything(), ~paste(na.omit(.), collapse = "::")))
      
      ungrouped_rows <- group_by_index %>%
        filter(current_bool == FALSE)
      
      group_by_index <- rbind(ungrouped_rows, single_index_row)
    }
    
    harmonization_map <- group_by_index %>%
      select(-current_bool)
    harmonization_map[harmonization_map == ""] <- NA  
  }
  
  # 10. Combine rows with the same values
  
  harmonization_map <- harmonization_map %>%
    select(treatment_name:treatment_notes) %>%
    rowwise() %>%
    mutate(across(everything(), ~paste(unique(unlist(strsplit(., split = "::"))), collapse = "::")))
  
  harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
  
  # value merging
  original_map <- harmonization_map
  for (i in 1:nrow(harmonization_map)) {
    print(paste0("row ", i))
    potential_merges <- data.frame(matrix(nrow = ncol(harmonization_map), ncol = 2, dimnames = list(colnames(harmonization_map), c("exists", "cellwise_merges"))))
    for (j in 1:ncol(harmonization_map)) {
      print(paste0("column ", j))
      current_cell <- unlist(strsplit(as.character(harmonization_map[i,j]), split = "::"))
      print(current_cell)
      if(!is.na(harmonization_map[i,j])) {
        print(!is.na(harmonization_map[i,j]))
        potential_merges$exists[j] <- TRUE
        cellwise_merges <- c()
        for (k in 1:nrow(harmonization_map)) {
          if (k != i) {
            print(paste0("testing against row ", k))
            test_cell <- unlist(strsplit(as.character(harmonization_map[k, j]), split = "::"))
            print(test_cell)
            print(intersect(current_cell, test_cell))
            print(length(intersect(current_cell, test_cell)))
            if (length(intersect(current_cell, test_cell)) > 0) {
              cellwise_merges <- c(cellwise_merges, k)
              print(paste0("cellwise_merges: ", cellwise_merges))
            }
          }
        } 
        if(length(cellwise_merges) > 0) {
          potential_merges$cellwise_merges[j] <- list(cellwise_merges)
        }
      } else {
        potential_merges$exists[j] <- FALSE
      }
    }
    if (!all(is.na(potential_merges$cellwise_merges))) {
      final_merges_frame <- potential_merges %>%
        filter(exists == TRUE)
      final_merges <- Reduce(intersect, final_merges_frame$cellwise_merges)
      
      merged_row <- as.data.frame(harmonization_map) %>%
        slice(c(i, final_merges)) %>%
        summarise(across(everything(), ~paste(na.omit(.), collapse = "::")))
      harmonization_map <- as.data.frame(harmonization_map) %>%
        slice(-c(i, final_merges)) %>%
        bind_rows(merged_row) 
    }
  }
  
  harmonization_map <- harmonization_map %>%
    rowwise() %>%
    mutate(across(everything(), ~paste(unique(unlist(strsplit(., split = "::"))), collapse = "::")))
  
  harmonization_map[harmonization_map == "" | harmonization_map == "NA"] <- NA
  
  # 11. Collapse entire frame into <;> delimited row and add to harmonized_study
  harmonization_map[is.na(harmonization_map)] <- "NA"
  harmonized_row <- harmonization_map %>%
    ungroup() %>%
    summarise(across(everything(), ~paste(., collapse = "<;>"))) %>%
    mutate(patientId = patient_ID, .before = treatment_name)
  
  harmonized_study[h,] <- harmonized_row
  
}
