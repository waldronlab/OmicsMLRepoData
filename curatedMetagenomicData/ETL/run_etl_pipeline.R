# Source required modules
# Determine script directory robustly
get_script_dir <- function() {
    # Try to get script path from command args (works with Rscript)
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    
    if (length(file_arg) > 0) {
        script_path <- sub("^--file=", "", file_arg)
        return(dirname(normalizePath(script_path)))
    }
    
    # Fallback for interactive or sourced execution
    # Safely check if we can access sys.frame(1) without causing an error
    tryCatch({
        if (sys.nframe() >= 1) {
            frame1 <- sys.frame(1)
            if (exists("ofile", where = frame1, inherits = FALSE)) {
                return(dirname(frame1$ofile))
            }
        }
    }, error = function(e) {
        # Silently continue to next fallback
    })
    
    # Final fallback to expected location
    return("curatedMetagenomicData/ETL")
}