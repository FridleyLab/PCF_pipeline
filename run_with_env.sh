#!/bin/bash
#SBATCH --job-name=targets
#SBATCH --partition=long
#SBATCH --mem=96G
#SBATCH --cpus-per-task=4
#SBATCH --time=08:00:00

set -euo pipefail

# Reduce allocator fragmentation (important for large fread)
export MALLOC_ARENA_MAX=2

# Resolve pilot root from script location
PILOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Enforce shared renv project
export RENV_PROJECT="/mnt/project/blfridley/PCF_pilots/_common"

# Load GCC
source "$RENV_PROJECT/R/gcc-9.3.0/gcc.env"

# Load Pandoc
source "$RENV_PROJECT/R/pandoc/pandoc.env"

# Load R
module load R/4.4.0

# Run pipeline from pilot root
cd "$PILOT_ROOT"
Rscript scripts/run_pipeline.R
