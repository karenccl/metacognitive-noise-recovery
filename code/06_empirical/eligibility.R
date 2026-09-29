# v3 empirical stage (docs/v3_plan.md §5.2): pure functions, no file I/O,
# all unit-tested in tests/test_eligibility.R. Rules and thresholds come from
# config/v3.yml$empirical and are passed in as `e`.

REQUIRED_COLS <- c("Subj_idx", "Stimulus", "Response", "Confidence")
OPTIONAL_COLS <- c("Accuracy", "Condition")

# ---- column-name standardisation --------------------------------------------
# A few datasets use other capitalisations (e.g. "stimulus", "confidence") or
# "subject_id". Rename case-insensitive exact matches to the standard names,
# only when the standard name is absent and the match is unique. Datasets with
# one column per task (e.g. Confidence_1/Confidence_2) are left unchanged and
# fail the required-column rule.
standardise_names <- function(d) {
  for (std in c(REQUIRED_COLS, OPTIONAL_COLS)) {
    if (std %in% names(d)) next
    aliases <- tolower(c(std, if (std == "Subj_idx") "subject_id"))
    hit <- which(tolower(names(d)) %in% aliases)
    if (length(hit) == 1) names(d)[hit] <- std
  }
  d
}

# ---- dataset-level screening from a raw data frame ------------------------
screen_raw <- function(d, min_trials) {
  d <- standardise_names(d)
  if (!all(REQUIRED_COLS %in% names(d))) {
    return(tibble::tibble(has_required = FALSE))
  }
  d <- d[stats::complete.cases(d[, REQUIRED_COLS]), ]
  per_subj  <- table(d$Subj_idx)
  conf_vals <- sort(unique(d$Confidence))
  stim_vals <- unique(d$Stimulus)
  tibble::tibble(
    has_required      = TRUE,
    n_rows            = nrow(d),
    n_subj            = length(per_subj),
    n_subj_min_trials = sum(per_subj >= min_trials),
    median_trials     = stats::median(as.numeric(per_subj)),
    n_stim            = length(stim_vals),
    n_resp            = length(unique(d$Response)),
    resp_in_stim      = all(unique(d$Response) %in% stim_vals),
    conf_numeric      = is.numeric(d$Confidence),
    conf_integer      = is.numeric(d$Confidence) && all(conf_vals == round(conf_vals)),
    n_conf_levels     = length(conf_vals),
    has_condition     = "Condition" %in% names(d),
    n_condition       = if ("Condition" %in% names(d)) length(unique(stats::na.omit(d$Condition))) else NA_integer_
  )
}

# ---- automatic eligibility rules (config/v3.yml$empirical) -----------------
# coalesce(): a dataset missing a required column has NA summaries -> not eligible.
# "Discrete" = numeric with 3-11 distinct values (config conf_levels_range);
# values need not be integers (e.g. probability ratings 0.5, 0.6, ..., 1).
apply_auto_rules <- function(s, e) {
  s |>
    dplyr::mutate(
      rule_required = has_required,
      rule_binary   = dplyr::coalesce(n_stim == 2 & n_resp == 2 & resp_in_stim, FALSE),
      rule_discrete = dplyr::coalesce(conf_numeric & n_conf_levels >= e$conf_levels_range[[1]] &
                                      n_conf_levels <= e$conf_levels_range[[2]], FALSE),
      rule_sample   = dplyr::coalesce(n_subj_min_trials >= e$min_participants, FALSE),
      auto_eligible = rule_required & rule_binary & rule_discrete & rule_sample
    )
}

# ---- merge sparse adjacent confidence levels -------------------------------
# Deterministic: repeatedly merge the sparsest level into its sparser adjacent
# neighbour until every level holds >= min_prop of trials and K <= k_max.
# Assumes larger raw values = higher confidence (checked separately).
merge_sparse_levels <- function(x, min_prop = 0.05, k_max = 6) {
  old <- sort(unique(x))
  grp <- seq_along(old)
  counts <- tabulate(match(x, old), length(old))
  repeat {
    gp <- as.numeric(tapply(counts, grp, sum)) / length(x)
    ng <- length(gp)
    if (ng <= 2 || (all(gp >= min_prop) && ng <= k_max)) break
    j    <- which.min(gp)
    nbrs <- c(j - 1L, j + 1L); nbrs <- nbrs[nbrs >= 1 & nbrs <= ng]
    m    <- nbrs[which.min(gp[nbrs])]
    grp[grp == max(j, m)] <- min(j, m)
    grp  <- as.integer(factor(grp))       # renumber consecutively, order preserved
  }
  tibble::tibble(old = old, new = grp)
}

# ---- row filters fixed in config/empirical_manual_coding.csv ----------------
# Applied before anything else in harmonise_dataset():
#  * practice trials: rows with Training == 1 whenever a Training column exists;
#  * exclude_filter: an R expression over the raw columns (e.g. "Catch_trial == 1");
#    rows where it is TRUE are dropped;
#  * conf_range: c(min, max) of valid confidence codes; rows outside are dropped
#    (sentinel codes such as 0 = "error", 999, -1 = not asked).
filter_rows <- function(d, exclude_filter = NA, conf_range = NULL) {
  n0 <- nrow(d)
  if ("Training" %in% names(d)) d <- d[is.na(d$Training) | d$Training != 1, , drop = FALSE]
  if (!is.null(exclude_filter) && !is.na(exclude_filter) && nzchar(exclude_filter)) {
    drop <- eval(parse(text = exclude_filter), envir = d)
    d <- d[is.na(drop) | !drop, , drop = FALSE]
  }
  if (!is.null(conf_range) && !anyNA(conf_range)) {
    ok <- !is.na(d$Confidence) & d$Confidence >= conf_range[[1]] & d$Confidence <= conf_range[[2]]
    d <- d[ok, , drop = FALSE]
  }
  attr(d, "n_rows_filtered") <- n0 - nrow(d)
  d
}

# ---- harmonise one dataset to hmetad input format --------------------------
# difficulty_col: name of the column that records difficulty/condition, or NULL.
# rank_within_subject: recode difficulty_col as the within-participant rank of
# its value (for designs with k fixed levels calibrated per participant, so the
# raw values differ across participants).
harmonise_dataset <- function(d, e, difficulty_col = NULL, exclude_filter = NA,
                              conf_range = NULL, rank_within_subject = FALSE) {
  d <- filter_rows(standardise_names(as.data.frame(d)), exclude_filter, conf_range)
  n_rows_filtered <- attr(d, "n_rows_filtered")
  if (isTRUE(rank_within_subject)) {
    stopifnot(!is.null(difficulty_col))
    d[[difficulty_col]] <- stats::ave(d[[difficulty_col]], d$Subj_idx,
                                      FUN = function(x) match(x, sort(unique(x))))
  }
  keep_cols <- c(REQUIRED_COLS, difficulty_col, intersect("Accuracy", names(d)))
  d <- d[stats::complete.cases(d[, c(REQUIRED_COLS, difficulty_col)]), keep_cols, drop = FALSE]
  stim_levels <- sort(unique(d$Stimulus))
  stopifnot(length(stim_levels) == 2, all(unique(d$Response) %in% stim_levels))

  out <- tibble::tibble(
    subj_raw  = d$Subj_idx,
    stimulus  = as.integer(match(d$Stimulus, stim_levels) - 1L),
    response  = as.integer(match(d$Response, stim_levels) - 1L),
    conf_raw  = d$Confidence,
    condition_raw = if (is.null(difficulty_col)) "all" else as.character(d[[difficulty_col]])
  )
  out$correct <- as.integer(out$stimulus == out$response)

  # Cross-check against the dataset's own Accuracy column if present.
  acc_agreement <- if ("Accuracy" %in% names(d)) mean(out$correct == d$Accuracy, na.rm = TRUE) else NA_real_

  # Confidence direction check: mean accuracy should rise with confidence.
  conf_acc_rho <- suppressWarnings(stats::cor(out$conf_raw, out$correct, method = "spearman"))

  # Participant exclusions (pre-specified).
  ps <- out |> dplyr::group_by(subj_raw) |>
    dplyr::summarise(n = dplyr::n(), acc = mean(correct), .groups = "drop")
  keep <- ps$subj_raw[ps$n >= e$min_trials_per_participant &
                      ps$acc >= e$accuracy_range[[1]] & ps$acc <= e$accuracy_range[[2]]]
  out <- out[out$subj_raw %in% keep, ]

  # Confidence levels: merge sparse ones (after exclusions).
  cmap <- merge_sparse_levels(out$conf_raw, e$merge_min_prop, e$k_max)
  out$confidence <- cmap$new[match(out$conf_raw, cmap$old)]

  # Syntactic, stable condition labels L1, L2, ... (brms coefficient names).
  cond_levels <- sort(unique(out$condition_raw))
  out$condition <- factor(paste0("L", match(out$condition_raw, cond_levels)))
  out$participant <- as.integer(factor(out$subj_raw))

  list(
    data = out[, c("participant", "stimulus", "response", "confidence", "condition",
                   "subj_raw", "conf_raw", "condition_raw", "correct")],
    K = max(cmap$new),
    conf_map = cmap,
    condition_map = tibble::tibble(label = paste0("L", seq_along(cond_levels)), raw = cond_levels),
    n_rows_filtered = n_rows_filtered,
    n_participants_raw = nrow(ps),
    n_participants_kept = length(keep),
    acc_agreement = acc_agreement,
    conf_acc_rho = conf_acc_rho
  )
}
