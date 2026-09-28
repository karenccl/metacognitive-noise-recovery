# Record every prior actually used by the production fits, including the
# brms/hmetad defaults that design.yml does not mention (review item 15).
# Reads the stored brmsfit of one G0 and one G2-correct fit (replication 1;
# full fits are kept only for rep_id <= 2) and writes
# outputs/tables/prior_summary.csv (one row per prior line, with the
# fit it came from). No refitting.
#
# Run from the project root: Rscript code/03_recovery_analysis/prior_summary.R

suppressPackageStartupMessages({library(dplyr); library(brms)})

grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
pick <- function(gen, variant) {
  g <- grid |> dplyr::filter(generator == gen, fit_variant == variant, rep_id == 1,
                             n_participants == 40, n_trials == 200, dprime_target == 1.5)
  stopifnot(nrow(g) == 1)
  f <- list.files(here::here("data", "interim"), pattern = sprintf("grid-%05d\\.qs2$", g$grid_id), full.names = TRUE)
  stopifnot(length(f) == 1)
  r <- qs2::qs_read(f)
  stopifnot(!is.null(r$fit))
  tibble::as_tibble(as.data.frame(brms::prior_summary(r$fit))) |>
    dplyr::mutate(source_fit = sprintf("%s/%s grid_id=%d", gen, variant, g$grid_id), .before = 1)
}

ps <- dplyr::bind_rows(pick("g0", "default"), pick("g2", "correct"), pick("g2", "misspecified"))
dir.create(here::here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(ps, here::here("outputs", "tables", "prior_summary.csv"))

show <- ps |> dplyr::filter(source_fit == unique(source_fit)[1]) |>
  dplyr::select(prior, class, coef, group, dpar, source)
print(as.data.frame(show), right = FALSE)
cat("\nPriors identical across the three fits (ignoring source_fit): ",
    dplyr::n_distinct(dplyr::select(ps, -source_fit)) == nrow(dplyr::filter(ps, source_fit == unique(source_fit)[1])), "\n")
