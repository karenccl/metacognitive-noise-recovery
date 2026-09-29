.PHONY: all setup calibrate grid g0 g1 g2 compile analyse robustness figures test clean \n	v3-relbias v3-reloo v3-g3 v3-empirical-screen v3-empirical-fit v3-empirical-summary v3-figures

RSCRIPT := Rscript

# run order matches the production run (G1 first); `robustness` is long-running
# (~20 min prior sweep + ~75 min K=6 refits) and is kept out of `all`.
all: setup calibrate grid g1 g0 g2 compile analyse figures

setup:
	$(RSCRIPT) code/00_setup/00_packages.R
	$(RSCRIPT) code/00_setup/01_config.R

# DDM drift calibration and sigma_c pilot (under a minute). Regenerates
# outputs/tables/ddm_calibration.csv and sigma_c_pilot.csv, the source of the
# locked ddm: values in config/design.yml (copied by hand, not read back).
calibrate:
	$(RSCRIPT) code/01_simulate/validate_generators.R

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
	$(RSCRIPT) code/04_ppc_and_comparison/g2_ppc_all.R
	$(RSCRIPT) code/04_ppc_and_comparison/g2_ppp_fullfits.R  # ~15 min; needs stored full fits (reps 1-2)
	$(RSCRIPT) code/03_recovery_analysis/bias_diagnostics.R
	$(RSCRIPT) code/03_recovery_analysis/prior_summary.R

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

# ---- v3 enhancement (docs/v3_plan.md; constants in config/v3.yml) ----------
# Long targets are resumable and shown single-process; shard them by running
# the shard scripts with <shard> <n_shards> in several terminals instead.
v3-relbias:
	$(RSCRIPT) code/03_recovery_analysis/relative_bias.R

v3-reloo:   # ~1.5 h at 3 shards; needs stored full fits (reps 1-2)
	$(RSCRIPT) code/04_ppc_and_comparison/v3_reloo_stored_fits.R 1 1
	$(RSCRIPT) code/04_ppc_and_comparison/v3_loo_robust_summary.R

v3-g3:      # 160 fits, ~6-7 h at 4 shards
	$(RSCRIPT) code/00_setup/03_create_grid_g3.R
	$(RSCRIPT) code/02_fit/run_g3_shard.R 1 1
	$(RSCRIPT) code/04_ppc_and_comparison/v3_g3_summary.R

# Needs data/raw/confidence_db/ (docs/data_access_confidence_db.md) and the G3 verdict.
v3-empirical-screen:
	$(RSCRIPT) code/06_empirical/01_screen_datasets.R
	$(RSCRIPT) code/06_empirical/02_select_datasets.R
	$(RSCRIPT) code/06_empirical/03_prepare_datasets.R

v3-empirical-fit:
	$(RSCRIPT) code/06_empirical/run_empirical_shard.R 1 1
	$(RSCRIPT) code/06_empirical/05_loo_repair.R 1 1
	$(RSCRIPT) code/06_empirical/06_ppc_dataset.R

v3-empirical-summary:
	$(RSCRIPT) code/06_empirical/07_summarise_empirical.R

v3-figures:
	$(RSCRIPT) code/05_figures/fig_6_relative_bias.R
	$(RSCRIPT) code/05_figures/fig_7_loo_robust.R
	$(RSCRIPT) code/05_figures/fig_8_g3_mixture.R
	$(RSCRIPT) code/05_figures/fig_9_empirical.R
