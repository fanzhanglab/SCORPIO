#!/bin/bash

## declare arrays
declare -a num_samples=(30) ## 10 20
declare -a fold_changes=(0.1 3) ## 0.75 1.5

## loop through the above array and generate datasets
for num_samp in "${num_samples[@]}"; do
    echo "$num_samp"
    for fold_change in "${fold_changes[@]}"; do
        echo "$fold_change"
        RScript simulation_bench.R "$num_samp" "$fold_change"
    done
done

# eval "$(conda shell.bash hook)"
# conda activate /Users/zhanglab_mac2/Library/CloudStorage/OneDrive-TheUniversityofColoradoDenver/Zhang_Lab/Research/shap/.conda

# ## then run the CellPhenoX Python script
# python3 ./xcell_functions/main.py