# v3 empirical step 5.2/5.4 (docs/v3_plan.md): automatic screening of every
# Confidence Database dataset against config/v3.yml$empirical rules, joined
# to the database's dataset-level metadata. Also writes the raw-file md5
# manifest. No model is fitted here.
#
# Run from the project root: Rscript code/06_empirical/01_screen_datasets.R

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "eligibility.R"))
e <- yaml::read_yaml(here::here("config", "v3.yml"))$empirical
raw_dir <- here::here("data", "raw", "confidence_db")
out_dir <- here::here("data", "processed", "v3", "empirical")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---- manifest: lets others confirm they have the same raw files -------------
all_files <- sort(list.files(raw_dir, full.names = TRUE))
manifest <- tibble::tibble(file = basename(all_files), md5 = unname(tools::md5sum(all_files)),
                           bytes = file.size(all_files))
readr::write_csv(manifest, file.path(out_dir, "raw_manifest.csv"))

# ---- per-dataset screening --------------------------------------------------
files <- sort(list.files(raw_dir, pattern = "^data_.*[.]csv$", full.names = TRUE))
screen <- purrr::map_dfr(files, function(f) {
  d <- readr::read_csv(f, show_col_types = FALSE, guess_max = 100000)
  dplyr::bind_cols(tibble::tibble(dataset = sub("^data_(.*)[.]csv$", "\\1", basename(f)),
                                  columns = paste(names(d), collapse = ";")),
                   screen_raw(d, e$min_trials_per_participant))
})
screen <- apply_auto_rules(screen, e)

# Dataset-level metadata (sheet "Database_Information"; checked 2026-09-30).
info <- readxl::read_excel(file.path(raw_dir, "Database_Information.xlsx"))
info <- info |> dplyr::transmute(dataset = .data[["Name_in_database"]],
                                 category = tolower(.data[["Category"]]),
                                 category_raw = .data[["Category"]],
                                 stimuli = .data[["Stimuli"]],
                                 confidence_scale = .data[["Confidence_scale"]],
                                 manipulations = .data[["Manipulations"]],
                                 num_tasks_x_conditions = .data[["Num_tasks_x_conditions"]])
stopifnot(!anyDuplicated(info$dataset))
screen <- screen |> left_join(info, by = "dataset")
if (anyNA(screen$category)) {
  warning("datasets without metadata: ", paste(screen$dataset[is.na(screen$category)], collapse = ", "))
}

readr::write_csv(screen, file.path(out_dir, "screening_table.csv"))
cat("Auto-eligible:", sum(screen$auto_eligible, na.rm = TRUE), "of", nrow(screen), "\n")
print(count(filter(screen, auto_eligible), category), n = Inf)
