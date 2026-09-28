.PHONY: all setup grid g0 g1 g2 compile analyse robustness figures test clean

RSCRIPT := Rscript

# run order matches the production run (G1 first); `robustness` is long-running
# (~20 min prior sweep + ~75 min K=6 refits) and is kept out of `all`.
all: setup grid g1 g0 g2 compile analyse figures

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

analyse:
	$(RSCRIPT) code/03_recovery_analysis/compute_primary_metrics.R
	$(RSCRIPT) code/04_ppc_and_comparison/loo_comparison.R
	$(RSCRIPT) code/04_ppc_and_comparison/diagnostics_summary.R
	$(RSCRIPT) code/04_ppc_and_comparison/ppc_joint_counts.R
	$(RSCRIPT) code/03_recovery_analysis/bias_diagnostics.R

# Refits (need rstan and a C++ toolchain): prior-width sweep and K=6 binning check.
robustness:
	$(RSCRIPT) code/03_recovery_analysis/prior_sensitivity.R
	$(RSCRIPT) code/03_recovery_analysis/sensitivity_binning.R

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
