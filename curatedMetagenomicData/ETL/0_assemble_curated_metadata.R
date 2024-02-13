### This script collect all the curated cMD metadata data files per attribute
### and combine them into a single `curated_all` table. 


# Import curated/harmonized attributes ----
dir <- "~/OmicsMLRepo/OmicsMLRepoData"
dataDir <- file.path(dir, "curatedMetagenomicData/data")
curated <- list.files(dataDir)
curated <- curated[grepl("\\.csv$", curated)] # choose only file
curatedDatObj <- gsub(".csv", "", curated)

for (i in seq_along(curated)) {
    res <- read_csv(file.path(dataDir, curated[i]))
    assign(curatedDatObj[i], res)
}

# Combine all the curated sample metadata ----
curated_all <- get(curatedDatObj[1])
for (i in 2:length(curatedDatObj)) { # assuming there are >= 2 tables to be combined
    dat <- get(curatedDatObj[i])
    curated_all <- left_join(curated_all, dat, by = "curation_id")
}
