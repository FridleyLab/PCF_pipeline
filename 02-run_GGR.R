.libPaths("/mnt/project/blfridley/PCF_pilots/_common/R/renv/library/linux-rhel-8.10/R-4.4/x86_64-pc-linux-gnu")

suppressPackageStartupMessages({
  library(yaml)
  library(data.table)
  library(GammaGateR)
  library(cfGMM)
})

start_time <- Sys.time()
cat(
  sprintf(
    "[%s] GammaGateR job started | RUN_ID=%s | ArrayTask=%s\n",
    format(start_time, "%Y-%m-%d %H:%M:%S"),
    Sys.getenv("RUN_ID", "NA"),
    Sys.getenv("SLURM_ARRAY_TASK_ID", "NA")
  )
)

cfg_path <- normalizePath("config.yml", mustWork = TRUE)
cfg <- yaml::read_yaml(cfg_path)

df <- fread(file.path(
  dirname(cfg_path),
  (function(x) if (!is.null(x$paths$folders$results)) x$paths$folders$results else x$paths$results)(read_yaml(cfg_path)),
  "data_processed.csv"
))

outdir <- file.path(
  dirname(cfg_path),
  (function(x) if (!is.null(x$paths$results_GammaGateR)) x$paths$results_GammaGateR else {
    file.path(if (!is.null(x$paths$folders$results)) x$paths$folders$results else x$paths$results, "GammaGateR")
  })(read_yaml(cfg_path))
)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# --- run folder (RUN_ID env var preferred; else timestamp) ---
run_id <- Sys.getenv("RUN_ID", "")
if (run_id == "") run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
run_dir <- file.path(outdir, run_id)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

# choose SampleID for this array task
sample_id <- unique(df$SampleID)[as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))]
df <- df[SampleID == sample_id]

##############
# GammaGateR #
##############

# Model Thresholds
# Formatted as c(lower.unexpressed, upper.unexpressed, lower.expressed, upper.expressed)
# Thresholds are on where the expected mode of the unexpressed & expressed mixture components lie.
# This allows for some control of the % of cells classified as marker-positive by the model. 

## Mouse Panel (24 markers + DAPI)
boundaries_mouse <- list(
  Caveolin          = matrix(c(0, 0.25, 0.50, Inf), byrow=TRUE, nrow=2),
  CD11c             = matrix(c(0, 0.3, 0.375, Inf), byrow=TRUE, nrow=2),
  CD20              = matrix(c(0, 0.30, 0.41, 1), byrow=TRUE, nrow=2),
  CD206             = matrix(c(0, 0.3, 0.35, Inf), byrow=TRUE, nrow=2),
  CD31              = matrix(c(0, 0.35, 0.50, Inf), byrow=TRUE, nrow=2),  
  CD36              = matrix(c(0, 0.25, 0.40, Inf), byrow=TRUE, nrow=2),  
  CD3e              = matrix(c(0, 0.3, 0.35, Inf), byrow=TRUE, nrow=2),  
  CD4               = matrix(c(0, 0.30, 0.4, Inf), byrow=TRUE, nrow=2),  
  CD44              = matrix(c(0, 0.25, 0.35, Inf), byrow=TRUE, nrow=2), 
  CD45              = matrix(c(0, 0.325, 0.375, Inf), byrow=TRUE, nrow=2), 
  `CD45R/B220`      = matrix(c(0, 0.30, 0.405, 1), byrow=TRUE, nrow=2),
  CD68              = matrix(c(0, 0.325, 0.35, 1), byrow=TRUE, nrow=2), 
  CD8               = matrix(c(0, 0.35, 0.4, Inf), byrow=TRUE, nrow=2),
  Col1A1            = matrix(c(0, 0.10, 0.768, Inf), byrow=TRUE, nrow=2),
  DAPI              = matrix(c(0, 0.35, 0.40, Inf), byrow=TRUE, nrow=2),
  `F4/80`           = matrix(c(0, 0.3, 0.35, Inf), byrow=TRUE, nrow=2),
  FCRy              = matrix(c(0, 0.275, 0.35, Inf), byrow=TRUE, nrow=2),
  FOXP3             = matrix(c(0, 0.30, 0.375, 1), byrow=TRUE, nrow=2), 
  Iba1              = matrix(c(0, 0.25, 0.35, Inf), byrow=TRUE, nrow=2), 
  Ki67              = matrix(c(0, 0.22, 0.48, 1), byrow=TRUE, nrow=2), 
  Ly6g              = matrix(c(0, 0.30, 0.375, Inf), byrow=TRUE, nrow=2),
  `Pan-Cytokeratin` = matrix(c(0, 0.3, 0.35, Inf), byrow=TRUE, nrow=2), 
  S100A9            = matrix(c(0, 0.25, 0.55, Inf), byrow=TRUE, nrow=2),
  Ter119            = matrix(c(0, 0.20, 0.55, Inf), byrow=TRUE, nrow=2),
  Vimentin          = matrix(c(0, 0.18, 0.325, Inf), byrow=TRUE, nrow=2) 
)

## IO60 Panel 

boundaries_IO60 <- list(
  `b-Catenin1`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Bcl-2`             = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Beta-actin`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  Caveolin            = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD107a              = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD11b               = matrix(c(0, 0.45, 0.50, 1), byrow = TRUE, nrow = 2),
  CD11c               = matrix(c(0, 0.25, 0.35, Inf), byrow = TRUE, nrow = 2),
  CD14                = matrix(c(0, 0.2, 0.30, 1), byrow = TRUE, nrow = 2),
  CD163               = matrix(c(0, 0.275, 0.3, Inf), byrow = TRUE, nrow = 2),
  CD20                = matrix(c(0, 0.55, 0.675, Inf), byrow = TRUE, nrow = 2),
  CD206               = matrix(c(0, 0.275, 0.4, Inf), byrow = TRUE, nrow = 2),
  CD209               = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD21                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD31                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD34                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD38                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD39                = matrix(c(0, 0.075, 0.1, Inf), byrow = TRUE, nrow = 2),
  CD3e                = matrix(c(0, 0.3, 0.4, Inf), byrow = TRUE, nrow = 2),
  CD4                 = matrix(c(0, 0.35, 0.4, Inf), byrow = TRUE, nrow = 2),
  CD44                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD45                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD45RO              = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD56                = matrix(c(0, 0.325, 0.45, Inf), byrow = TRUE, nrow = 2),
  CD57                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD66                = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  CD68                = matrix(c(0, 0.2, 0.25, Inf), byrow = TRUE, nrow = 2),
  CD79a               = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD8                 = matrix(c(0, 0.275, 0.3, Inf), byrow = TRUE, nrow = 2),
  `Collagen IV`       = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  DAPI                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `E-cadherin`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  EpCAM               = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  ER                  = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  FOXP3               = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  GP100               = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Granzyme B`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Histone H3 (p Ser28)` = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `HLA-A`             = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `HLA-DR`            = matrix(c(0, 0.25, 0.30, Inf), byrow = TRUE, nrow = 2),
  ICOS                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  IDO1                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  IFNG                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  iNOS                = matrix(c(0, 0.3, 0.375, Inf), byrow = TRUE, nrow = 2),
  `Keratin 14`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Keratin 5`         = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Keratin 8/18`      = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  Ki67                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  LAG3                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  MPO                 = matrix(c(0, 0.25, 0.325, Inf), byrow = TRUE, nrow = 2),
  `Pan-Cytokeratin`   = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  PCNA                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `PD-1`              = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `PD-L1`             = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  Podoplanin          = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  SMA                 = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  SOX2                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  `TCF-1`             = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  TOX                 = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  TP63                = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  Vimentin            = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  VISTA               = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2)
)

## Neuro Panel

boundaries_neuro <- list(
  `A-beta`                 = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  `Alpha-synuclein`        = matrix(c(0, 0.25, 0.50, Inf), byrow = TRUE, nrow = 2),
  ApoE                    = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  AQP4                    = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD14                    = matrix(c(0, 0.35, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD163                   = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD31                    = matrix(c(0, 0.25, 0.35, Inf), byrow = TRUE, nrow = 2),
  CD34                    = matrix(c(0, 0.15, 0.3, Inf), byrow = TRUE, nrow = 2),
  CD3e                    = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  CD4                     = matrix(c(0, 0.3, 0.4, Inf), byrow = TRUE, nrow = 2),
  CD44                    = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  CD45                    = matrix(c(0, 0.4, 0.45, Inf), byrow = TRUE, nrow = 2),
  CD68                    = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  CD8                     = matrix(c(0, 0.15, 0.3, Inf), byrow = TRUE, nrow = 2),
  CHAT                    = matrix(c(0, 0.25, 0.375, Inf), byrow = TRUE, nrow = 2),
  `Claudin-5`             = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  `Collagen IV`           = matrix(c(0, 0.1, 0.15, Inf), byrow = TRUE, nrow = 2),
  DAPI                    = matrix(c(0, 0.15, 0.2, Inf), byrow = TRUE, nrow = 2),
  GABA                    = matrix(c(0, 0.3, 0.35, Inf), byrow = TRUE, nrow = 2),
  GFAP                    = matrix(c(0, 0.05, 0.10, Inf), byrow = TRUE, nrow = 2),
  `H2A.X`                 = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  `HLA-A`                 = matrix(c(0, 0.35, 0.40, Inf), byrow = TRUE, nrow = 2),
  `HLA-DR`                = matrix(c(0, 0.05, 0.10, Inf), byrow = TRUE, nrow = 2),
  `Iba-1`                 = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  iNOS                    = matrix(c(0, 0.35, 0.40, Inf), byrow = TRUE, nrow = 2),
  Ki67                    = matrix(c(0, 0.05, 0.2, Inf), byrow = TRUE, nrow = 2),
  `Mac2/Galectin-3`       = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  `MAP-2`                 = matrix(c(0, 0.35, 0.50, Inf), byrow = TRUE, nrow = 2),
  MBP                     = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  NeuN                    = matrix(c(0, 0.4, 0.50, Inf), byrow = TRUE, nrow = 2),
  `Neurofilament-L`       = matrix(c(0, 0.325, 0.375, Inf), byrow = TRUE, nrow = 2),
  `Olig-2`                = matrix(c(0, 0.35, 0.50, Inf), byrow = TRUE, nrow = 2),
  PCNA                    = matrix(c(0, 0.3, 0.55, Inf), byrow = TRUE, nrow = 2),
  S100B                   = matrix(c(0, 0.325, 0.4, Inf), byrow = TRUE, nrow = 2),
  Serotonin               = matrix(c(0, 0.05, 0.10, Inf), byrow = TRUE, nrow = 2),
  SMA                     = matrix(c(0, 0.2, 0.4, Inf), byrow = TRUE, nrow = 2),
  Synaptophysin           = matrix(c(0, 0.3, 0.35, Inf), byrow = TRUE, nrow = 2),
  `Tau (phospho S396)`    = matrix(c(0, 0.3, 0.40, Inf), byrow = TRUE, nrow = 2),
  `Tau (phospho T181)`    = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  `Tau (phospho T205)`    = matrix(c(0, 0.35, 0.4, Inf), byrow = TRUE, nrow = 2),
  `Tau phosphoT231`       = matrix(c(0, 0.3, 0.4, Inf), byrow = TRUE, nrow = 2),
  TMEM119                 = matrix(c(0, 0.35, 0.45, Inf), byrow = TRUE, nrow = 2),
  Vimentin                = matrix(c(0, 0.25, 0.325, Inf), byrow = TRUE, nrow = 2)
)

## Custom Panel (if modifying any of above to add/remove markers, copy them here and make the changes)






# GGR Script

panel <- Sys.getenv("GGR_PANEL", cfg$gammagater$panel %||% "mouse") # Defaults to mouse panel if not specified in YML (so set it!)

boundaries <- switch(
  panel,
  mouse  = boundaries_mouse,
  IO60   = boundaries_IO60,
  neuro  = boundaries_neuro,
  custom = boundaries_custom,
  stop("Unknown GGR panel: ", panel)
)

# ------------------------------------------------------------
# Optional: restrict to gating markers from config.yml
# ------------------------------------------------------------

gating_markers <- cfg$gammagater$markers %||% NULL

if (!is.null(gating_markers)) {
  
  # Ensure requested markers exist in boundaries
  missing_gate <- setdiff(gating_markers, names(boundaries))
  if (length(missing_gate)) {
    stop(
      "Requested gating markers not found in panel ",
      panel, ": ",
      paste(missing_gate, collapse = ", ")
    )
  }
  
  # Subset boundaries to gating markers only
  boundaries <- boundaries[gating_markers]
}

missing <- setdiff(paste0("nzNorm_", names(boundaries)), names(df))
if (length(missing)) {
  stop("Missing nzNorm markers for panel ", panel, ": ",
       paste(missing, collapse = ", "))
}

if (Sys.getenv("SLURM_ARRAY_TASK_ID", "1") == "1") {
  saveRDS(boundaries, file.path(run_dir, paste0("boundaries_", panel, ".rds")))
}

fit <- groupGammaGateR(
  as.data.frame(df[, paste0("nzNorm_", names(boundaries)), with = FALSE]),
  slide = df[["ImageID"]],
  boundaryMarkers = unname(boundaries),
  n.cores = as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))
)

saveRDS(fit, file.path(run_dir, paste0(sample_id, ".rds")))

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "secs")

cat(
  sprintf(
    "[%s] GammaGateR job finished | RUN_ID=%s | ArrayTask=%s | Runtime=%.1f seconds (%.2f hours)\n",
    format(end_time, "%Y-%m-%d %H:%M:%S"),
    Sys.getenv("RUN_ID", "NA"),
    Sys.getenv("SLURM_ARRAY_TASK_ID", "NA"),
    as.numeric(elapsed),
    as.numeric(elapsed) / 3600
  )
)

