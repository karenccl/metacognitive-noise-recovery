# Execution tiers for the LOO repair (docs/analysis_log.md 2026-10-04), from the
# fits' convergence diagnostics only (no LOO is read):
#   tier 1  both families pass                  -> primary categorisation
#   tier 2  both conv_ok, not both pass         -> divergence-only sensitivity only
#   tier 3  any fit fails beyond divergences    -> "unreliable" under both
#           pre-specified rules whatever its LOO; repaired only on request
#           (05_loo_repair.R --include-tier3)
# Changes execution order only; no pre-specified category depends on tier-3 LOO.
#
# Run from the project root: Rscript code/06_empirical/05b_loo_tiers.R

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "loo_repair_functions.R"))
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
sel <- readr::read_csv(here::here("data", "processed", "v3", "empirical", "selected_datasets.csv"),
                       show_col_types = FALSE)
datasets <- sort(unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$"))))

tiers <- purrr::map_dfr(datasets, function(ds) {
  f <- purrr::map(c(normal = "normal", gumbel = "gumbel_min"),
                  ~ qs2::qs_read(file.path(fit_dir, sprintf("%s__%s.qs2", ds, .x))))
  both_pass <- all(purrr::map_chr(f, "status") == "pass")
  both_ok   <- all(purrr::map_lgl(f, conv_ok))
  tibble::tibble(dataset = ds, status_normal = f$normal$status, status_gumbel = f$gumbel$status,
                 tier = if (both_pass) 1L else if (both_ok) 2L else 3L)
}) |>
  left_join(select(sel, dataset, set), by = "dataset")

out <- here::here("data", "processed", "v3", "empirical", "loo_repair_tiers.csv")
readr::write_csv(tiers, out)
print(count(tiers, tier, set))
