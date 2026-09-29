# Run one shard of the G3 grid sequentially (resumable; finished ids are skipped).
# Usage: Rscript code/02_fit/run_g3_shard.R <shard> <n_shards>
args <- commandArgs(trailingOnly = TRUE)
shard <- as.integer(args[1]); n_shards <- as.integer(args[2])
ids <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)$g3_id
rscript <- file.path(R.home("bin"), "Rscript")
for (id in ids[(ids - 1L) %% n_shards == (shard - 1L)]) {
  system2(rscript, c(here::here("code", "02_fit", "run_one_cell_g3.R"), id))
}
