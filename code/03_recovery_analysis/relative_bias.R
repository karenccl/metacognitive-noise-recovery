# v3 step 1: decompose G2 log_M error into (a) misspecification effect
# delta_mis = log_M(normal fit) - log_M(correct fit), paired on the SAME
# simulated dataset, and (b) baseline error of the correct fit
# bias_correct = log_M(correct) - truth. No refitting; reads
# data/processed/compiled_results.csv and config/grid.csv only.
# Sign convention: config/v3.yml sign_conventions$delta_mis.
#
# Run from the project root: Rscript code/03_recovery_analysis/relative_bias.R

suppressPackageStartupMessages(library(dplyr))

cfg   <- yaml::read_yaml(here::here("config", "design.yml"))
truth <- cfg$truth$log_M
out   <- here::here("data", "processed", "v3")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

res  <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE) |>
  select(grid_id, sim_seed)

keys <- c("n_participants", "n_trials", "dprime_target", "rep_id")

# ---- Pair the two G2 fits of each simulated dataset -------------------------
g2 <- res |>
  filter(generator == "g2") |>
  left_join(grid, by = "grid_id") |>
  mutate(covered  = log_M_q025 <= truth & truth <= log_M_q975,
         ci_width = log_M_q975 - log_M_q025) |>
  select(all_of(keys), fit_variant, sim_seed, status, log_M_mean, covered, ci_width)

wide <- g2 |>
  tidyr::pivot_wider(names_from = fit_variant,
                     values_from = c(sim_seed, status, log_M_mean, covered, ci_width))

# Integrity checks: 240 datasets, both variants fitted to the identical data.
stopifnot(nrow(wide) == 240,
          !anyNA(wide$log_M_mean_correct), !anyNA(wide$log_M_mean_misspecified),
          all(wide$sim_seed_correct == wide$sim_seed_misspecified))

by_fit <- wide |>
  mutate(delta_mis    = log_M_mean_misspecified - log_M_mean_correct,
         bias_correct = log_M_mean_correct - truth,
         bias_mis     = log_M_mean_misspecified - truth,
         both_pass    = status_correct == "pass" & status_misspecified == "pass",
         any_error    = status_correct == "error" | status_misspecified == "error")
stopifnot(!any(by_fit$any_error))   # if this fails, drop error rows explicitly and log it
readr::write_csv(by_fit, file.path(out, "g2_relative_bias_by_fit.csv"))

# ---- Per-cell summary (primary = pass + fail, sensitivity = both pass) -------
mcse <- function(x) stats::sd(x) / sqrt(length(x))
summarise_cells <- function(d) d |>
  group_by(n_participants, n_trials, dprime_target) |>
  summarise(n              = n(),
            delta_mean     = mean(delta_mis),
            delta_mcse     = mcse(delta_mis),
            delta_median   = median(delta_mis),
            delta_q025     = quantile(delta_mis, 0.025, names = FALSE),
            delta_q975     = quantile(delta_mis, 0.975, names = FALSE),
            prop_delta_pos = mean(delta_mis > 0),
            base_mean      = mean(bias_correct),
            base_mcse      = mcse(bias_correct),
            cover_correct  = mean(covered_correct),
            cover_mis      = mean(covered_misspecified),
            width_correct  = mean(ci_width_correct),
            width_mis      = mean(ci_width_misspecified),
            .groups = "drop")

cells_primary     <- summarise_cells(by_fit) |> mutate(analysis = "primary")
cells_sensitivity <- summarise_cells(filter(by_fit, both_pass)) |> mutate(analysis = "pass_only")
readr::write_csv(bind_rows(cells_primary, cells_sensitivity),
                 file.path(out, "g2_relative_bias_by_cell.csv"))

# ---- d' contrast: is the misspecification effect larger at low d'? ----------
# Seeds differ across cells, so low- and high-d' cells are INDEPENDENT samples:
# SE of a difference = sqrt(se1^2 + se2^2). Do not pair replications across cells.
dprime_contrast <- cells_primary |>
  mutate(dlev = if_else(dprime_target == 0.75, "low", "high")) |>
  select(n_participants, n_trials, dlev, delta_mean, delta_mcse) |>
  tidyr::pivot_wider(names_from = dlev, values_from = c(delta_mean, delta_mcse)) |>
  mutate(diff_low_minus_high = delta_mean_low - delta_mean_high,
         se_diff = sqrt(delta_mcse_low^2 + delta_mcse_high^2),
         z = diff_low_minus_high / se_diff)
# n_cells_positive comes first: summarise() evaluates in order, so after
# diff_low_minus_high is overwritten by its mean it would count a scalar.
pooled <- dprime_contrast |>
  summarise(n_cells = n(),
            n_cells_positive = sum(diff_low_minus_high > 0),
            diff_low_minus_high = mean(diff_low_minus_high),
            se_diff = sqrt(sum(se_diff^2)) / n())
readr::write_csv(dprime_contrast, file.path(out, "g2_dprime_contrast_by_NT.csv"))
readr::write_csv(pooled, file.path(out, "g2_dprime_contrast_pooled.csv"))

# ---- Persistence: does delta_mis shrink with more data? ---------------------
# A slope near 0 for log2(n_trials) with a clearly non-zero intercept = the
# misspecification effect does not vanish with data (pseudo-true displacement).
persist_fit <- lm(delta_mis ~ log2(n_trials) + factor(n_participants) + factor(dprime_target),
                  data = by_fit)
persist <- tibble::tibble(term = names(coef(persist_fit)),
                          estimate = coef(persist_fit),
                          lo = confint(persist_fit)[, 1],
                          hi = confint(persist_fit)[, 2])
readr::write_csv(persist, file.path(out, "g2_delta_persistence_lm.csv"))

# "More confidently wrong": interval width shrinks while delta stays.
confidently_wrong <- by_fit |>
  group_by(n_trials, dprime_target) |>
  summarise(mean_width_mis = mean(ci_width_misspecified),
            mean_delta     = mean(delta_mis),
            prop_mis_excludes_truth = mean(!covered_misspecified),
            .groups = "drop")
readr::write_csv(confidently_wrong, file.path(out, "g2_confidently_wrong.csv"))

# ---- Baseline check: G0 bias vs G2-correct bias in the same cells -----------
g0_bias <- res |>
  filter(generator == "g0", status %in% c("pass", "fail")) |>
  group_by(n_participants, n_trials, dprime_target) |>
  summarise(g0_bias = mean(log_M_mean - truth), g0_mcse = mcse(log_M_mean - truth), .groups = "drop")
baseline_cmp <- cells_primary |>
  select(n_participants, n_trials, dprime_target, base_mean, base_mcse) |>
  left_join(g0_bias, by = c("n_participants", "n_trials", "dprime_target")) |>
  mutate(diff = base_mean - g0_bias, se = sqrt(base_mcse^2 + g0_mcse^2))
readr::write_csv(baseline_cmp, file.path(out, "g2_baseline_vs_g0.csv"))

cat("\n=== Per-cell delta_mis (primary) ===\n")
print(as.data.frame(select(cells_primary, n_participants, n_trials, dprime_target, n,
                           delta_mean, delta_mcse, base_mean, base_mcse)), digits = 3)
cat("\n=== Pooled d' contrast (low - high) ===\n"); print(as.data.frame(pooled), digits = 3)
cat("\n=== Persistence lm ===\n"); print(as.data.frame(persist), digits = 3)
cat("\n=== Baseline: G2-correct vs G0 ===\n"); print(as.data.frame(baseline_cmp), digits = 3)
cat("\nDone. Outputs in data/processed/v3/\n")
