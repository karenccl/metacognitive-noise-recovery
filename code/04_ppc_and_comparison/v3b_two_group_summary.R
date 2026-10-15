# v3b work package C summary: false-positive rate for b_groupB (log_M difference,
# truth 0) when two groups differ only in d', fitted in ONE model.
suppressPackageStartupMessages(library(dplyr))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

files <- list.files(here::here("data", "interim", "v3b"), "^two_group_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == 2 * cfgb$two_group$replications)

param <- "b_groupB"   # checked against the trial fits (plan section 3.6; analysis log)
by_fit <- purrr::map_dfr(files, function(f) {
  r <- qs2::qs_read(f); j <- r$job
  x <- if (!is.null(r$draws_b_sd) && param %in% names(r$draws_b_sd)) r$draws_b_sd[[param]] else NA_real_
  q <- stats::quantile(x, c(.025, .975), names = FALSE, na.rm = TRUE)
  tibble::tibble(job_id = j$job_id, rep_id = j$rep_id, fit_variant = j$fit_variant,
                 status = r$status, escalated = isTRUE(r$escalated),
                 diff_mean = mean(x), diff_q025 = q[1], diff_q975 = q[2],
                 excl0 = q[1] > 0 | q[2] < 0,
                 logM_groupA = if (is.null(r$draws_b_sd)) NA_real_ else mean(r$draws_b_sd$b_Intercept))
})
readr::write_csv(by_fit, file.path(out, "c_two_group_by_fit.csv"))

wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n; ctr <- (p + z^2 / (2 * n)) / den
  hw <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den; c(ctr - hw, ctr + hw)
}
summ <- function(d, label) d |>
  filter(!is.na(excl0)) |>
  group_by(fit_variant) |>
  summarise(n = n(), n_pass = sum(status == "pass"), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            .groups = "drop") |>
  mutate(analysis = label)
pooled <- bind_rows(summ(filter(by_fit, status %in% c("pass", "fail")), "primary"),
                    summ(filter(by_fit, status == "pass"), "pass_only"))
readr::write_csv(pooled, file.path(out, "c_two_group_summary.csv"))

paired <- by_fit |> filter(status %in% c("pass", "fail")) |>
  select(rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_reps")
readr::write_csv(paired, file.path(out, "c_two_group_paired.csv"))

# Descriptive, added after the results (not part of the framing rule): the
# d'-dependent part of the Gaussian bias, misspecified - correct on the same data.
differential <- by_fit |> filter(status %in% c("pass", "fail")) |>
  select(rep_id, fit_variant, diff_mean) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = diff_mean) |>
  mutate(d = misspecified - correct) |>
  summarise(n = sum(!is.na(d)), mean_mis_minus_cor = mean(d, na.rm = TRUE),
            mcse = sd(d, na.rm = TRUE) / sqrt(n))
readr::write_csv(differential, file.path(out, "c_differential_bias.csv"))

fr <- cfgb$framing_rule
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_C <- (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(sprintf("C: FPR misspecified = %.3f, correct = %.3f, excess = %.3f; framing rule met in C: %s",
                   p_mis, p_cor, p_mis - p_cor, verdict_C),
           file.path(out, "c_framing_rule.txt"))
print(as.data.frame(pooled), digits = 3); print(paired)
cat("framing rule met in C:", verdict_C, "\n")
