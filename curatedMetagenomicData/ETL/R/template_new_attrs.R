### Data dictionary for newly added attributes
### Required input: `expanded_dd`

# ECOG Performance Status -----
ECOG_Performance_Status <- data.frame(
    col.name = "ecog_performance_status",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE,
    description = "A performance status scale designed to assess disease progression and its affect on the daily living abilities of the patient. (NCIT:C105721)",
    allowedvalues = paste("ECOG Performance Status", c("0", "1", "2", "2 or Higher", "3", "4", "5")) %>%
        paste0(., collapse = "|"),
    ontology = "NCIT:C105722|NCIT:C105723|NCIT:C105724|NCIT:C105725|NCIT:C105726|NCIT:C105727|NCIT:C105728"
)

# Overall survival -----
disease_response_os <- data.frame(
    col.name = "disease_response_os",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional", 
    multiplevalues = FALSE, 
    description = "A measure of the time until death from any cause. (NCIT:C125201)",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA
) 

disease_response_os_unit <- data.frame(
    col.name = "disease_response_os_unit",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",  #<<<<<<<< required if `disease_response_os` is entered
    multiplevalues = FALSE, 
    description = "A time point used to observe overall survival (OS).",
    allowedvalues = "Day|Week|Month|Year",
    ontology = "NCIT:C25301|NCIT:C29844|NCIT:C29846|NCIT:C29848"
)

# Tumor Size Measurement ----------
tumor_size <- data.frame(
    col.name = "tumor_size_measurement",
    col.class = "numeric",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE, 
    description = "The measurement of the size of a tumor mass either clinically or in a surgically resected specimen. (NCIT:C106303)",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA
)

tumor_size_residual <- data.frame(
    col.name = "tumor_size_residual_measurement",
    col.class = "character",
    uniqueness = "non-unique", 
    requiredness = "optional",
    multiplevalues = FALSE, 
    description = "A procedure that measures the size of a residual tumor mass. (NCIT:C198194)",
    allowedvalues = "^[1-9]\\d*(\\.\\d+)?$",
    ontology = NA
)



# Data dictionary for curated attributes ----
attr_dd <- do.call("rbind", list(
    ECOG_Performance_Status,
    disease_response_os,
    disease_response_os_unit,
    tumor_size,
    tumor_size_residual
))

# Add the content to data dictionary template, `expanded_dd` ----
expanded_dd <- rbind(expanded_dd, attr_dd)
