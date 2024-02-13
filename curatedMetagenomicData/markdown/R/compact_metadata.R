# This script creates `uncurated` column which contains all the values marked 
# as `FALSE` in the `ver_0.99.0` column in the `cMD_metadata_export_version.csv`
# table. For each column, the column name and the value is separated by `:` 
# and different columns are separated by `;`.

# For now, we are ignoring these `uncurated` variables. Some of these uncurated
# variables will be exposed in the future releases.


suppressPackageStartupMessages({
    library(dplyr)
})

## Select the variables to be exposed
## I edited this from the Google Sheet
# dir <- system.file("extdata", package = "OmicsMLRepoData")
dir <- "~/OmicsMLRepo/OmicsMLRepoData/inst/extdata"
map <- read.table(file.path(dir, "cMD_metadata_export_version.csv"),
                  sep = ",", header = TRUE)[,-1]

## Variables not to be included for the selected version of export
uncurated_var <- map$ind[which(map$ver_0.99.0 == "FALSE")]

## Make a compact version of sampleMetadata
x <- read.table(file.path(dir, "cMD_curated_sampleMetadata.csv"),
                sep = ",", header = TRUE)
for (var in uncurated_var) {
    x[var] <- paste(var, x[[var]], sep = ":") # 'column_name:value' separated by ':'
}
meta <- x %>%
    tidyr::unite(col = "unharmonized_metadata",
                 all_of(uncurated_var),
                 sep = ";", # columns separated by ';'
                 remove = TRUE, # remove the individual column
                 na.rm = FALSE) # NA stays

## Place the `uncurated` column at the end
meta <- relocate(meta, "unharmonized_metadata", .after = "last_modified")
