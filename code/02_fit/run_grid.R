# Iterate config/grid.csv (optionally filtered by --generator) and
# invoke run_one_cell.R for every grid_id x rep_id, skipping cells
# whose output already exists. Safe to re-invoke (resumable), used by
# the Makefile g0/g1/g2 targets.
