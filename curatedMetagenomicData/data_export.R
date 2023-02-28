##### How to run this script in superstudio ####################################
# /usr/bin/Rscript data_export.R

##### Setup ####################################################################
suppressPackageStartupMessages({
    library(curatedMetagenomicData)
    library(dplyr)
    library(purrr)
    library(dplyr)
})
all_studies <- unique(sampleMetadata$study_name)
dataTypes <- c("gene_families", "marker_abundance", "marker_presence", 
               "pathway_abundance", "pathway_coverage", "relative_abundance")
## Temporal subset of studies
study_size <- sampleMetadata %>%
    dplyr::group_by(study_name) %>% 
    summarise(., n = dplyr::n())
test_studies <- study_size[order(study_size$n),] %>% head(., 5) %>% .$study_name


##### Sample-level Export ######################################################
for (i in seq_along(test_studies)) { ##<<<<<<<<<< Switch to run all studies
    
    ## Target repository <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Need to update
    study_dir <- "~/Packages/OmicsMLRepoData/curatedMetagenomicData/export_example/study_level" 
    sample_dir <- "~/Packages/OmicsMLRepoData/curatedMetagenomicData/export_example/sample_level"
    
    ## Collect values for manifest file
    sample_mani <- data.frame(sample_id = character(),
                              location = character(), # physical location the file is stored
                              size = numeric(), # file size in Byte
                              checksum = character(), # md5sum
                              updated = as.Date(character())) # the date last modified  
    
    ## Get all the sample metadata for a given study
    study <- test_studies[i]
    meta <- sampleMetadata |> 
        dplyr::filter(study_name == study) |>
        dplyr::select(where(~ !all(is.na(.x)))) 
    
    ## Calculate metadata completeness
    meta_completeness <- round(colSums(!is.na(meta))/nrow(meta)*100)
    
    ## Collect study-level metadata <<<<< Might be required for non-curated datasets
    # study_mani <- data.frame(attribute = names(meta),
    #                          completeness = unname(meta_completeness),
    #                          values = NA,
    #                          type = NA, ##<<<<<<<<<<<<< Use metadata dictionary
    #                          keywords = NA)
    # 
    # ## Save study-level manifest file including attributes
    # jsonlite::write_json(study_mani, 
    #                      file.path(study_dir, paste0(study, "_manifest.json")),
    #                      na = "null")
    
    for (j in seq_len(nrow(meta))) {
        # for (j in seq_len(nrow(meta))[1:3]) { ##<<<<<<<<<< Switch to run all samples
        id <- meta$sample_id[j] ##<<<<<<<<<< Confirm the header label
        
        ## Save sample metadata for each sample
        meta_fname <- file.path(sample_dir, paste0(id, "_metadata.csv"))
        data.table::fwrite(meta[j,], meta_fname)
        
        ## Value for manifest file
        res1 <- data.frame(sample_id = id,
                           study = study,
                           type = "metadata",
                           location = meta_fname,
                           size = file.size(meta_fname),
                           checksum = tools::md5sum(meta_fname),
                           updated = Sys.Date())
        sample_mani <- rbind(sample_mani, res1, make.row.names = FALSE)
        
        for (k in seq_along(dataTypes)) {
            ## Get the all the assay data for a study's given data type
            dataType <- dataTypes[k]
            se <- returnSamples(meta, dataType)
            
            ## Save assay data for each sample for a given data type
            data_fname <- file.path(sample_dir, paste0(id, "_", dataType, ".csv"))
            assay_tb <- as.data.frame(as.matrix(assay(se))) 
            data.table::fwrite(assay_tb[,id,drop = FALSE],
                               file = data_fname, 
                               row.names = TRUE, col.names = TRUE)
            
            ## Value for manifest file
            res2 <- data.frame(sample_id = id,
                               study = study,
                               type = dataType,
                               location = data_fname,
                               size = file.size(data_fname),
                               checksum = tools::md5sum(data_fname),
                               updated = Sys.Date())
            sample_mani <- rbind(sample_mani, res2, make.row.names = FALSE)
        }
    }
    
    ##### Save the manifest as YAML ################################################
    ## Temporal reformatting of the sample_manifest table
    df <- sample_mani[,c("sample_id", "type", "location", "size", "checksum", "updated")]
    colnames(df)[c(1,5)] <- c("name", "md5sum")
    
    ## A nested list containing file metadata, such as type, location, checksum, etc.
    nested_file <- df %>%   
        group_split(name) %>%
        purrr::map(dplyr::select, -name) %>%
        purrr::map(~ group_split(., type)) 

    ## A nested list with the 'name' and 'files' level added
    study_manifest <- vector(mode = "list", length = length(unique(df$name)))
    for (i in seq_along(unique(df$name))) {
        study_manifest[[i]] <- list(name = unique(df$name)[i],
                                    files = nested_file[i]) # more depth
    }
    # cat(yaml::as.yaml(list(samples = study_manifest))) ## If I want to comment "samples" category
    cat(yaml::as.yaml(study_manifest))
    
    ## Save
    yaml::write_yaml(study_manifest, 
                     file.path(study_dir, paste0(study, "_sample_manifest.yaml")))
    
}


