.libPaths("/mnt/project/blfridley/PCF_pilots/_common/R/renv/library/linux-rhel-8.10/R-4.4/x86_64-pc-linux-gnu")

suppressPackageStartupMessages({
  library(targets)
  library(data.table)
  library(dplyr)
  library(stringr)
  library(readxl)
  library(yaml)
  library(fs)
  library(tibble)
})

tar_option_set(
  packages = c("data.table", "dplyr", "stringr", "readxl", "yaml", "fs", "tibble")
)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x)) || identical(x, "")) y else x

list(
  tar_target(
    cfg_path,
    "config.yml",
    format = "file"
  ),
  
  tar_target(
    cfg,
    read_yaml(cfg_path)
  ),
  
  tar_target(
    qupath_file,
    file.path(dirname(cfg_path), cfg$paths$folders$results, "QuPath_data.csv"),
    format = "file"
  ),
  
  tar_target(
    metadata_file,
    {
      x <- cfg$metadata$file %||% ""
      if (nzchar(x)) {
        file.path(dirname(cfg_path), x)
      } else {
        
        x <- dir_ls(
          file.path(dirname(cfg_path), cfg$paths$folders$pcf_images),
          recurse = FALSE,
          type = "file",
          regexp = "(?i)\\.(xlsx|xls)$"
        )
        
        # Drop Excel lock / temp files
        x <- x[!str_detect(basename(x), "^~\\$")]
        
        # Apply metadata filename pattern
        x <- x[str_detect(
          basename(x),
          regex(cfg$metadata$pattern %||% "PCF_meta_data", ignore_case = TRUE)
        )]
        
        if (length(x) == 0)
          stop("No Excel workbook found in PCF_images matching the metadata pattern.")
        if (length(x) > 1)
          stop("Multiple Excel workbooks found in PCF_images matching the metadata pattern.")
        
        x
        
      }
    },
    format = "file"
  ),
  
  tar_target(
    data_processed,
    {
      x <- suppressWarnings(fread(qupath_file))
      x <- x[Parent != ""]
      
      if ("V1" %in% names(x)) {
        x[, V1 := NULL]
      }
      
      x[, `:=`(
        Parent = as.character(Parent),
        Image  = as.character(Image)
      )]
      
      x[, join_key := get(cfg$join$qupath_col %||% "Parent")]
      
      meta <- read_excel(metadata_file, sheet = cfg$metadata$sheet %||% 1) %>%
        as.data.table() %>%
        .[, .(
          ImageID       = as.character(ImageID),
          SubjectID     = as.character(SubjectID),
          SampleID      = as.character(SampleID),
          Date.PCF.Run  = as.POSIXct(Date.PCF.Run),
          join_key      = as.character(get(cfg$join$metadata_col %||% "SampleID"))
        )]
      
      # keep only metadata that appears in QuPath
      meta <- meta[join_key %in% unique(x$join_key)]
      
      # keep latest metadata row per SampleID
      setorder(meta, join_key, -Date.PCF.Run)
      meta <- meta[!duplicated(join_key)]
      
      # safe 1:many join
      x <- merge(
        x,
        meta,
        by = "join_key",
        all.x = TRUE,
        sort = FALSE
      )
      
      if (any(is.na(x$ImageID) | is.na(x$SubjectID))) {
        stop(
          "Metadata join failed for some ", cfg$join$qupath_col %||% "Parent", " values. Examples: ",
          paste(head(unique(x$join_key[is.na(x$ImageID) | is.na(x$SubjectID)]), 10), collapse = ", ")
        )
      }
      
      # Exclude specified SampleIDs (if provided)
      if (!is.null(cfg$join$exclude)) {
        x <- x[!SampleID %in% cfg$join$exclude]
      }
      
      marker_cols <- grep(
        "^\\s*Cell:\\s*[^:]+:\\s*Mean\\s*$",
        names(x),
        value = TRUE,
        ignore.case = TRUE
      )
      
      markers <- marker_cols %>%
        sub("^\\s*Cell:\\s*", "", ., ignore.case = TRUE) %>%
        sub(":\\s*Mean\\s*$", "", ., ignore.case = TRUE) %>%
        unique() %>%
        sort()
      
      qc_cols <- grep(
        "Area|Perimeter|Circularity|caliper|Eccentricity|ratio|Length|diameter|Solidity",
        names(x),
        value = TRUE,
        ignore.case = TRUE
      )
      
      x <- x[, c("ImageID", "SubjectID", "SampleID", "Parent", "CentroidX µm", "CentroidY µm", marker_cols, qc_cols), with = FALSE]
      
      setnames(x, c("Parent", "CentroidX µm", "CentroidY µm"), c("QuPathParent", "X", "Y"))
      setnames(x, marker_cols, markers)
      
      for (j in markers) {
        set(x, j = j, value = as.numeric(x[[j]]))
      }
      
      x[, paste0("nzNorm_", markers) := lapply(.SD, function(v) {
        m <- mean(replace(v, v == 0, NA), na.rm = TRUE)
        log10(1 + v / m)
      }), by = SampleID, .SDcols = markers]
      
      x <- x %>% select(-QuPathParent)
      
      x
      
    }
  ),
  
  tar_target(
    normalized_outfile,
    {
      x <- file.path(dirname(cfg_path), cfg$paths$folders$results, "data_processed.csv")
      fwrite(data_processed, x)
      x
    },
    format = "file"
  )
)
