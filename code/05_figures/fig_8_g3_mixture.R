# Fig. 8 (v3 step 3): G3 difficulty-mixture simulation (Gaussian data).
# A: elpd(normal) - elpd(gumbel_min) per replication by condition and
# aggregation (> 0 favours Gaussian; dashed = 0), points filled when |diff| > 2 SE.
# B: log_M bias (mean +/- 2 MCSE) per fit variant.
#
# Run from the project root: Rscript code/05_figures/fig_8_g3_mixture.R

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
l <- readr::read_csv(here::here("data", "processed", "v3", "g3_loo_by_rep.csv"), show_col_types = FALSE) |>
  mutate(agg = factor(agg, levels = c("pooled", "difficulty"),
                      labels = c("Pooled over difficulty", "Difficulty modelled")),
         clear = case_when(favors_normal_2se ~ "Gaussian > 2 SE", favors_gumbel_2se ~ "Gumbel-min > 2 SE",
                           TRUE ~ "within 2 SE"))
verdict <- readLines(here::here("data", "processed", "v3", "g3_verdict.txt"), n = 1)
pA <- ggplot(l, aes(condition, elpd_diff)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_errorbar(aes(ymin = elpd_diff - 2 * se, ymax = elpd_diff + 2 * se), colour = "grey75", width = 0,
                position = position_jitter(width = 0.15, seed = 1)) +
  geom_point(aes(colour = clear), size = 2, position = position_jitter(width = 0.15, seed = 1)) +
  scale_colour_manual(values = c("Gaussian > 2 SE" = "#D55E00", "Gumbel-min > 2 SE" = "#009E73",
                                 "within 2 SE" = "grey50")) +
  facet_wrap(~agg) +
  labs(subtitle = paste0("A. elpd(Gaussian) - elpd(Gumbel-min) per replication (± 2 SE)\n",
                         "Pre-specified verdict: ", verdict),
       x = NULL, y = "ELPD difference (> 0 favours Gaussian)", colour = NULL) +
  theme_minimal() + theme(legend.position = "top")

b <- readr::read_csv(here::here("data", "processed", "v3", "g3_bias.csv"), show_col_types = FALSE) |>
  mutate(fam = if_else(grepl("^normal", fit_variant), "Gaussian", "Gumbel-min"),
         agg = if_else(grepl("pooled", fit_variant), "pooled", "difficulty"))
pB <- ggplot(b, aes(interaction(agg, condition, sep = "\n"), bias, colour = fam)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = bias - 2 * mcse, ymax = bias + 2 * mcse), position = position_dodge(width = 0.5)) +
  scale_colour_manual(values = c("Gaussian" = "#D55E00", "Gumbel-min" = "#009E73")) +
  labs(subtitle = "B. log M bias (estimate - truth), mean ± 2 MCSE",
       x = NULL, y = "log M bias", colour = NULL) +
  theme_minimal() + theme(legend.position = "top")

dir.create(here::here("outputs", "figures", "v3"), recursive = TRUE, showWarnings = FALSE)
g <- gridExtra::arrangeGrob(pA, pB, ncol = 2, widths = c(1.3, 1))
ggsave(here::here("outputs", "figures", "v3", "fig_8_g3_mixture.png"), g, width = 13, height = 5.5, dpi = 200)
cat("Wrote outputs/figures/v3/fig_8_g3_mixture.png\n")
