# Fig. 10 (v3b): spurious log_M group differences when groups differ only in d'.
# A: false-positive rate by N x T, separate fits (work package B), correct vs Gaussian.
# B: posterior mean of the group difference, single two-group model (work package C).
# Panels combined with gridExtra, as in figs 6-9 (the plan's patchwork is not in renv.lock).
#
# Run from the project root: Rscript code/05_figures/fig_10_dprime_confound.R
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
source(here::here("code", "05_figures", "fig_helpers.R"))
okabe_v <- c(correct = "#009E73", misspecified = "#D55E00")
lab_v   <- c(correct = "Correct (Gumbel-min)", misspecified = "Gaussian (misspecified)")

b <- readr::read_csv(here::here("data", "processed", "v3b", "b_dprime_confound_by_cell.csv"),
                     show_col_types = FALSE) |>
  filter(analysis == "primary") |>
  mutate(fpr_lo = pmax(fpr_lo, 0))          # Wilson lower limit is -1e-17 when k = 0
pA <- ggplot(b, aes(n_trials, fpr, colour = fit_variant, shape = factor(n_participants))) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = fpr_lo, ymax = fpr_hi), position = position_dodge(width = 0.2)) +
  scale_x_continuous(trans = "log2", breaks = c(100, 200, 400)) +
  scale_colour_manual(values = okabe_v, labels = lab_v) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(subtitle = "A. Separate fits per group: 95% CrI of the difference excludes 0",
       x = "Trials per participant (log scale)", y = "False-positive rate (Wilson 95% CI)",
       colour = NULL, shape = "N per group") +
  theme_minimal() + theme(legend.position = "top", legend.box = "vertical")

c2 <- readr::read_csv(here::here("data", "processed", "v3b", "c_two_group_by_fit.csv"),
                      show_col_types = FALSE) |> filter(status %in% c("pass", "fail"))
pB <- ggplot(c2, aes(fit_variant, diff_mean, colour = fit_variant)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = diff_q025, ymax = diff_q975, alpha = excl0),
                  position = position_jitter(width = 0.25, seed = 1)) +
  scale_alpha_manual(values = c(`FALSE` = 0.35, `TRUE` = 1), name = "CrI excludes 0") +
  scale_colour_manual(values = okabe_v, labels = lab_v, guide = "none") +
  scale_x_discrete(labels = lab_v) +
  labs(subtitle = "B. One model with a group effect (N = 20 + 20, T = 200)",
       x = NULL, y = "log M (high d') - log M (low d'); truth = 0") +
  theme_minimal() + theme(legend.position = "top")

dir.create(here::here("outputs", "figures", "v3b"), recursive = TRUE, showWarnings = FALSE)
g <- gridExtra::arrangeGrob(print_ready(pA), print_ready(pB), ncol = 2, widths = c(1.4, 1))
save_fig(g, here::here("outputs", "figures", "v3b", "fig_10_dprime_confound.png"), width = 11, height = 4.5, dpi = 300,
         sub_name = "Fig3", sub_height_mm = 85)
cat("Wrote outputs/figures/v3b/fig_10_dprime_confound.png\n")
