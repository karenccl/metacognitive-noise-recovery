# Fig. g2_ppp (v2 extension 2; report Fig. 7, paper Fig. 4): replicated-data
# posterior predictive p-values for the 48 stored G2 fits and flag rates.
# Drawn from the CSVs written by code/04_ppc_and_comparison/g2_ppp_fullfits.R
# (which sources this script at the end); no fits needed.
#
# Run from the project root: Rscript code/05_figures/fig_g2_ppp.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
source(here::here("code", "05_figures", "fig_helpers.R"))
out_data <- here::here("data", "processed", "v2")
out_fig  <- here::here("outputs", "figures", "v2")
dir.create(out_fig, recursive = TRUE, showWarnings = FALSE)
by_fit <- readr::read_csv(file.path(out_data, "g2_ppp_by_fit.csv"), show_col_types = FALSE)
summary_tbl <- readr::read_csv(file.path(out_data, "g2_ppp_summary.csv"), show_col_types = FALSE)
stats <- c("stat1_rmse", "stat2_highconf", "stat3_x2_df")
primary <- list(verdict = summary_tbl$verdict[summary_tbl$analysis == "primary"][1])

stat_labels <- c(stat1_rmse = "1. Aggregate RMSE (primary)", stat2_highconf = "2. High-confidence (secondary)",
                 stat3_x2_df = "3. Pearson X2/df (secondary)")
long <- by_fit |>
  tidyr::pivot_longer(dplyr::starts_with("p_stat"), names_to = "statistic", values_to = "p") |>
  dplyr::mutate(statistic = factor(stat_labels[sub("^p_", "", statistic)], levels = stat_labels),
                cell = factor(cell, levels = unique(by_fit$cell)),
                family = ifelse(fit_variant == "correct", "Correct (Gumbel-min)", "Gaussian"))
pA <- ggplot(long, aes(x = cell, y = p, color = family)) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "grey40") +
  geom_point(position = position_dodge(width = 0.5), size = 1.8, alpha = 0.85) +
  scale_color_manual(values = c("Correct (Gumbel-min)" = "#009E73", "Gaussian" = "#D55E00")) +
  facet_wrap(~statistic, ncol = 1) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(subtitle = "A. Replicated-data posterior predictive p-value per fit (2 datasets per cell;\ndashed = 0.05, below = flagged)",
       x = NULL, y = "p-value", color = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top")

bars <- dplyr::bind_rows(
  summary_tbl |> dplyr::filter(analysis == "primary", split == "all", statistic %in% stats) |>
    dplyr::mutate(label = paste0(stat_labels[statistic], "\n", ifelse(fit_variant == "correct", "correct (false alarm)", "Gaussian"))),
  summary_tbl |> dplyr::filter(statistic %in% c("oracle_stat1_ext1", "loo_2se")) |>
    dplyr::mutate(label = ifelse(statistic == "loo_2se", "LOO > 2 SE\n(same 24 datasets)", "Oracle, stat 1\n(extension 1)"))
)
bars$label <- factor(bars$label, levels = rev(unique(bars$label)))
pB <- ggplot(bars, aes(x = label, y = rate, fill = fit_variant)) +
  geom_col(width = 0.7) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.2, na.rm = TRUE) +
  geom_text(aes(label = sprintf("%d/%d", n_flagged, n_fits), y = pmax(rate, hi, na.rm = TRUE) + 0.02),
            size = if (fig_submission) 2.4 else 3, hjust = 0) +
  scale_fill_manual(values = c(correct = "#009E73", misspecified = "#D55E00"), guide = "none") +
  coord_flip(ylim = c(0, if (fig_submission) 1.25 else 1.1)) +
  labs(subtitle = paste0("B. Flag rates (Wilson 95% CI), with the oracle and LOO\n",
                         "on the same 24 datasets. Pre-specified verdict: ", primary$verdict, "."),
       x = NULL, y = "Proportion flagged") +
  theme_minimal()

g <- gridExtra::arrangeGrob(print_ready(pA), print_ready(pB), ncol = 2, widths = c(1.1, 1))
save_fig(g, file.path(out_fig, "fig_g2_ppp.png"), width = 15, height = 9,
         sub_name = "Fig4", sub_height_mm = 150)
cat("Wrote outputs/figures/v2/fig_g2_ppp.png\n")
