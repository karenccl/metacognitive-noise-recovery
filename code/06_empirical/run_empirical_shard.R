# Run one shard of the empirical fits (prepared datasets x 2 families),
# sequentially and resumably (finished fits are skipped).
# Usage: Rscript code/06_empirical/run_empirical_shard.R <shard> <n_shards>
args <- commandArgs(trailingOnly = TRUE)
shard <- as.integer(args[1]); n_shards <- as.integer(args[2])
prep_dir <- here::here("data", "interim", "v3_empirical", "prepared")
jobs <- tidyr::expand_grid(dataset = sort(sub("[.]qs2$", "", list.files(prep_dir, "[.]qs2$"))),
                           family  = c("normal", "gumbel_min"))
rscript <- file.path(R.home("bin"), "Rscript")
idx <- seq_len(nrow(jobs))
for (i in idx[(idx - 1L) %% n_shards == (shard - 1L)]) {
  system2(rscript, c(here::here("code", "06_empirical", "04_fit_dataset.R"),
                     jobs$dataset[i], jobs$family[i]))
}
