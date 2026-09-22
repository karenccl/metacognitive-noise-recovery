# Single named function implementing the locked K=4 rank-based,
# within-subject discretisation rule applied to a continuous confidence
# readout (protocol sections 1.3, 1.4). Must preserve/return cut-points
# per subject and be usable for the K=6 / fixed-cutpoint sensitivity
# analysis as well.
#
# Contract:
#   input:  data.frame with a participant id column and a continuous
#           confidence readout column, one row per trial
#   output: list(
#     data            = input augmented with an integer `confidence`
#                       column in 1:K (rank-based within-subject bins,
#                       via dplyr::ntile -- ties broken by row order,
#                       not by value, so marginal counts are ~n/K per
#                       subject by construction; see docs/design_decisions.md)
#     cutpoints       = one row per subject: the K-1 empirical quantile
#                       cut-points actually used, plus per-subject
#                       degeneracy flags
#     category_counts = long-format confidence category counts per subject
#     tie_summary     = one-row overall degeneracy summary
#   )
#
# "Degenerate" here means duplicate values in the continuous readout
# that straddle a bin boundary: dplyr::ntile() still assigns them to
# different bins (via row order), so a high tie rate means the K=4
# labels partly reflect arbitrary tie-breaking rather than genuine
# ordering. This is the check protocol section 1.4 asks for.

discretise_confidence <- function(data, participant_col, value_col, k = 4) {
  stopifnot(is.data.frame(data), k >= 2)
  stopifnot(participant_col %in% names(data), value_col %in% names(data))
  stopifnot(!anyNA(data[[value_col]]))

  data$confidence <- NULL
  data <- dplyr::group_by(data, dplyr::across(dplyr::all_of(participant_col)))
  data <- dplyr::mutate(data, confidence = dplyr::ntile(.data[[value_col]], k))
  data <- dplyr::ungroup(data)

  cutpoints <- dplyr::group_by(data, dplyr::across(dplyr::all_of(participant_col)))
  cutpoints <- dplyr::summarise(
    cutpoints,
    n_trials = dplyr::n(),
    cutpoint_values = list(stats::quantile(
      .data[[value_col]], probs = (1:(k - 1)) / k, type = 1, names = FALSE
    )),
    n_duplicate_values = sum(duplicated(.data[[value_col]]) |
      duplicated(.data[[value_col]], fromLast = TRUE)),
    .groups = "drop"
  )
  cutpoints <- tidyr::unnest_wider(cutpoints, "cutpoint_values", names_sep = "_")
  cutpoint_cols <- grep("^cutpoint_values_", names(cutpoints), value = TRUE)
  cutpoints$n_degenerate_cutpoints <- apply(
    as.matrix(cutpoints[cutpoint_cols]), 1,
    function(row) sum(duplicated(row))
  )

  category_counts <- dplyr::count(
    data,
    dplyr::across(dplyr::all_of(participant_col)),
    confidence,
    name = "n"
  )

  tie_summary <- tibble::tibble(
    k = k,
    n_participants = dplyr::n_distinct(data[[participant_col]]),
    total_trials = nrow(data),
    total_duplicate_values = sum(cutpoints$n_duplicate_values),
    proportion_duplicate_values = sum(cutpoints$n_duplicate_values) / nrow(data),
    total_degenerate_cutpoints = sum(cutpoints$n_degenerate_cutpoints)
  )

  list(
    data = data,
    cutpoints = cutpoints,
    category_counts = category_counts,
    tie_summary = tie_summary
  )
}
