library(targets)
library(rmarkdown)
library(yaml)

script_path <- sub(
  "--file=", "",
  commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))]
)
script_dir <- dirname(normalizePath(script_path))
setwd(file.path(script_dir, ".."))

stopifnot(file.exists("config.yml"))
stopifnot(file.exists("_targets.R"))

cfg <- read_yaml("config.yml")

# ------------------------------------------------------------
# 1) targets
# ------------------------------------------------------------
tar_make(callr_function = NULL, reporter = "verbose")

stopifnot(file.exists("results/data_processed.csv"))

# ------------------------------------------------------------
# 2) FIRST‑PASS GammaGateR bootstrap (fit0NULL)
# ------------------------------------------------------------
Sys.setenv(
  RUN_ID = "fit0NULL",
  GGR_PANEL = cfg$gammagater$panel,
  GGR_NULL_BOUNDARIES = "TRUE"
)

# IMPORTANT: call as a new R process
system2(
  "Rscript",
  args = c("../_common/R/02-run_GGR.R"),
  stdout = "",
  stderr = ""
)

# ------------------------------------------------------------
# 3) QC report (LAST)
# ------------------------------------------------------------
rmarkdown::render(
  input         = "../../_common/R/01-SegmentationQC.Rmd",
  output_dir    = "results",
  knit_root_dir = getwd()
)
