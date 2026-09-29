# v3 step 2b (docs/v3_plan.md §3.3): compare PSIS-LOO vs exact-refit LOO
# (v3_reloo_stored_fits.R) on the 24 stored G2 pairs, and summarise Pareto k
# across all 480 G2 fits by cell. Sign here follows g2_elpd_comparison.csv:
# diff = elpd(correct) - elpd(Gaussian), > 0 favours the correct (Gumbel) model.
#
# Run from the project root: Rscript code/04_ppc_and_comparison/v3_loo_robust_summary.R

suppressPackageStartupMessages(library(dplyr))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
out <- here::here("data", "processed", "v3")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

recs <- purrr::map(list.files(here::here("data", "interim", "v3_reloo"),
                              pattern = "[.]qs2$", full.names = TRUE), qs2::qs_read)
stopifnot(length(recs) == 48, all(purrr::map_lgl(recs, "ok")))

cmp_one <- function(loo_c, loo_m) {
  cmp  <- loo::loo_compare(list(correct = loo_c, misspecified = loo_m))
  diff <- cmp["correct", "elpd_diff"] - cmp["misspecified", "elpd_diff"]  # > 0 favours correct
  se   <- max(cmp[, "se_diff"])
  c(diff = diff, se = se)
}

pairs <- split(recs, purrr::map_chr(recs, ~ paste(.x$cell_id, .x$rep_id)))
stopifnot(length(pairs) == 24, all(lengths(pairs) == 2))
by_pair <- purrr::map_dfr(pairs, function(p) {
  v <- purrr::map_chr(p, "fit_variant")
  c_ <- p[[which(v == "correct")]]; m_ <- p[[which(v == "misspecified")]]
  psis  <- cmp_one(c_$loo_psis,  m_$loo_psis)
  exact <- cmp_one(c_$loo_exact, m_$loo_exact)
  tibble::tibble(cell_id = c_$cell_id, rep_id = c_$rep_id,
                 n_participants = c_$n_participants, n_trials = c_$n_trials,
                 dprime_target = c_$dprime_target,
                 status_correct = c_$status, status_mis = m_$status,
                 n_bad_k_correct = c_$n_bad_k, n_bad_k_mis = m_$n_bad_k,
                 diff_psis = psis[["diff"]], se_psis = psis[["se"]],
                 diff_exact = exact[["diff"]], se_exact = exact[["se"]]) |>
    mutate(favors_psis = diff_psis > 0, favors_exact = diff_exact > 0,
           favors2se_psis = diff_psis > 2 * se_psis, favors2se_exact = diff_exact > 2 * se_exact,
           sign_agree = favors_psis == favors_exact,
           twose_agree = favors2se_psis == favors2se_exact)
}) |> arrange(n_participants, n_trials, dprime_target, rep_id)
readr::write_csv(by_pair, file.path(out, "g2_loo_psis_vs_exact_by_pair.csv"))

summary_tbl <- by_pair |>
  summarise(n_pairs = n(),
            n_refits = sum(n_bad_k_correct) + sum(n_bad_k_mis),
            prop_favor_psis = mean(favors_psis), prop_favor_exact = mean(favors_exact),
            prop_2se_psis = mean(favors2se_psis), prop_2se_exact = mean(favors2se_exact),
            sign_agreement = mean(sign_agree), twose_agreement = mean(twose_agree),
            median_abs_change = median(abs(diff_exact - diff_psis)),
            max_abs_change = max(abs(diff_exact - diff_psis)))
# Pre-specified decision (plan §3.5): PSIS conclusion stands if the 2-SE
# classification agrees in >= 90% of pairs and the favour-correct rate moves < 10 points.
summary_tbl <- summary_tbl |>
  mutate(psis_conclusion_holds = twose_agreement >= 0.9 &
           abs(prop_favor_exact - prop_favor_psis) < 0.10)
readr::write_csv(summary_tbl, file.path(out, "g2_loo_psis_vs_exact_summary.csv"))
print(as.data.frame(summary_tbl), digits = 3)

# Full-grid Pareto k table (all 480 fits) from the existing per-fit file,
# broken down by cell, for the supplement.
pk <- readr::read_csv(here::here("data", "processed", "g2_pareto_k_by_fit.csv"), show_col_types = FALSE)
pk_cell <- pk |>
  group_by(fit_variant, n_participants, n_trials, dprime_target) |>
  summarise(n_fits = n(), prop_fits_any_bad = mean(n_k_bad > 0),
            prop_obs_bad = sum(n_k_bad) / sum(n_obs), mean_max_k = mean(max_k),
            .groups = "drop")
readr::write_csv(pk_cell, file.path(out, "g2_pareto_k_by_cell.csv"))
cat("\nWrote g2_loo_psis_vs_exact_{by_pair,summary}.csv and g2_pareto_k_by_cell.csv\n")
