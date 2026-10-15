# Fig. g2_ppc_all (v2 extension 1; report Fig. 6, paper Fig. S5): paired PPC
# discrepancies (misspecified / correct) and oracle-calibrated detection rates
# for all 240 G2 datasets. Drawn from the CSVs written by
# code/04_ppc_and_comparison/g2_ppc_all.R (which sources this script at the end).
#
# Run from the project root: Rscript code/05_figures/fig_g2_ppc_all.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
set.seed(20260923)  # jitter positions are reproducible (same seed as g2_ppc_all.R)
source(here::here("code", "05_figures", "fig_helpers.R"))
out_data <- here::here("data", "processed", "v2")
out_fig  <- here::here("outputs", "figures", "v2")
dir.create(out_fig, recursive = TRUE, showWarnings = FALSE)
by_fit <- readr::read_csv(file.path(out_data, "g2_ppc_by_fit.csv"), show_col_types = FALSE)
paired <- readr::read_csv(file.path(out_data, "g2_ppc_paired.csv"), show_col_types = FALSE)
detection_by_cell <- readr::read_csv(file.path(out_data, "g2_ppc_detection_by_cell.csv"), show_col_types = FALSE)
summary_tbl <- readr::read_csv(file.path(out_data, "g2_ppc_summary.csv"), show_col_types = FALSE)
primary <- list(verdict = summary_tbl$verdict[summary_tbl$analysis == "primary"][1])

stat_labels <- c(stat1_rmse = "1. Aggregate RMSE", stat2_highconf = "2. High-confidence (secondary)",
                 stat3_x2_df = "3. Pearson X2/df")
cell_levels <- unique(by_fit$cell)
paired$cell <- factor(paired$cell, levels = cell_levels)
detection_by_cell$cell <- factor(detection_by_cell$cell, levels = cell_levels)
paired$statistic <- factor(stat_labels[paired$statistic], levels = stat_labels)
detection_by_cell$statistic <- factor(stat_labels[detection_by_cell$statistic], levels = stat_labels)

pA <- ggplot(paired, aes(x = cell, y = ratio)) +
  geom_hline(yintercept = 1, color = "grey40") +
  geom_jitter(aes(shape = both_pass), width = 0.15, alpha = 0.5, size = 1.2, color = "#D55E00") +
  stat_summary(fun = stats::median, geom = "point", shape = 95, size = 8, color = "black") +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 4), labels = c(`TRUE` = "both pass", `FALSE` = "a fit flagged")) +
  scale_y_log10() +
  facet_wrap(~statistic, ncol = 1, scales = "free_y") +
  labs(subtitle = "A. Paired ratio, misspecified / correct (log scale; one point per dataset;\nbar = median; 1 = no difference)",
       x = NULL, y = "Ratio", shape = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "top")

loo_line <- detection_by_cell |> dplyr::distinct(statistic, cell, loo_prop_2se)
pB <- ggplot(detection_by_cell, aes(x = cell, y = detection)) +
  geom_hline(yintercept = 0.05, linetype = "dotted", color = "grey50") +
  geom_col(data = loo_line, aes(y = loo_prop_2se), fill = "#009E73", alpha = 0.25, width = 0.8) +
  geom_pointrange(aes(ymin = det_lo, ymax = det_hi), color = "#D55E00", size = 0.3) +
  facet_wrap(~statistic, ncol = 1) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(subtitle = paste0("B. Oracle-calibrated PPC detection of the Gaussian fit (points, Wilson 95% CI;\n",
                         "n = 20 per point) vs. LOO preferring the correct family by > 2 SE (green bars).\n",
                         "Dotted = 5% false-alarm rate. Pre-specified verdict: ", primary$verdict, "."),
       x = NULL, y = "Proportion") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

g <- gridExtra::arrangeGrob(print_ready(pA), print_ready(pB), ncol = 2)
save_fig(g, file.path(out_fig, "fig_g2_ppc_all.png"), width = 15, height = 10,
         sub_name = "FigS5", sub_height_mm = 200)
cat("Wrote outputs/figures/v2/fig_g2_ppc_all.png\n")
