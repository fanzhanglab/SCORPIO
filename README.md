# SCORPIO
## Simulated single-Cell Omics with Realistic Phenotypes and Integrated Outcomes

Given the current limitation of single-cell simulation packages which often are not designed to address the association with clinical variables, we developed and employed a flexible simulation strategy. This approach generates single-cell datasets along with corresponding metadata—including disease status, cell type, subject, batch, as well as age and sex when necessary—specifically tailored to evaluate CellPhenoX. This approach is able to create simulated single-cell cell count data, followed by varying levels of differential cluster abundance.

The SCORPIO package helps benchmark the performance of [CellPhenoX](https://github.com/fanzhanglab/pyCellPhenoX).

This code was developed by [Jun Inamo](https://github.com/juninamo) and Jade Young.

## Simulation Framework Details

Our simulation framework operates in two primary stages: 1) Generation of single-cell metadata, including subject-level variables and cell type abundances, and 2) Simulation of a high-dimensional feature matrix whose variance is controllably partitioned across different biological and technical factors.

### 1\. Simulation of Metadata and Cell Type Abundance

The simulation begins by generating a metadata table for a specified number of subjects (`n_individuals`). This process is governed by the `generate_dummy_metadata` function.

  * **Subject-Level Covariates:** For each subject, we simulate key clinical and technical variables. Categorical variables such as disease status (`disease`) and `sex` are sampled based on user-defined proportions (`prop_disease`, `prop_sex`). Continuous variables like `age` and `bmi` are sampled uniformly from a specified range. Technical variables, such as `batch`, are assigned to subjects to simulate batch effects.
  * **Baseline Cell Abundance:** We simulate a hierarchy of cell types, categorized as 'major' and 'rare'. For each subject, the baseline number of cells for each cell type is drawn from a uniform distribution. The range of this distribution is determined by a baseline cell count (`n_cells`) and its standard deviation (`sd_celltypes`) for major types, and scaled by a `relative_abundance` parameter for rare types.
  * **Inducing Differential Abundance:** To simulate disease-associated changes in cell populations, we introduce a "fold change" increase (`fc_increase`) in the abundance of specific cell types. This is achieved by adding a calculated number of additional cells from the designated "differentially abundant" cell types exclusively to the subjects in the 'case' (disease=1) group. This directly models the expansion of specific cell populations in response to the disease condition. The function `generate_dummy_data_woInteraction` provides an alternative mechanism for manipulating cell counts based on disease status.

### 2\. Simulation of High-Dimensional Feature Space

The core of our simulation is the generation of a realistic single-cell feature matrix, where each feature represents a molecular measurement (e.g., a gene or a PC). This process, handled by the `generate_pseudo_features` function, is based on a linear model of Gaussian-distributed components, which aligns with the Gaussian Mixture Model structure mentioned in the manuscript.

The value of each feature for each cell is modeled as a weighted linear combination of multiple underlying signals plus random noise:

$$ \text{Feature}_j = \sum_{i=1}^{k} w_{i,j} \cdot \text{Signal}_i + w_{\text{noise},j} \cdot \text{Noise} $$

where for a given feature $j$:

  * $\text{Signal}_i$ is a vector of values across all cells representing a specific source of variation (e.g., cell type, disease status, sex, age, batch).
  * $w_{i,j}$ is the weight or 'ratio' for that signal, controlling the proportion of variance in Feature $j$ attributable to Factor $i$.
  * $\text{Noise}$ is a vector of random Gaussian noise.

The generation of each feature involves these steps:

1.  **Generation of Pure Signals:** For each factor (e.g., `cluster`, `disease`, `sex`), a "pure" signal vector is generated. This is done by drawing random values from a Gaussian distribution where the mean is systematically varied according to the cell's label for that factor. For instance, for the `cell_type` signal, cells belonging to Cluster A will be assigned values from a normal distribution with a different mean than cells in Cluster B. This ensures the signal is highly specific to the factor it represents.
2.  **Weighted Combination:** Each pure signal, as well as a pure noise signal, is scaled to have a mean of 0 and a standard deviation of 1. They are then combined using the user-defined ratio parameters (e.g., `cluster_ratio`, `disease_ratio`, `batch_ratio`). These ratios dictate the contribution of each factor to the final feature's variance. For example, setting `disease_ratio = 0.4` for a feature ensures that disease status is a primary driver of that feature's expression.
3.  **Flexibility:** This approach allows us to create a complex dataset where different features are influenced by different combinations of factors. For instance, we can simulate features that are primarily driven by cell type identity, others driven by batch effects, and critically, specific features that are driven by disease status or the interaction between disease and another covariate.

### Core Assumptions of the Simulation Framework

The design of our simulation framework relies on the following key assumptions:

  * **Distributional Assumptions:**

      * The feature values generated for each underlying biological or technical factor, as well as the residual noise, are assumed to follow a Gaussian distribution.
      * The final simulated features, being a linear combination of these Gaussian components, are also implicitly Gaussian.
      * The baseline cell counts for each subject are assumed to be drawn from a uniform distribution within a specified range.

  * **Model Structure Assumptions:**

      * The effects of different biological and technical factors on feature expression are linear and additive. The framework does not inherently model non-linear relationships or complex interactions between covariates unless explicitly specified.
      * Sources of variation (e.g., cell type, disease, batch) are modeled as statistically independent components that are mixed together. The initial sampling of subject-level metadata does not impose a correlation between variables like age and disease status, for instance.

  * **Biological Assumptions:**

      * Differential cell abundance in a disease state is modeled as a uniform increase in the number of cells for specific cell types within all individuals in the case group.
      * The influence of a factor (e.g., disease status) on a cell's feature expression is assumed to be consistent for all cells sharing that factor label.

## Usage
Run the `simulation_benchmark.sh` script to automize the generation of the datasets.
For example, 
```bash
$ cd src
$ bash simulation_benchmark.sh
```

## Contact

For questions or suggestions regarding the SCORPIO simulation framework and code, please contact **Jun Inamo** _[jun.inamo@cuanschutz.edu]_ or **Jade Young** _[jade.young@cuanschutz.edu]_

For questions regarding the CellPhenoX publication and methodology, please contact [Fan Zhang](https://fanzhanglab.org/).
