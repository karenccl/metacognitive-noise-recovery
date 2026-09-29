# v3 empirical step 5.5 (docs/v3_plan.md): harmonise every selected dataset to
# hmetad input (participant, stimulus 0/1, response 0/1, confidence 1..K,
# condition L1..), applying the pre-specified row filters, participant
# exclusions and sparse-level merging. Writes one prepared .qs2 per usable
# dataset and a log with the data checks (acc_agreement, conf_acc_rho).
#
# Run from the project root: Rscript code/06_empirical/03_prepare_datasets.R

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "eligibility.R"))
e <- yaml::read_yaml(here::here("config", "v3.yml"))$empirical
raw_dir <- here::here("data", "raw", "confidence_db")
prep_dir <- here::here("data", "interim", "v3_empirical", "prepared")
dir.create(prep_dir, recursive = TRUE, showWarnings = FALSE)

sel <- readr::read_csv(here::here("data", "processed", "v3", "empirical", "selected_datasets.csv"),
                       show_col_types = FALSE,
                       col_types = readr::cols(exclude_filter = "c", difficulty_column = "c")) |>
  filter(set %in% c("primary", "sensitivity", "sensitivity_unrecorded", "secondary"))

prep_log <- purrr::map_dfr(seq_len(nrow(sel)), function(i) {
  s <- sel[i, ]
  d <- readr::read_csv(file.path(raw_dir, paste0("data_", s$dataset, ".csv")),
                       show_col_types = FALSE, guess_max = 100000)
  dcol <- if (s$difficulty_design == "recorded_levels") s$difficulty_column else NULL
  h <- harmonise_dataset(d, e, difficulty_col = dcol, exclude_filter = s$exclude_filter,
                         conf_range = c(s$conf_min, s$conf_max),
                         rank_within_subject = isTRUE(s$rank_within_subject))
  h$dataset <- s$dataset; h$set <- s$set
  # Data checks (plan §5.5): coding must agree with the dataset's own Accuracy
  # column and confidence must rise with accuracy; otherwise not usable.
  checks_ok <- (is.na(h$acc_agreement) || h$acc_agreement >= 0.99) &&
               !is.na(h$conf_acc_rho) && h$conf_acc_rho > 0
  usable <- h$K >= e$k_min && h$n_participants_kept >= e$min_participants && checks_ok
  if (usable) qs2::qs_save(h, file.path(prep_dir, paste0(s$dataset, ".qs2")))
  tibble::tibble(dataset = s$dataset, set = s$set, K = h$K,
                 conf_map = paste(h$conf_map$old, h$conf_map$new, sep = "->", collapse = " "),
                 n_cond = nlevels(h$data$condition),
                 n_rows_filtered = h$n_rows_filtered,
                 n_participants_raw = h$n_participants_raw,
                 n_participants_kept = h$n_participants_kept,
                 n_trials = nrow(h$data), acc_agreement = h$acc_agreement,
                 conf_acc_rho = h$conf_acc_rho, checks_ok = checks_ok, usable = usable)
})
readr::write_csv(prep_log, here::here("data", "processed", "v3", "empirical", "prepare_log.csv"))
print(as.data.frame(select(prep_log, -conf_map)), digits = 3)
cat("\nUsable by set:\n"); print(count(prep_log, set, usable))
