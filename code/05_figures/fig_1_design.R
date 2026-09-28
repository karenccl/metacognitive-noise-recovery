# Fig 1: design schematic of the three generators and the fitted models
# (protocol section 6.4). Drawn with ggplot primitives so it is fully
# reproducible from code. Numbers are read from config/design.yml and
# config/grid.csv rather than hardcoded, so it cannot drift from the
# design that was actually run.
#
# Run from the project root: Rscript code/05_figures/fig_1_design.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
counts <- grid |> dplyr::count(generator)
n_rows <- function(g) counts$n[counts$generator == g]

okabe <- c(g0 = "#56B4E9", g1 = "#E69F00", g2 = "#009E73", fit = "#CC79A7")

boxes <- tibble::tribble(
  ~id,  ~x, ~y, ~w, ~h, ~fill,      ~label,
  "g0", 1,  6,  4.2, 2.6, okabe[["g0"]],
  sprintf("G0: model-consistent benchmark\nequal-variance Gaussian meta-d'\nknown log_M = -1\n%d fits (12 cells x %d reps)", n_rows("g0"), cfg$grid$replications$target),
  "g1", 1,  3,  4.2, 2.6, okabe[["g1"]],
  sprintf("G1: DDM + post-decisional noise\nv, a, t0, tau; readout noise sigma_c\n(low / medium / high, calibrated)\n%d fits (36 cells x %d reps)", n_rows("g1"), cfg$grid$replications$target),
  "g2", 1,  0,  4.2, 2.6, okabe[["g2"]],
  sprintf("G2: Gumbel-min signal distribution\nknown log_M = -1\nsame data fit twice\n%d fits (12 cells x %d reps x 2)", n_rows("g2"), cfg$grid$replications$target),
  "fit", 7, 3,  5.4, 5.6, okabe[["fit"]],
  "Fitted model (all generators)\nhierarchical hmetad, K = 4\n(1|participant) on log_M, d', c\nconfidence-threshold gaps pooled\nnormal(0,1) log_M prior\n4 chains, 1000 warmup + 1000 draws\nadapt_delta 0.95\n(one escalation retry if flagged)\n\nG2 also fit under Gaussian\n(misspecified) for comparison",
  "out", 13.4, 3, 5.4, 5.6, "grey85",
  "Outputs\nG0: bias, RMSE, pooled coverage\nG1: level means, diffs, Spearman, ordering\n     accuracy, separation prob.\nG2: paired LOO/ELPD, log_M bias\nPPCs; prior & K=6 (G1) sensitivity"
) |> dplyr::mutate(xmin = x - w / 2, xmax = x + w / 2, ymin = y - h / 2, ymax = y + h / 2)

arrows <- tibble::tribble(
  ~x, ~y, ~xend, ~yend,
  3.2, 6, 4.3, 4.2,
  3.2, 3, 4.3, 3,
  3.2, 0, 4.3, 1.8,
  9.7, 3, 10.7, 3
)

grid_txt <- sprintf(
  "Grid (per generator cell): N in {%s} participants x T in {%s} trials x d' in {%s}; G1 adds 3 sigma_c levels. %d replications per cell.",
  paste(unlist(cfg$grid$n_subjects), collapse = ", "), paste(unlist(cfg$grid$n_trials), collapse = ", "),
  paste(unlist(cfg$grid$dprime_target), collapse = ", "), cfg$grid$replications$target
)

p <- ggplot() +
  geom_rect(data = boxes, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill), color = "grey30", alpha = 0.85) +
  geom_text(data = boxes, aes(x = x, y = y, label = label), size = 3.1, lineheight = 0.95) +
  geom_segment(data = arrows, aes(x = x, y = y, xend = xend, yend = yend),
               arrow = arrow(length = unit(0.25, "cm")), color = "grey30") +
  scale_fill_identity() +
  coord_fixed(xlim = c(-1.3, 16.8), ylim = c(-2, 8)) +
  labs(
    title = "Simulation design: does a static meta-d' model track dynamic confidence?",
    subtitle = grid_txt,
    caption = "RQ1 (G1): does posterior log_M fall monotonically as readout noise rises?  RQ2 (G2): what does distributional misspecification cost?  RQ3: convergence failures reported throughout."
  ) +
  theme_void() +
  theme(plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0, size = 8),
        plot.subtitle = element_text(size = 9), plot.margin = margin(10, 10, 10, 10))

ggsave(here::here("outputs", "figures", "fig_1_design.png"), p, width = 11, height = 6, dpi = 200)
cat("Wrote outputs/figures/fig_1_design.png\n")
