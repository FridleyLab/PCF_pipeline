#!/bin/bash
#SBATCH --job-name=GammaGateR
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --partition=medium
#SBATCH --output=logs/GammaGateR_%A_%a.out
#SBATCH --error=logs/GammaGateR_%A_%a.err

set -euo pipefail

CONFIG="${1:-config.yml}"
ROOT="$(dirname "$(realpath "$CONFIG")")"
cd "$ROOT"

# Enforce shared renv
export RENV_PROJECT="$(cd "$ROOT/../../_common" && pwd)"

# Environment
source /mnt/project/blfridley/PCF_pilots/_common/R/gcc-9.3.0/gcc.env
source /mnt/project/blfridley/PCF_pilots/_common/R/pandoc/pandoc.env
module load R/4.4.0

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

: "${RUN_ID:?Set RUN_ID}"

Rscript --vanilla "$RENV_PROJECT/R/02-run_GGR.R" --config "$CONFIG"
