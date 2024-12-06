# SCORPIO
## Simulated single-Cell Omics with Realistic Phenotypes and Integrated Outcomes

Given the current limitation of single-cell simulation packages which often are not designed to address the association with clinical variables, we developed and employed a flexible simulation strategy. This approach generates single-cell datasets along with corresponding metadata—including disease status, cell type, subject, batch, as well as age and sex when necessary—specifically tailored to evaluate CellPhenoX. This approach is able to create simulated single-cell cell count data, followed by varying levels of differential cluster abundance.

The SCORPIO package helps benchmark the performance of [CellPhenoX](https://github.com/fanzhanglab/pyCellPhenoX).

This code was initially developed by [Dr. Jun Inamo](https://github.com/juninamo/S2EQTL).

## Usage
Run the `simulation_benchmark.sh` script to automize the generation of the datasets.
For example, 
```bash
$ cd src
$ bash simulation_benchmark.sh
```