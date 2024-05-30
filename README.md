# Cell Painting Pipeline

This repository contains a Cell Painting pipeline that was originally developed as separate scripts for running on AWS. It has been rewritten into two Nextflow pipelines to facilitate easier execution on an HPC environment. Additionally, this repository includes scripts that simplify various analysis steps for the IGVF Cell Painting Consortium.

## Overview

### Purpose
These pipelines and scripts are configured for compound-based experiments. However, the high-throughput screening core facility is transitioning into CRISPRi and CRISPRa for cardiac cells. If any assumptions or requirements change for generating the appropriate files, these scripts will be updated accordingly.

### Sections
The repository is organized into several sections:

- **Preparing_For_CellProfiler**
  - **generate_load_data.sh**: Generates the `load_data.csv` file for illumination correction.
  - **generate_load_data_with_illum.sh**: Generates the `load_data_with_illum.csv` file for analysis.
  
- **Preparing_For_Cytominer**
  - **aggregate_data.r**: Aggregates data into the median value for the well position.
  - **merge_aggregated_data.r**: Merges files together for Cytominer analysis.
  
- **Plotting_Results**
  - **plot_cp_results.r**: Plots results of the CellProfiler data.
  - **plot_cytominer_results.r**: Plots results of the Cytominer data.

## Getting Started

### Prerequisites
- Nextflow
- Singularity (for containerized execution)
- An HPC environment with SLURM scheduler
- R (for R scripts)
- CellProfiler

### Installation

1. Clone the repository:
   ```sh
   git clone git@github.com:your-username/Cell-Painting.git
   cd Cell-Painting

2. Set up the environment:
   Ensure that Nextflow and Singularity are installed and configured on your HPC environment.


If you would like to contribute to this project, please submit a pull request or open an issue on GitHub.
