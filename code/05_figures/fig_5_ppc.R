# Fig 5: representative posterior predictive checks (protocol sections
# 5 Day 5, 6.4). Five prespecified representative fits, all N=40, T=200,
# d'=1.5, rep 1 (selected by category, not by how good they look): G0
# typical pass, G1 low/high noise pass (no G1 failure exists to show),
# G2 correct, G2 misspecified. Points = the 16 stimulus x response x
# confidence cells (proportions conditional on stimulus); the highest
# confidence category (C4) is highlighted because that is where the G2
# misspecified fit's largest discrepancies concentrate.
#
# Run from the project root: Rscript code/05_figures/fig_5_ppc.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

ppc <- readr::read_csv(here::here("data", "processed", "ppc_joint_counts.csv"), show_col_types = FALSE)
summ <- readr::read_csv(here::here("data", "processed", "ppc_discrepancy_summary.csv"), show_col_types = FALSE)

lvl <- c("G0 (typical pass)", "G1 low noise (pass)", "G1 high noise (pass)",
         "G2 correct (Gumbel-min)", "G2 misspecified (Gaussian)")
ppc$fit_label <- factor(ppc$fit_label, levels = lvl)
ppc$extreme <- ifelse(ppc$confidence == 4, "Highest confidence (C4)", "Other confidence levels")

lab <- summ |>
  dplyr::mutate(fit_label = factor(fit_label, levels = lvl),
                text = sprintf("RMSE %.4f\nmax |d| %.4f", rmse_discrepancy, max_abs_discrepancy))

p <- ggplot(ppc, aes(x = predicted_prop, y = observed_prop)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(aes(color = extreme, shape = factor(stimulus)), size = 2.4, alpha = 0.9) +
  geom_text(data = lab, aes(x = 0.02, y = 0.255, label = text), hjust = 0, vjust = 1, size = 2.9, inherit.aes = FALSE) +
  facet_wrap(~fit_label, ncol = 3) +
  scale_color_manual(values = c("Highest confidence (C4)" = "#D55E00", "Other confidence levels" = "#0072B2")) +
  scale_shape_manual(values = c("0" = 16, "1" = 17), labels = c("Stimulus 0", "Stimulus 1")) +
  labs(
    title = "Posterior predictive checks: all fits track the joint counts closely",
    subtitle = "Each point is one stimulus x response x confidence cell (proportion conditional on stimulus). Dashed line = perfect fit.\nIn these single replicates, only the misspecified G2 fit has its four largest errors all at the highest confidence category (suggestive, n = 1 per fit).",
    x = "Posterior-predicted proportion (hmetad::epred_draws_metad)", y = "Observed proportion",
    color = NULL, shape = NULL,
    caption = "Representative condition N=40, T=200, d'=1.5, replication 1 (fits chosen by category). All fits are hierarchical hmetad, K=4. G1 had no failed fits to display (720/720 pass).\nSmall aggregate discrepancy is not evidence of generative adequacy: LOO (Fig. 4) separates the G2 models far more clearly than PPC magnitude does."
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.caption = element_text(hjust = 0, size = 7.5),
        plot.subtitle = element_text(size = 9))

ggsave(here::here("outputs", "figures", "fig_5_ppc.png"), p, width = 10.5, height = 7, dpi = 200)
cat("Wrote outputs/figures/fig_5_ppc.png\n")
