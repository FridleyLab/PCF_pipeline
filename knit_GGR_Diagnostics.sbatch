#!/bin/bash
#SBATCH --job-name=KnitGGR
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH --partition=medium
#SBATCH --output=logs/GGR_Diagnostics_%A_%a.out
#SBATCH --error=logs/GGR_Diagnostics_%A_%a.err

set -euo pipefail

CONFIG="${1:-config.yml}"
ROOT="$(dirname "$(realpath "$CONFIG")")"
cd "$ROOT"

# Enforce shared renv project
export RENV_PROJECT="$(cd "$ROOT/../../_common" && pwd)"

# Environment
source "$RENV_PROJECT/R/gcc-9.3.0/gcc.env"
source "$RENV_PROJECT/R/pandoc/pandoc.env"
module load R/4.4.0

# Logging
LOGDIR="$ROOT/logs/slurm"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGDIR/${SLURM_JOB_NAME}_${SLURM_JOB_ID}.out") 2>&1

: "${RUN_ID:?RUN_ID not set}"

Rscript --vanilla - <<'RS'
library(yaml)
library(rmarkdown)

cfg <- read_yaml("config.yml")

res <- if (!is.null(cfg$paths$folders$results)) {
  cfg$paths$folders$results
} else {
  cfg$paths$results
}

ggr_base <- if (!is.null(cfg$paths$results_GammaGateR)) {
  cfg$paths$results_GammaGateR
} else {
  file.path(res, "GammaGateR")
}

run_id  <- Sys.getenv("RUN_ID")
outdir  <- normalizePath(file.path(ggr_base, run_id), mustWork = TRUE)

render(
  input         = file.path(Sys.getenv("RENV_PROJECT"), "R", "03-GGR_Diagnostics.Rmd"),
  params = list(run_id = Sys.getenv("RUN_ID")),
  knit_root_dir = getwd(),
  output_dir    = outdir,
  output_file   = paste0("GGR_Diagnostics_", run_id, ".html"),
  quiet         = FALSE
)

cat("Wrote:", file.path(outdir, paste0("GGR_Diagnostics_", run_id, ".html")), "\n")
RS
