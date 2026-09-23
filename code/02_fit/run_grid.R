# Iterate config/grid.csv (optionally filtered by --generator) and
# invoke run_one_cell.R as a subprocess for every grid_id, skipping
# cells whose output already exists (resumable). Each row runs in its
# own Rscript process so a Stan compile/sampling crash on one cell
# can't take down the batch.
#
# Runs up to config/design.yml's execution.max_concurrent_fits rows at
# once (each fit itself uses sampling.chains cores via brms cores=chains,
# so total cores in use is bounded by max_concurrent_fits * chains --
# see docs/design_decisions.md's compute-benchmark writeup for the sizing
# rationale). Uses processx for portable (Windows/Unix) background
# process management with a simple poll loop.
#
# Usage: Rscript code/02_fit/run_grid.R [--generator g0|g1|g2] [--max-concurrent N]

args <- commandArgs(trailingOnly = TRUE)

get_flag <- function(name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) == 1 && length(args) > idx) args[idx + 1] else default
}

generator_filter <- get_flag("--generator")
cfg <- yaml::read_yaml(here::here("config", "design.yml"))
max_concurrent <- as.integer(get_flag("--max-concurrent", cfg$execution$max_concurrent_fits))

grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
if (!is.null(generator_filter)) {
  grid <- grid[grid$generator == generator_filter, ]
}

out_dir <- here::here("data", "interim")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

output_path_for <- function(row) {
  variant_suffix <- if (row$fit_variant != "default") paste0("_", row$fit_variant) else ""
  file.path(out_dir, sprintf(
    "%s_cell-%04d_rep-%02d%s_grid-%05d.qs2",
    row$generator, row$cell_id, row$rep_id, variant_suffix, row$grid_id
  ))
}

is_done <- function(row) file.exists(output_path_for(row))

pending_idx <- which(!vapply(seq_len(nrow(grid)), function(i) is_done(grid[i, ]), logical(1)))
pending <- grid[pending_idx, ]

cat("Grid rows:", nrow(grid), "| already done:", nrow(grid) - nrow(pending),
    "| pending:", nrow(pending), "| max_concurrent:", max_concurrent, "\n")

if (nrow(pending) == 0) {
  cat("Nothing to do.\n")
  quit(save = "no", status = 0)
}

run_one_cell_path <- here::here("code", "02_fit", "run_one_cell.R")
rscript_bin <- file.path(R.home("bin"), "Rscript")

# pool: named list of processx::process objects keyed by grid_id (as character)
pool <- list()
next_idx <- 1L
n_total <- nrow(pending)
n_finished <- 0L

launch_next <- function() {
  row <- pending[next_idx, ]
  gid <- row$grid_id
  cat(sprintf("[launch %d/%d] grid_id=%d (%s, cell=%d, rep=%d, variant=%s)\n",
              next_idx, n_total, gid, row$generator, row$cell_id, row$rep_id, row$fit_variant))
  p <- processx::process$new(
    rscript_bin, c(run_one_cell_path, as.character(gid)),
    stdout = "|", stderr = "|"
  )
  pool[[as.character(gid)]] <<- p
  next_idx <<- next_idx + 1L
}

while (next_idx <= n_total && length(pool) < max_concurrent) {
  launch_next()
}

while (length(pool) > 0) {
  Sys.sleep(2)
  finished_ids <- character(0)
  for (gid_chr in names(pool)) {
    p <- pool[[gid_chr]]
    if (!p$is_alive()) {
      status <- p$get_exit_status()
      out <- tryCatch(p$read_all_output_lines(), error = function(e) character(0))
      err <- tryCatch(p$read_all_error_lines(), error = function(e) character(0))
      n_finished <<- n_finished + 1L
      cat(sprintf("[done %d/%d] grid_id=%s exit_status=%s\n", n_finished, n_total, gid_chr, status))
      if (length(out) > 0) cat(paste0("  ", tail(out, 3)), sep = "\n")
      if (!identical(status, 0L) && length(err) > 0) {
        cat("  STDERR:\n", paste0("    ", tail(err, 10), collapse = "\n"), "\n")
      }
      finished_ids <- c(finished_ids, gid_chr)
    }
  }
  for (gid_chr in finished_ids) pool[[gid_chr]] <- NULL
  while (next_idx <= n_total && length(pool) < max_concurrent) {
    launch_next()
  }
}

cat("Done.\n")
