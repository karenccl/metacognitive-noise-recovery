# Fig 4: G2 correct-vs-misspecified comparison (protocol sections 3.3,
# 6.3, 6.4). Generator: G2 (Gumbel-min signal distribution, known
# log_M = -1). Fitted: hierarchical hmetad under the correct Gumbel-min
# family vs. the misspecified default Gaussian family, both fit to the
# SAME simulated dataset per replicate. Panel A: paired LOO/ELPD
# difference (correct - misspecified; one LOO observation = one
# participant's aggregated count vector, NOT a trial). Panel B: raw
# per-replicate log_M error under each fit. All replicates shown; fails
# kept (x). Pareto-k caveat in caption (12.0%/8.2% of LOO observations
# have k > 0.7).
#
# Run from the project root: Rscript code/05_figures/fig_4_g2_misspecification.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

okabe <- c(correct = "#009E73", misspecified = "#D55E00")
log_M_truth <- -1

elpd <- readr::read_csv(here::here("data", "processed", "g2_elpd_comparison.csv"), show_col_types = FALSE)
compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
pareto <- readr::read_csv(here::here("data", "processed", "g2_pareto_k_summary.csv"), show_col_types = FALSE)

cond_label <- function(n, t, d) sprintf("N=%d,T=%d,d'=%s", n, t, d)

elpd <- elpd |>
  dplyr::mutate(condition = cond_label(n_participants, n_trials, dprime_target),
                cond_order = n_participants * 10000 + n_trials * 10 + dprime_target)
cond_levels <- unique(elpd$condition[order(elpd$cond_order)])
elpd$condition <- factor(elpd$condition, levels = cond_levels)
elpd$ok <- ifelse(elpd$status_correct == "pass" & elpd$status_misspecified == "pass", "both pass", "a fit flagged")

prop_correct <- mean(elpd$favors_correct)

pA <- ggplot(elpd, aes(x = condition, y = elpd_diff_correct_minus_mis)) +
  geom_hline(yintercept = 0, color = "grey40") +
  geom_jitter(aes(shape = ok), width = 0.15, alpha = 0.5, size = 1.4, color = okabe[["correct"]]) +
  stat_summary(fun = mean, geom = "point", shape = 95, size = 8, color = "black") +
  scale_shape_manual(values = c("both pass" = 16, "a fit flagged" = 4)) +
  labs(
    title = sprintf("Correct (Gumbel-min) model preferred by LOO in %.1f%% of 240 paired datasets", prop_correct * 100),
    subtitle = "A. Paired ELPD difference, correct - misspecified (positive = correct preferred); black bar = condition mean",
    x = NULL, y = "ELPD difference\n(participant-level LOO)", shape = NULL
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top")

err <- compiled |>
  dplyr::filter(generator == "g2", status %in% c("pass", "fail")) |>
  dplyr::mutate(
    error = log_M_mean - log_M_truth,
    condition = factor(cond_label(n_participants, n_trials, dprime_target), levels = cond_levels),
    fit_variant = factor(fit_variant, levels = c("correct", "misspecified")),
    status = factor(status, levels = c("pass", "fail"))
  )

pB <- ggplot(err, aes(x = condition, y = error, color = fit_variant)) +
  geom_hline(yintercept = 0, color = "grey40") +
  geom_point(aes(shape = status), position = position_jitterdodge(jitter.width = 0.1, dodge.width = 0.6),
             alpha = 0.4, size = 1.2) +
  stat_summary(aes(group = fit_variant), fun = mean, geom = "point", shape = 95, size = 8,
               position = position_dodge(width = 0.6)) +
  scale_color_manual(values = c(correct = okabe[["correct"]], misspecified = okabe[["misspecified"]]),
                     labels = c(correct = "Correct: Gumbel-min", misspecified = "Misspecified: Gaussian")) +
  scale_shape_manual(values = c(pass = 16, fail = 4), drop = FALSE) +
  labs(
    subtitle = "B. Per-replicate log_M error (posterior mean - truth of -1); bars = condition means",
    x = NULL, y = "log_M error", color = NULL, shape = "Fit status",
    caption = sprintf(
      "Generator: G2 Gumbel-min (mean-centred, unit variance). Both fits use the hierarchical hmetad model, K=4, normal(0,1) prior; 20 replications per condition.\nLOO unit = participant (aggregated counts). Pareto k > 0.7 in %.1f%% (correct) / %.1f%% (misspecified) of LOO observations: ELPD magnitudes are approximate, direction is robust.\nCross-distribution log_M comparison is within hmetad's parameterisation only, not a claim of identical substantive scale.",
      pareto$prop_obs_k_bad[pareto$fit_variant == "correct"] * 100,
      pareto$prop_obs_k_bad[pareto$fit_variant == "misspecified"] * 100
    )
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom",
        plot.caption = element_text(hjust = 0, size = 7.5))

g <- gridExtra::arrangeGrob(pA, pB, ncol = 1, heights = c(1, 1.15))
ggsave(here::here("outputs", "figures", "fig_4_g2_misspecification.png"), g, width = 10, height = 10, dpi = 200)
cat("Wrote outputs/figures/fig_4_g2_misspecification.png\n")
