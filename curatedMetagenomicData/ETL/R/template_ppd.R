# # probing_pocket_depth (expanded) -----
# probing_pocket_depth_buccal <- data.frame(
#     col.name = "probing_pocket_depth_buccal", 
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Depth of periodontal pocket (observable entity) (SNOMED:286546002) measured at Buccal surface (FMA:64849)",
#     allowedvalues = "[0-9]+",
#     ontology = NA     
# ) 
# 
# probing_pocket_depth_distal <- data.frame(
#     col.name = "probing_pocket_depth_distal", 
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Depth of periodontal pocket (observable entity) (SNOMED:286546002) measured at Distal surface of tooth (FMA:55649)",
#     allowedvalues = "[0-9]+",
#     ontology = NA     
# ) 
# 
# probing_pocket_depth_lingual <- data.frame(
#     col.name = "probing_pocket_depth_lingual", 
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Depth of periodontal pocket (observable entity) (SNOMED:286546002) measured at Lingual surface of tooth (FMA:55647)",
#     allowedvalues = "[0-9]+",
#     ontology = NA     
# ) 
# 
# probing_pocket_depth_mesial <- data.frame(
#     col.name = "probing_pocket_depth_mesial", 
#     col.class = "numeric",
#     uniqueness = "non-unique", 
#     requiredness = "optional",
#     multiplevalues = FALSE,
#     description = "Depth of periodontal pocket (observable entity) (SNOMED:286546002) measured at Mesial surface of tooth (FMA:55650)",
#     allowedvalues = "[0-9]+",
#     ontology = NA     
# ) 
# 
# curated_probing_pocket_depth <- bind_rows(probing_pocket_depth_buccal, 
#                                           probing_pocket_depth_distal, 
#                                           probing_pocket_depth_lingual, 
#                                           probing_pocket_depth_mesial)

# probing_pocket_depth (collapsed) -----
ppd_map <- read.csv(file.path(mapDir, "cMD_PPD_map.csv")) %>%
    .[order(.$curated_ontology_term),]

curated_probing_pocket_depth <- data.frame(
    col.name = "probing_pocket_depth",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "Depath of periodontal pocket measured at the different tooth's regions",
    allowedvalues = paste(unique(ppd_map$curated_ontology_term), collapse = "|"),
    ontology = paste(unique(ppd_map$curated_ontology_term_id), collapse = "|")     
) 

# Add the content to data dictionary template, `filled_dd` ----
filled_dd <- fillDataDictionary(filled_dd, curated_probing_pocket_depth)
