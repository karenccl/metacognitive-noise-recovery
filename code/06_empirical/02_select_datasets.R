# v3 empirical step 5.4 (docs/v3_plan.md): combine automatic screening with the
# manual difficulty coding (config/empirical_manual_coding.csv) and assign each
# dataset to an analysis set. Rules (config/v3.yml$empirical, fixed before any
# real-data fit; tag v3-prereg-empirical):
#   primary      perception, difficulty design constant or recorded_levels
#   sensitivity  perception, staircase
#   sensitivity_unrecorded
#                perception, unrecorded_varied -- ONLY if the G3 verdict
#                (data/processed/v3/g3_verdict.txt) is "no pooling artefact";
#                excluded otherwise (plan §4.7)
#   secondary    memory, constant or recorded_levels
# A recorded_levels dataset whose difficulty column has more than
# max_condition_levels levels (after the pre-specified row filters) is excluded.
# If more than max_datasets_primary are primary, a seeded random sample is kept.
#
# Run from the project root: Rscript code/06_empirical/02_select_datasets.R

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "eligibility.R"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
raw_dir <- here::here("data", "raw", "confidence_db")
out_dir <- here::here("data", "processed", "v3", "empirical")
screen <- readr::read_csv(file.path(out_dir, "screening_table.csv"), show_col_types = FALSE)
manual <- readr::read_csv(here::here("config", "empirical_manual_coding.csv"), show_col_types = FALSE,
                          col_types = readr::cols(exclude_filter = "c", difficulty_column = "c"))

verdict_file <- here::here("data", "processed", "v3", "g3_verdict.txt")
if (!file.exists(verdict_file)) stop("G3 verdict not found: run v3_g3_summary.R first (plan order).")
g3_no_artefact <- startsWith(readLines(verdict_file, n = 1), "no pooling artefact")

codable <- screen |> filter(auto_eligible, category %in% c(e$primary_category, e$secondary_category))
missing_codes <- setdiff(codable$dataset, manual$dataset)
if (length(missing_codes)) stop("not manually coded: ", paste(missing_codes, collapse = ", "))

# Levels of the difficulty column actually used, after the pre-specified filters.
n_levels_used <- function(ds, col, filt, cmin, cmax, rank) {
  if (is.na(col)) return(1L)
  d <- readr::read_csv(file.path(raw_dir, paste0("data_", ds, ".csv")), show_col_types = FALSE,
                       guess_max = 100000)
  d <- filter_rows(standardise_names(as.data.frame(d)), filt, c(cmin, cmax))
  d <- d[stats::complete.cases(d[, c(REQUIRED_COLS, col)]), ]
  if (isTRUE(rank)) return(as.integer(max(tapply(d[[col]], d$Subj_idx, function(x) length(unique(x))))))
  length(unique(d[[col]]))
}

cand <- screen |> inner_join(manual, by = "dataset") |>
  filter(auto_eligible, conf_higher_is_more) |>
  mutate(n_levels = purrr::pmap_int(list(dataset, difficulty_column, exclude_filter, conf_min, conf_max,
                                         rank_within_subject), n_levels_used),
         set = case_when(
           category == e$primary_category & difficulty_design %in% e$difficulty_designs_primary ~ "primary",
           category == e$primary_category & difficulty_design %in% e$difficulty_designs_sensitivity ~ "sensitivity",
           category == e$primary_category & difficulty_design == "unrecorded_varied" & g3_no_artefact ~
             "sensitivity_unrecorded",
           category == e$secondary_category & difficulty_design %in% e$difficulty_designs_primary ~ "secondary",
           TRUE ~ "excluded"),
         n_cond_ok = n_levels <= e$max_condition_levels) |>
  mutate(set = if_else(!n_cond_ok & set != "excluded", "excluded", set)) |>
  arrange(set, dataset)

# Cap the primary set by seeded random sampling (pre-specified).
prim <- filter(cand, set == "primary")
if (nrow(prim) > e$max_datasets_primary) {
  set.seed(cfg3$seed_base_v3)
  keep <- sample(sort(prim$dataset), e$max_datasets_primary)
  cand <- cand |> mutate(set = if_else(set == "primary" & !dataset %in% keep, "primary_not_sampled", set))
}
cand$g3_no_artefact <- g3_no_artefact
readr::write_csv(select(cand, -columns), file.path(out_dir, "selected_datasets.csv"))
print(count(cand, set))
