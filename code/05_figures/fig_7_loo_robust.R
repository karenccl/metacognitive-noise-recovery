# Fig. 7 (v3 step 2): PSIS-LOO vs exact-refit LOO on the 24 stored G2 pairs.
# A: diff = elpd(correct) - elpd(Gaussian) under both, with y = x. B: share of
# participants with Pareto k > 0.7 by cell (all 480 fits).
#
# Run from the project root: Rscript code/05_figures/fig_7_loo_robust.R

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
source(here::here("code", "05_figures", "fig_helpers.R"))
p <- readr::read_csv(here::here("data", "processed", "v3", "g2_loo_psis_vs_exact_by_pair.csv"),
                     show_col_types = FALSE) |>
  mutate(refit = if_else(n_bad_k_correct + n_bad_k_mis > 0, "some participants refitted", "no k > 0.7"))
s <- readr::read_csv(here::here("data", "processed", "v3", "g2_loo_psis_vs_exact_summary.csv"),
                     show_col_types = FALSE)
pA <- ggplot(p, aes(diff_psis, diff_exact, shape = refit, colour = factor(n_participants))) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey40") +
  geom_hline(yintercept = 0, colour = "grey80") + geom_vline(xintercept = 0, colour = "grey80") +
  geom_point(size = 2.2) +
  scale_colour_manual(values = c("20" = "#E69F00", "40" = "#0072B2")) +
  scale_shape_manual(values = c("some participants refitted" = 16, "no k > 0.7" = 1)) +
  labs(subtitle = sprintf(paste0("A. ELPD difference (correct - Gaussian), 24 stored pairs\n",
                                 "%d exact refits; > 2 SE agreement %d/%d; median |change| %.3f"),
                          s$n_refits, round(s$twose_agreement * s$n_pairs), s$n_pairs, s$median_abs_change),
       x = "PSIS-LOO", y = "Exact refit (reloo)", colour = "N", shape = NULL) +
  theme_minimal() + theme(legend.position = "top", legend.box = "vertical")

k <- readr::read_csv(here::here("data", "processed", "v3", "g2_pareto_k_by_cell.csv"), show_col_types = FALSE) |>
  mutate(cell = sprintf("N=%d, T=%d, d'=%s", n_participants, n_trials, dprime_target),
         fit = if_else(fit_variant == "correct", "Correct (Gumbel-min)", "Gaussian"))
k$cell <- factor(k$cell, levels = unique(k$cell[order(k$n_participants, k$n_trials, k$dprime_target)]))
pB <- ggplot(k, aes(cell, prop_obs_bad, fill = fit)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = c("Correct (Gumbel-min)" = "#009E73", "Gaussian" = "#D55E00")) +
  labs(subtitle = "B. Share of participants with Pareto k > 0.7 (all 480 G2 fits)",
       x = NULL, y = "Proportion of LOO observations", fill = NULL) +
  theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top")

dir.create(here::here("outputs", "figures", "v3"), recursive = TRUE, showWarnings = FALSE)
g <- gridExtra::arrangeGrob(print_ready(pA), print_ready(pB), ncol = 2, widths = c(1, 1.2))
save_fig(g, here::here("outputs", "figures", "v3", "fig_7_loo_robust.png"), width = 13, height = 6,
         sub_name = "FigS4", sub_height_mm = 105)
cat("Wrote outputs/figures/v3/fig_7_loo_robust.png\n")
