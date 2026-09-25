# Fig 2: G0 known-parameter recovery (protocol sections 3.1, 6.1, 6.4).
# Generator: G0 (Gaussian meta-d' model). Fitted model: hierarchical
# hmetad, normal(0,1) log_M prior, K=4. Estimand: population-level
# log_M (known truth -1). Uncertainty: per-replicate error shown as raw
# points (all 20 per condition, failed fits shown with a distinct shape,
# never suppressed) plus condition mean; coverage shown with Wilson 95%
# CIs and the pooled-across-cells estimate.
#
# Run from the project root: Rscript code/05_figures/fig_2_g0_validation.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

okabe <- c(orange = "#E69F00", sky = "#56B4E9", green = "#009E73", blue = "#0072B2", vermillion = "#D55E00")
log_M_truth <- -1

compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
cov_summary <- readr::read_csv(here::here("data", "processed", "g0_recovery_summary.csv"), show_col_types = FALSE)
pooled <- readr::read_csv(here::here("data", "processed", "g0_pooled_coverage.csv"), show_col_types = FALSE)

g0 <- compiled |>
  dplyr::filter(generator == "g0", status %in% c("pass", "fail")) |>
  dplyr::mutate(
    error = log_M_mean - log_M_truth,
    condition = sprintf("N=%d, T=%d", n_participants, n_trials),
    dprime_label = factor(sprintf("d' = %s", dprime_target), levels = c("d' = 0.75", "d' = 1.5")),
    status = factor(status, levels = c("pass", "fail"))
  )

cond_levels <- unique(g0$condition[order(g0$n_participants, g0$n_trials)])
g0$condition <- factor(g0$condition, levels = cond_levels)

cov_summary <- cov_summary |>
  dplyr::mutate(
    condition = factor(sprintf("N=%d, T=%d", n_participants, n_trials), levels = cond_levels),
    dprime_label = factor(sprintf("d' = %s", dprime_target), levels = c("d' = 0.75", "d' = 1.5"))
  )

n_fail <- sum(g0$status == "fail")

p_bias <- ggplot(g0, aes(x = condition, y = error)) +
  geom_hline(yintercept = 0, color = "grey40") +
  geom_jitter(aes(shape = status, color = dprime_label), width = 0.15, alpha = 0.6, size = 1.8, show.legend = c(color = FALSE, shape = TRUE)) +
  stat_summary(fun = mean, geom = "point", shape = 95, size = 8, color = "black") +
  facet_wrap(~dprime_label) +
  scale_color_manual(values = c("d' = 0.75" = okabe[["orange"]], "d' = 1.5" = okabe[["blue"]])) +
  scale_shape_manual(values = c(pass = 16, fail = 4), drop = FALSE) +
  labs(
    title = "G0 recovery of known log_M (truth = -1)",
    subtitle = sprintf("Per-replicate posterior-mean error, 20 replications per condition (black bar = mean).\n%d of 240 fits flagged 'fail' are kept and shown as x.", n_fail),
    x = NULL, y = "Error: posterior mean log_M - truth", shape = "Fit status"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom")

p_cov <- ggplot(cov_summary, aes(x = condition, y = coverage)) +
  geom_hline(yintercept = 0.95, linetype = "dashed", color = "grey40") +
  geom_hline(yintercept = pooled$coverage, color = okabe[["vermillion"]]) +
  geom_pointrange(aes(ymin = coverage_ci_low, ymax = coverage_ci_high, color = dprime_label), size = 0.5) +
  annotate("text", x = 0.6, y = 0.53, hjust = 0, color = okabe[["vermillion"]], size = 3.2,
           label = sprintf("pooled: %.1f%% [%.1f, %.1f] (MCSE %.1f%%)", pooled$coverage * 100,
                            pooled$coverage_ci_low * 100, pooled$coverage_ci_high * 100, pooled$mcse * 100)) +
  facet_wrap(~dprime_label) +
  scale_color_manual(values = c("d' = 0.75" = okabe[["orange"]], "d' = 1.5" = okabe[["blue"]]), guide = "none") +
  coord_cartesian(ylim = c(0.5, 1.02)) +
  labs(
    subtitle = "95% credible-interval coverage per condition (Wilson 95% CI, n=20 each; dashed = nominal 95%)",
    x = NULL, y = "Coverage of true log_M"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

g <- gridExtra::arrangeGrob(p_bias, p_cov, ncol = 1, heights = c(1.15, 1))
ggsave(here::here("outputs", "figures", "fig_2_g0_validation.png"), g, width = 9, height = 9.5, dpi = 200)
cat("Wrote outputs/figures/fig_2_g0_validation.png\n")
