# v3b work package C: two groups of participants that differ ONLY in d'
# (same true log_M), simulated from the gumbel_min generator used for G2.
# Group B participants get ids offset by the size of group A, so ids are unique.
# Requires code/01_simulate/simulate_g2_gumbel.R to be sourced first.

simulate_two_group_g2 <- function(n_per_group, n_trials, dprime_groups, log_M,
                                  k = 4, seed) {
  stopifnot(all(c("A", "B") %in% names(dprime_groups)))
  a <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["A"]], log_M, k = k, seed = seed)
  b <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["B"]], log_M, k = k,
                          seed = seed + 100000L)
  a$participant <- as.integer(a$participant)
  b$participant <- as.integer(b$participant) + max(a$participant)
  a$group <- "A"; b$group <- "B"
  out <- dplyr::bind_rows(a, b)
  out$group <- factor(out$group, levels = c("A", "B"))
  out
}
