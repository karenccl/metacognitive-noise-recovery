.PHONY: all setup grid g0 g1 g2 compile figures test clean

RSCRIPT := Rscript

all: setup grid g0 g1 g2 compile figures

setup:
	$(RSCRIPT) code/00_setup/00_packages.R
	$(RSCRIPT) code/00_setup/01_config.R

grid:
	$(RSCRIPT) code/00_setup/02_create_grid.R

# Per-cell runs are resumable: run_one_cell.R checks for existing output
# before simulating/fitting, so re-invoking these targets is safe.
g0:
	$(RSCRIPT) code/02_fit/run_grid.R --generator g0

g1:
	$(RSCRIPT) code/02_fit/run_grid.R --generator g1

g2:
	$(RSCRIPT) code/02_fit/run_grid.R --generator g2

compile:
	$(RSCRIPT) code/03_recovery_analysis/compile_results.R

figures:
	$(RSCRIPT) code/05_figures/fig_1_design.R
	$(RSCRIPT) code/05_figures/fig_2_g0_validation.R
	$(RSCRIPT) code/05_figures/fig_3_g1_ordinal_recovery.R
	$(RSCRIPT) code/05_figures/fig_4_g2_misspecification.R
	$(RSCRIPT) code/05_figures/fig_5_ppc.R

test:
	$(RSCRIPT) -e 'testthat::test_dir("tests")'

clean:
	rm -rf data/interim/*
