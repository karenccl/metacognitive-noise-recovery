# Fig. 6 (v3 step 1): misspecification effect on log_M, paired on the same
# simulated dataset. A: delta_mis = log_M(Gaussian) - log_M(correct) per cell
# (mean +/- 2 MCSE) against trials per participant. B: baseline error of the
# correct fit next to the G0 bias in the same cell.
#
# Run from the project root: Rscript code/05_figures/fig_6_relative_bias.R

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
source(here::here("code", "05_figures", "fig_helpers.R"))
okabe_d <- c("0.75" = "#E69F00", "1.5" = "#0072B2")

d <- readr::read_csv(here::here("data", "processed", "v3", "g2_relative_bias_by_cell.csv"),
                     show_col_types = FALSE) |> filter(analysis == "primary")
pooled <- readr::read_csv(here::here("data", "processed", "v3", "g2_dprime_contrast_pooled.csv"),
                          show_col_types = FALSE)
pA <- ggplot(d, aes(n_trials, delta_mean, colour = factor(dprime_target),
                    shape = factor(n_participants))) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = delta_mean - 2 * delta_mcse, ymax = delta_mean + 2 * delta_mcse),
                  position = position_dodge(width = 0.15)) +
  scale_x_continuous(trans = "log2", breaks = c(100, 200, 400)) +
  scale_colour_manual(values = okabe_d) +
  labs(subtitle = sprintf(paste0("A. Misspecification shift, same dataset (mean ± 2 MCSE, 20 reps)\n",
                                 "d' contrast (low - high): %+.3f (SE %.3f), positive in %d/%d cells"),
                          pooled$diff_low_minus_high, pooled$se_diff, pooled$n_cells_positive, pooled$n_cells),
       x = "Trials per participant (log scale)",
       y = expression(Delta[mis] ~ "= log M (Gaussian) - log M (correct)"),
       colour = "d'", shape = "N") +
  theme_minimal() + theme(legend.position = "top")

b <- readr::read_csv(here::here("data", "processed", "v3", "g2_baseline_vs_g0.csv"), show_col_types = FALSE) |>
  tidyr::pivot_longer(c(base_mean, g0_bias), names_to = "source", values_to = "bias") |>
  mutate(mcse = if_else(source == "base_mean", base_mcse, g0_mcse),
         source = recode(source, base_mean = "G2, correct (Gumbel) fit", g0_bias = "G0 (Gaussian data, Gaussian fit)"),
         cell = factor(sprintf("N=%d, T=%d, d'=%s", n_participants, n_trials, dprime_target)))
b$cell <- factor(b$cell, levels = unique(b$cell[order(b$n_participants, b$n_trials, b$dprime_target)]))
pB <- ggplot(b, aes(cell, bias, colour = source)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = bias - 2 * mcse, ymax = bias + 2 * mcse), position = position_dodge(width = 0.5)) +
  scale_colour_manual(values = c("G2, correct (Gumbel) fit" = "#009E73", "G0 (Gaussian data, Gaussian fit)" = "#999999")) +
  labs(subtitle = "B. Baseline error of correctly specified fits (mean ± 2 MCSE)",
       x = NULL, y = "log M error (estimate - truth)", colour = NULL) +
  theme_minimal() + theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top") +
  (if (fig_submission) guides(colour = guide_legend(nrow = 2)))

dir.create(here::here("outputs", "figures", "v3"), recursive = TRUE, showWarnings = FALSE)
g <- gridExtra::arrangeGrob(print_ready(pA), print_ready(pB), ncol = 2, widths = c(1, 1.1))
save_fig(g, here::here("outputs", "figures", "v3", "fig_6_relative_bias.png"), width = 13, height = 5.5,
         sub_name = "Fig2", sub_height_mm = 95)
cat("Wrote outputs/figures/v3/fig_6_relative_bias.png\n")
