# Fig. 9 (v3 step 4): Confidence Database results.
# A: forest plot of elpd(normal) - elpd(gumbel_min) +/- 2 SE per dataset
# (repaired LOO), coloured by pre-specified category, faceted by analysis set.
# B: delta_logM = log_M(Gaussian) - log_M(Gumbel-min) against elpd_diff.
#
# Run from the project root: Rscript code/05_figures/fig_9_empirical.R

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
cat_cols <- c(clear_gaussian = "#D55E00", clear_gumbel = "#009E73", inconclusive = "grey50",
              unreliable = "#CC79A7")
d <- readr::read_csv(here::here("data", "processed", "v3", "empirical", "empirical_by_dataset.csv"),
                     show_col_types = FALSE) |>
  mutate(set = factor(set, levels = c("primary", "sensitivity", "sensitivity_unrecorded", "secondary")),
         # unreliable rows have no repaired diff: show the PSIS value, hollow
         x = coalesce(elpd_diff, elpd_diff_psis), xse = coalesce(se, se_psis),
         repaired = !is.na(elpd_diff)) |>
  arrange(set, x)
d$dataset <- factor(d$dataset, levels = unique(d$dataset))

pA <- ggplot(d, aes(x, dataset, colour = category)) +
  geom_vline(xintercept = 0, linetype = 2, colour = "grey40") +
  geom_errorbarh(aes(xmin = x - 2 * xse, xmax = x + 2 * xse), height = 0) +
  geom_point(aes(shape = repaired), size = 2) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1), labels = c(`TRUE` = "repaired LOO", `FALSE` = "PSIS only"),
                     name = NULL) +
  scale_colour_manual(values = cat_cols, drop = FALSE) +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 5), breaks = c(-500, -100, -20, 0, 20, 100, 500)) +
  facet_grid(set ~ ., scales = "free_y", space = "free_y") +
  labs(subtitle = "A. elpd(Gaussian) - elpd(Gumbel-min) ± 2 SE (> 0 favours Gaussian; pseudo-log axis)",
       x = "ELPD difference", y = NULL, colour = NULL) +
  theme_minimal() + theme(legend.position = "top", strip.text.y = element_text(angle = 0))

pB <- ggplot(d, aes(x, delta_logM, colour = category)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_vline(xintercept = 0, linetype = 2, colour = "grey40") +
  geom_errorbar(aes(ymin = delta_logM_q025, ymax = delta_logM_q975), width = 0, alpha = 0.5) +
  geom_point(aes(shape = set), size = 2.2) +
  scale_colour_manual(values = cat_cols, guide = "none") +
  scale_x_continuous(trans = scales::pseudo_log_trans(sigma = 5), breaks = c(-500, -100, -20, 0, 20, 100, 500)) +
  labs(subtitle = "B. log M shift between families vs model preference",
       x = "ELPD difference (> 0 favours Gaussian)",
       y = expression(Delta ~ "log M = Gaussian - Gumbel-min (95% interval)"), shape = NULL) +
  theme_minimal() + theme(legend.position = "top")

dir.create(here::here("outputs", "figures", "v3"), recursive = TRUE, showWarnings = FALSE)
h <- max(7, 0.22 * nrow(d) + 2)
g <- gridExtra::arrangeGrob(pA, pB, ncol = 2, widths = c(1.3, 1))
ggsave(here::here("outputs", "figures", "v3", "fig_9_empirical.png"), g, width = 15, height = h, dpi = 200)
cat("Wrote outputs/figures/v3/fig_9_empirical.png\n")
