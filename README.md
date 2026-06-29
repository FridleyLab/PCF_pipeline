# PCF Workflow
Code for the workflow used in the PCF analysis pipeline. 

**QuPath / Groovy**

_parallel_segmenter.groovy_ — Runs StarDist2D nuclear segmentation across all images in a QuPath project using a parallel Java thread pool, detecting cells within existing annotation objects only. Saves results back to the project on completion.

_detection_output.groovy_ — Exports all QuPath detection objects (cell morphology measurements and per-channel mean intensities) to a single results/QuPath_data.csv, with centroids converted to microns using the image's pixel calibration.

**R — Orchestration**

_run_pipeline.R_ — Top-level entry point that sequentially runs the {targets} DAG, launches a first-pass GammaGateR bootstrap subprocess, and renders the segmentation QC report.

_targets_pipeline.R_ — Defines the {targets} DAG that ingests QuPath_data.csv, joins sample metadata from Excel, applies per-sample non-zero-mean log10 normalization, and writes results/data_processed.csv.

**R — Analysis Reports**

_01-SegmentationQC.Rmd_ — Renders an HTML QC report auditing StarDist segmentation quality across all samples: cell counts, morphology distributions, bivariate sanity checks, a per-sample flag table, and normalized expression density curves to inform GammaGateR boundary specification.

_02-run_GGR.R_ — Fits GammaGateR two-component gamma mixture models for a single sample (selected by SLURM_ARRAY_TASK_ID) against a panel-specific boundary list, and saves the fitted object to results/GammaGateR/<RUN_ID>/<SampleID>.rds.

_03-GGR_Diagnostics.Rmd_ — Parameterized report evaluating GammaGateR model quality for a completed fitting run: convergence checks, mixture density histograms, posterior probability distributions, confidence and entropy metrics, cross-marker correlation, and intensity-vs-posterior mapping.

_04-spatial_analysis.Rmd_ — Converts GammaGateR posterior probabilities to binary marker calls using Bayesian FDR thresholding, applies a hierarchical phenotype rule set to assign each cell a lineage and phenotype label, and runs a QC audit of the gating and phenotyping results.

_05-Report.qmd_ — Final Quarto results report compiling phenotype abundance summary tables, per-lineage boxplot panels with optional statistical comparisons, stacked bar charts of lineage and phenotype composition, and marker co-expression tabsets.

**HPC / Slurm**

_run_with_env.sh_ — Sbatch wrapper that sources the shared GCC/Pandoc environments, loads R/4.4.0, and runs run_pipeline.R from the pilot root.

_submit_GGR.sh_ — Submits the GammaGateR Slurm array job (one task per unique SampleID) and automatically chains knit_GGR_Diagnostics.sbatch as a dependent job that runs only after all array tasks succeed.

_run_GGR.sbatch_ — Sbatch spec for a single GammaGateR array task; enforces single-threaded BLAS to prevent over-subscription and calls 02-run_GGR.R via Rscript --vanilla.

_knit_GGR_Diagnostics.sbatch_ — Sbatch job that renders 03-GGR_Diagnostics.Rmd after the array job completes, writing the diagnostic HTML to results/GammaGateR/<RUN_ID>/.

