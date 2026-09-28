# Validate config/design.yml (run by `make setup`). Every other script reads
# this file directly; this step fails early if a required key is missing or
# implausible so a bad edit does not surface hours into a grid run.

cfg <- yaml::read_yaml(here::here("config", "design.yml"))

need <- list(
  c("seed_base"), c("grid", "replications", "target"), c("ddm", "v_by_dprime_target"),
  c("ddm", "sigma_c_values"), c("sampling", "chains"), c("sampling", "adapt_delta"),
  c("execution", "max_concurrent_fits"), c("diagnostics", "rhat_max"),
  c("fitting", "hierarchical_dprime_c"), c("priors", "log_M_production"), c("truth", "log_M")
)
absent <- vapply(need, function(k) is.null(purrr::pluck(cfg, !!!k)), logical(1))
if (any(absent)) {
  stop("design.yml is missing: ", paste(vapply(need[absent], paste, "", collapse = "$"), collapse = ", "), call. = FALSE)
}
stopifnot(
  identical(names(cfg$ddm$sigma_c_values), c("low", "medium", "high")),
  all(diff(unlist(cfg$ddm$sigma_c_values)) > 0),
  cfg$sampling$adapt_delta > 0, cfg$sampling$adapt_delta < 1
)
cat(sprintf("design.yml OK: seed_base %s, %s reps/cell, %s chains, %s concurrent fits, truth log_M = %s\n",
            cfg$seed_base, cfg$grid$replications$target, cfg$sampling$chains,
            cfg$execution$max_concurrent_fits, cfg$truth$log_M))
