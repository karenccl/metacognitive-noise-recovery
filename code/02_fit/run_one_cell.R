# Command-line entry point: takes grid_id and rep_id, derives a
# deterministic seed from generator + grid_id + rep_id, checks whether
# output already exists (resumable), simulates, fits, extracts, and
# saves an atomic result to e.g. data/interim/g1_cell-012_rep-017.qs.
# Wraps the run in tryCatch() and writes a structured error record on
# failure instead of throwing (protocol section 5, Day 2).

# args <- commandArgs(trailingOnly = TRUE)
