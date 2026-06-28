#!/bin/bash
set -euo pipefail

RUN_ID="${1:?Usage: scripts/submit_GGR.sh fit7 [config.yml] [max_concurrent]}"
CONFIG="${2:-config.yml}"
MAXC="${3:-99999}"

ROOT="$(dirname "$(realpath "$CONFIG")")"
cd "$ROOT"

# Ensure Rscript exists (works on clusters with Environment Modules)
if ! command -v Rscript >/dev/null 2>&1; then
  module purge >/dev/null 2>&1 || true
  module load R/4.4.0 >/dev/null 2>&1 || true
fi

if ! command -v Rscript >/dev/null 2>&1; then
  echo "ERROR: Rscript not found. Load the R module first (e.g., module load R/4.4.0) or edit submit_GGR.sh to match your cluster."
  exit 1
fi

N=$(Rscript --vanilla - <<'RS'
library(yaml); library(data.table)
cfg <- read_yaml("config.yml")
res <- if (!is.null(cfg$paths$folders$results)) cfg$paths$folders$results else cfg$paths$results
df  <- fread(file.path(res, "data_processed.csv"), select="SampleID")
cat(length(unique(df$SampleID)))
RS
)

COMMON_R="$(cd "$(dirname "$0")/../../_common/R" && pwd)"

jid=$(sbatch --parsable \
  --array=1-"$N"%${MAXC} \
  --export=ALL,RUN_ID="$RUN_ID" \
  "$COMMON_R/run_GGR.sbatch" "$CONFIG" | cut -d';' -f1)

kid=$(sbatch --parsable \
  --dependency=afterok:$jid \
  --export=ALL,RUN_ID="$RUN_ID" \
  "$COMMON_R/knit_GGR_Diagnostics.sbatch" "$CONFIG")