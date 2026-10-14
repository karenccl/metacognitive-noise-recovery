# v3b work package B: false-positive rate for a between-group difference in log_M
# when two groups differ ONLY in d' and each group is fitted separately.
# Uses the stored G2 fits (draws_b_sd$b_Intercept). No refitting.
# Low-d' group = d' 0.75 cell, high-d' group = d' 1.5 cell, same (N, T, rep, fit_variant).
# diff_high_minus_low: truth = 0 (both cells share log_M = design.yml truth).
#
# Run from the project root: Rscript code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R

suppressPackageStartupMessages(library(dplyr))

cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
ra   <- cfgb$reanalysis
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# ---- Locate the 480 G2 records ---------------------------------------------
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE) |>
  filter(generator == "g2")
grid$path <- here::here("data", "interim", sprintf(
  "g2_cell-%04d_rep-%02d_%s_grid-%05d.qs2",
  grid$cell_id, grid$rep_id, grid$fit_variant, grid$grid_id))
stopifnot(nrow(grid) == 480, all(file.exists(grid$path)))

# ---- Read status + log_M draws (compact record, every rep) -----------------
recs <- lapply(grid$path, function(p) {
  r <- qs2::qs_read(p)
  list(status = r$status,
       x = if (is.null(r$draws_b_sd)) NULL else r$draws_b_sd$b_Intercept)
})
grid$status  <- vapply(recs, function(r) r$status, character(1))
grid$n_draws <- vapply(recs, function(r) length(r$x), integer(1))
draws <- setNames(lapply(recs, `[[`, "x"), grid$grid_id)
cat("status counts:\n"); print(table(grid$fit_variant, grid$status))
cat("n_draws:\n"); print(table(grid$n_draws))

# ---- Pair low-d' and high-d' cells -------------------------------------------
keys <- c("fit_variant", "n_participants", "n_trials", "rep_id")
lev  <- grid |> select(grid_id, all_of(keys), dprime_target, status, n_draws)
pairs <- inner_join(filter(lev, dprime_target == 0.75), filter(lev, dprime_target == 1.5),
                    by = keys, suffix = c("_low", "_high"))
stopifnot(nrow(pairs) == 240)

# ---- Posterior of the difference, per pair ----------------------------------
set.seed(cfgb$seed_base_v3b + ra$pair_seed_offset)
lo_p <- (1 - ra$interval) / 2
by_pair <- pairs |>
  mutate(diff_mean = NA_real_, diff_q_lo = NA_real_, diff_q_hi = NA_real_, excl0 = NA)
for (i in seq_len(nrow(by_pair))) {
  a <- draws[[as.character(by_pair$grid_id_low[i])]]
  b <- draws[[as.character(by_pair$grid_id_high[i])]]
  if (is.null(a) || is.null(b)) next
  n <- min(length(a), length(b))
  d <- sample(b, n) - sample(a, n)                 # high minus low; independent posteriors
  q <- stats::quantile(d, c(lo_p, 1 - lo_p), names = FALSE)
  by_pair$diff_mean[i] <- mean(d)
  by_pair$diff_q_lo[i] <- q[1]; by_pair$diff_q_hi[i] <- q[2]
  by_pair$excl0[i]     <- q[1] > 0 | q[2] < 0
}
by_pair <- by_pair |>
  mutate(primary   = status_low %in% ra$statuses_primary & status_high %in% ra$statuses_primary,
         pass_only = status_low == "pass" & status_high == "pass")
readr::write_csv(by_pair, file.path(out, "b_dprime_confound_by_pair.csv"))

# ---- Summaries ---------------------------------------------------------------
wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(ctr - hw, ctr + hw)
}
# Output columns are named mean_diff / mcse_diff (not diff_mean): inside summarise(),
# re-using an input column name would make later expressions see the summarised value.
summarise_fpr <- function(d, ...) d |>
  group_by(...) |>
  summarise(n = n(), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            prop_diff_neg = mean(diff_mean < 0),
            .groups = "drop")

prim <- filter(by_pair, primary, !is.na(excl0))
sens <- filter(by_pair, pass_only, !is.na(excl0))

by_cell <- bind_rows(
  summarise_fpr(prim, fit_variant, n_participants, n_trials) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant, n_participants, n_trials) |> mutate(analysis = "pass_only"))
pooled <- bind_rows(
  summarise_fpr(prim, fit_variant) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant) |> mutate(analysis = "pass_only"))
readr::write_csv(by_cell, file.path(out, "b_dprime_confound_by_cell.csv"))
readr::write_csv(pooled,  file.path(out, "b_dprime_confound_pooled.csv"))

# Paired on the same simulated datasets: which variant produced the false positive?
paired <- prim |>
  select(n_participants, n_trials, rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_pairs")
readr::write_csv(paired, file.path(out, "b_dprime_confound_paired.csv"))

# ---- Pre-specified framing rule (config/v3b.yml framing_rule) --------------
fr <- cfgb$framing_rule
cell_max_mis <- max(by_cell$fpr[by_cell$analysis == "primary" & by_cell$fit_variant == "misspecified"])
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_B <- cell_max_mis >= fr$cell_fpr_min || (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(c(sprintf("max cell FPR (misspecified) = %.3f", cell_max_mis),
             sprintf("pooled FPR misspecified = %.3f, correct = %.3f, excess = %.3f", p_mis, p_cor, p_mis - p_cor),
             sprintf("framing rule met in B: %s", verdict_B)),
           file.path(out, "b_framing_rule.txt"))

cat("\n=== Pooled ===\n"); print(as.data.frame(pooled), digits = 3)
cat("\n=== By cell (primary) ===\n"); print(as.data.frame(filter(by_cell, analysis == "primary")), digits = 3)
cat("\n=== Paired ===\n"); print(paired)
cat("\nframing rule met in B:", verdict_B, "\n")
