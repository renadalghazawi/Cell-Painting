#!/bin/bash
#
# CREATED USING THE BIOHPC PORTAL on Wed Apr 19 2023 11:09:11 GMT-0600 (Mountain Daylight Time)
#
# This file is a batch script used to run commands on the BioHPC cluster.
# The script is submitted to the cluster using the SLURM `sbatch` command.
# Lines starting with # are comments, and will not be run.
# Lines starting with #SBATCH specify options for the scheduler.
# Lines that do not start with # or #SBATCH are commands that will run.

# Name for the job that will be visible in the job queue and accounting tools.
#SBATCH --job-name CellprofilerCellPaintingNode

# Name of the SLURM partition that this job should run on.
#SBATCH -p 512GB       # partition (queue)
# Number of nodes required to run this job
#SBATCH -N 1

# Memory (RAM) requirement/limit in MB.
#SBATCH --mem 501760	  # Memory Requirement (MB)

# Time limit for the job in the format Days-H:M:S
# A job that reaches its time limit will be cancelled.
# Specify an accurate time limit for efficient scheduling so your job runs promptly.
#SBATCH -t 7-23:0:00

# The standard output and errors from commands will be written to these files.
# %j in the filename will be replaced with the job number when it is submitted.
#SBATCH -o job_%j_CellProfiler.out
#SBATCH -e job_%j_CellProfiler.err

# Send an email when the job status changes, to the specified address.
#SBATCH --mail-type ALL
#SBATCH --mail-user renad.ghazawi@utsouthwestern.edu

module load nextflow/22.04.5 singularity/3.5.3

# Section for variables to edit:
BATCHID=29990313_renad_test

date
echo "CellProfiler analysis for:"
echo "BATCHID: ${BATCHID}"
# COMMAND GROUP 1
nextflow run dsl2.nf --batch 29990313_renad_test --cellprofanalysis /project/shared/gcrb_igvf/htscore/workspace/pipelines/Cell_Painting_Analysis_IGVF_loaddata.cppipe -profile singularity -w work/biochemistry/s230860/work --userid s230860 #-resume

