# Fig 3: G1 ordinal recovery -- posterior log_M vs. sigma_c (protocol
# sections 3.2, 6.2, 6.4). Generator: G1 (DDM with post-decisional
# readout noise sigma_c). Fitted model: hierarchical static Gaussian
# hmetad, K=4. Primary estimand: ordering/monotonic slope of population
# log_M over sigma_c (NOT numerical recovery of sigma_c -- different
# scales, protocol section 1.2). Every replication is shown as a raw
# point (20 per sigma_c level per panel); failed fits would be shown as
# x (there are none in G1: 720/720 pass). Lines join per-level means.
#
# Run from the project root: Rscript code/05_figures/fig_3_g1_ordinal_recovery.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

okabe <- c(orange = "#E69F00", blue = "#0072B2")
cfg <- yaml::read_yaml(here::here("config", "design.yml"))
compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
metrics <- readr::read_csv(here::here("data", "processed", "g1_primary_metrics.csv"), show_col_types = FALSE)

g1 <- compiled |>
  dplyr::filter(generator == "g1") |>
  dplyr::mutate(
    sigma_c = unlist(cfg$ddm$sigma_c_values[sigma_c_level]),
    status = factor(status, levels = c("pass", "fail", "error")),
    dprime_label = factor(sprintf("d' = %s", dprime_target), levels = c("d' = 0.75", "d' = 1.5")),
    row_label = factor(sprintf("N = %d", n_participants)),
    col_label = factor(sprintf("T = %d", n_trials), levels = c("T = 100", "T = 200", "T = 400"))
  )

means <- g1 |>
  dplyr::group_by(row_label, col_label, dprime_label, sigma_c) |>
  dplyr::summarise(log_M_median = mean(log_M_median), .groups = "drop")

n_pass <- sum(g1$status == "pass"); n_fail <- sum(g1$status == "fail"); n_err <- sum(g1$status == "error")
n_neg <- sum(metrics$slope < 0)
ord_min <- min(metrics$ordering_accuracy)

p <- ggplot(g1, aes(x = sigma_c, y = log_M_median, color = dprime_label)) +
  geom_jitter(aes(shape = status), width = 0.06, alpha = 0.45, size = 1.3) +
  geom_line(data = means, aes(group = dprime_label), linewidth = 0.9) +
  geom_point(data = means, size = 2.2) +
  facet_grid(row_label ~ col_label) +
  scale_x_continuous(breaks = unlist(cfg$ddm$sigma_c_values), labels = c("0.29\n(low)", "0.87\n(med)", "2.91\n(high)"), trans = "log10") +
  scale_color_manual(values = c("d' = 0.75" = okabe[["orange"]], "d' = 1.5" = okabe[["blue"]])) +
  scale_shape_manual(values = c(pass = 16, fail = 4, error = 1), drop = FALSE) +
  labs(
    title = "Static log_M declines monotonically as confidence-readout noise increases (G1)",
    subtitle = sprintf(
      "Posterior median log_M per replication (points, 20 per sigma_c level) and level means (lines). Fits: %d pass, %d fail, %d error.\nExpected sign (negative slope) in %d/12 N x T x d' conditions; matched-rep ordering accuracy low>medium>high >= %.0f%% in every condition.",
      n_pass, n_fail, n_err, n_neg, ord_min * 100
    ),
    x = "Readout noise sigma_c (log scale; calibrated low / medium / high)",
    y = "Posterior median population log_M",
    color = NULL, shape = "Fit status",
    caption = "Generator: DDM + post-decisional readout noise. Fitted: hierarchical Gaussian meta-d' (hmetad), K=4, normal(0,1) prior. log_M is not on the sigma_c scale; only ordering is claimed."
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.caption = element_text(hjust = 0, size = 7.5),
        plot.subtitle = element_text(size = 9))

ggsave(here::here("outputs", "figures", "fig_3_g1_ordinal_recovery.png"), p, width = 10, height = 6.5, dpi = 200)
cat("Wrote outputs/figures/fig_3_g1_ordinal_recovery.png\n")
