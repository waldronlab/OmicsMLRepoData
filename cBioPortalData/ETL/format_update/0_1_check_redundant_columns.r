## Define a function to read only the column names of a table
get_column_names <- function(dat_name) {
    dat <- get(dat_name)
    return(names(dat))
}

## Apply the function to all files and store the results in a list
all_col_names <- lapply(curatedAll, get_column_names)

## Name the list elements with the file names for easy identification
names(all_col_names) <- curatedAll

## Compare the column names to find matches

# Initialize a logical vector to check for shared column names
# We compare the first set of names (File 1) against all others (File 2 to N), 
# then File 2 against File 3 to N, and so on.

shared_cols_found <- FALSE
matching_files <- list()
n_files <- length(all_col_names)

if (n_files > 1) {
    # Loop through every unique pair of files
    for (i in 1:(n_files - 1)) {
        for (j in (i + 1):n_files) {
            # Use identical() to check if the column names (including order) are exactly the same
            shared_cols <- intersect(all_col_names[[i]], all_col_names[[j]])
            shared_cols <- shared_cols[shared_cols != "curation_id"]
            if (length(shared_cols) != 0) {
                shared_cols_found <- TRUE
                # Store the names of the matching files
                matching_files <- append(matching_files, list(c(names(all_col_names)[i], names(all_col_names)[j])))
            }
        }
    }
}

## Print the final result
if (shared_cols_found) {
    cat("\n❌ **MATCH FOUND!** The following pairs of files share the exact same column names:\n")
    
    # Print the list of matching pairs
    for (pair in matching_files) {
        cat(sprintf("   - **%s** and **%s**\n", pair[1], pair[2]))
    }
} else {
    cat("\n✅ **NO MATCH FOUND.** All found CSV files have unique sets of column names.\n")
}