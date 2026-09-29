# Generalised replicated-data posterior predictive p-values for hmetad fits
# with any K and any grouping columns (docs/v3_plan.md §5.6), extracted from
# g2_ppp_fullfits.R. For K = 4 and group_cols = "participant" this reproduces
# g2_ppp_fullfits.R exactly (tests/test_ppp_functions.R).
#
# Statistics (as in v2 extension 2): stat1 aggregate RMSE over the 4K
# stimulus x response x confidence cells, stat2 mean |discrepancy| in the
# highest-confidence cells, stat3 group-level Pearson X2/df.
# p = mean over draws of T(y_rep) >= T(y).
#
# Callers must source code/01_simulate/simulate_g2_gumbel.R first for
# gumbel_min fits (hmetad's epred looks up gumbel_min_lcdf by name).

# Column layout of agg$N for any K: per stimulus, response 0 runs from
# confidence K down to 1, then response 1 from confidence 1 up to K.
make_col_map <- function(K) {
  expand.grid(confidence = seq_len(K), response = 0:1, stimulus = 0:1) |>
    dplyr::mutate(col = stimulus * 2L * K +
                    ifelse(response == 0, K - confidence + 1L, K + confidence)) |>
    dplyr::arrange(col) |>
    dplyr::select(stimulus, response, confidence, col) |>
    tibble::as_tibble()
}

ppp_one_fit_general <- function(fit, agg, K, group_cols = "participant", seed, ndraws = NULL) {
  col_map <- make_col_map(K)
  width   <- 2L * K                                   # columns per group x stimulus

  # With ndraws, tidybayes subsamples draws; pass the seed so that is repeatable.
  ep <- if (is.null(ndraws)) hmetad::epred_draws_metad(fit, agg)
        else hmetad::epred_draws_metad(fit, agg, ndraws = ndraws, seed = seed)
  ep <- ep |> dplyr::ungroup() |>
    dplyr::arrange(.draw, dplyr::across(dplyr::all_of(group_cols)), stimulus, response, confidence)
  n_draws <- dplyr::n_distinct(ep$.draw)
  n_cols  <- nrow(ep) / n_draws
  stopifnot(n_cols == round(n_cols), n_cols %% width == 0)
  P <- matrix(ep$.epred, nrow = n_draws, byrow = TRUE)

  cols <- ep |> dplyr::filter(.draw == min(.draw)) |>
    dplyr::select(dplyr::all_of(group_cols), stimulus, response, confidence) |>
    dplyr::left_join(col_map, by = c("stimulus", "response", "confidence"))
  stopifnot(nrow(cols) == n_cols, !anyNA(cols$col))
  n_groups <- n_cols / width
  group <- rep(seq_len(n_groups), each = width)
  stopifnot(all(tapply(cols$stimulus, group, dplyr::n_distinct) == 1))

  arr  <- array(P, c(n_draws, width, n_groups))
  sums <- apply(arr, c(1, 3), sum)
  stopifnot(max(abs(sums - 1)) < 1e-8)

  key  <- function(df) do.call(paste, c(lapply(group_cols, function(g) as.character(df[[g]])), sep = "|"))
  pidx <- match(key(cols), key(agg))
  stopifnot(!anyNA(pidx))
  obs  <- agg$N[cbind(pidx, cols$col)]
  n_ps <- ifelse(cols$stimulus == 0, agg$N_0[pidx], agg$N_1[pidx])
  stopifnot(all(tapply(obs, group, sum) == tapply(n_ps, group, unique)))

  n_cells <- 4L * K
  A <- outer(cols$col, seq_len(n_cells), `==`) * 1
  cell_stim   <- col_map$stimulus[order(col_map$col)]
  tot_by_cell <- ifelse(cell_stim == 0, sum(agg$N_0), sum(agg$N_1))
  conf_top    <- col_map$col[col_map$confidence == K]
  n_rows      <- nrow(agg)
  df3         <- n_rows * n_cells - n_rows * 2

  E   <- sweep(P, 2, n_ps, `*`)
  E16 <- E %*% A
  discrepancies <- function(Y) {
    d <- sweep(Y %*% A - E16, 2, tot_by_cell, `/`)
    cbind(stat1_rmse     = sqrt(rowMeans(d^2)),
          stat2_highconf = rowMeans(abs(d[, conf_top, drop = FALSE])),
          stat3_x2_df    = rowSums((Y - E)^2 / E) / df3)
  }

  # Replicated data: sequential conditional binomials = one multinomial per
  # draw x group x stimulus. set.seed() position matches g2_ppp_fullfits.R.
  set.seed(seed)
  n_rem <- matrix(rep(n_ps[seq(1, n_cols, by = width)], each = n_draws), n_draws, n_groups)
  p_rem <- matrix(1, n_draws, n_groups)
  Yarr  <- array(0L, c(n_draws, width, n_groups))
  for (k in seq_len(width - 1L)) {
    pk <- arr[, k, ]
    q  <- pmin(pmax(pk / pmax(p_rem, 1e-300), 0), 1)
    yk <- matrix(stats::rbinom(length(n_rem), n_rem, q), n_draws, n_groups)
    Yarr[, k, ] <- yk
    n_rem <- n_rem - yk
    p_rem <- p_rem - pk
  }
  Yarr[, width, ] <- n_rem
  Yrep <- matrix(Yarr, n_draws, n_cols)

  T_obs <- discrepancies(matrix(obs, n_draws, n_cols, byrow = TRUE))
  T_rep <- discrepancies(Yrep)
  p <- colMeans(T_rep >= T_obs)
  tibble::tibble(n_draws = n_draws, n_groups = n_groups,
                 p_stat1_rmse = p[["stat1_rmse"]],
                 p_stat2_highconf = p[["stat2_highconf"]],
                 p_stat3_x2_df = p[["stat3_x2_df"]],
                 mean_obs_stat1 = mean(T_obs[, "stat1_rmse"]),
                 mean_rep_stat1 = mean(T_rep[, "stat1_rmse"]),
                 mean_obs_stat2 = mean(T_obs[, "stat2_highconf"]),
                 mean_rep_stat2 = mean(T_rep[, "stat2_highconf"]))
}
