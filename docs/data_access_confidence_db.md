# Confidence Database: data access record (v3 empirical analysis)

## Source

- **Database:** The Confidence Database (Rahnev et al., 2020), OSF project `s46pr`,
  <https://osf.io/s46pr/>, folder `Confidence Database/` plus the dataset-level metadata sheet
  `Database_Information.xlsx` (OSF guid `xkc7b`, dated 2025-08-31 on OSF).
- **Downloaded:** 2026-09-30 through the OSF v2 API (`api.osf.io/v2/nodes/s46pr/files/osfstorage/`).
  The OSF project was last modified 2026-09-03.
- **Contents:** 361 files, 255.4 MB: 180 `data_<name>.csv`, 180 `readme_<name>.txt`, and
  `Database_Information.xlsx` (one sheet, `Database_Information`, 180 rows, 16 columns).
- **Integrity:** every file matched the md5 hash reported by the OSF API. Hashes and sizes of the
  local copies are in `data/processed/v3/empirical/raw_manifest.csv`, so anyone can check they
  have the same files.
- **Location:** `data/raw/confidence_db/` (git-ignored by `data/raw/*`; raw data are not
  redistributed with this repository).

## Licence

The OSF project's licence field reads **CC0 1.0 Universal** (copyright year 2019, no named
holders), as returned by the OSF API on 2026-09-30. CC0 places the data in the public domain.
Citing the database paper and the original studies is still expected scholarly practice.

## How to cite

- Database: Rahnev, D., Desender, K., Lee, A. L. F., Adler, W. T., Aguilar-Lleyda, D., Akdoğan, B.,
  ... Zylberberg, A. (2020). The Confidence Database. *Nature Human Behaviour, 4*(3), 317–325.
  https://doi.org/10.1038/s41562-019-0813-1
- Every dataset used in an analysis must also be cited by its own source. The citation of each
  dataset is given in its `readme_<name>.txt`. The analysed list is `set != "excluded"` rows of
  `data/processed/v3/empirical/selected_datasets.csv` that are `usable` in `prepare_log.csv`.

## Column conventions relied on

Standard columns `Subj_idx`, `Stimulus`, `Response`, `Confidence` (optional `Accuracy`,
`Condition`). A few datasets use other capitalisations (e.g. `stimulus`, `confidence`) or
`subject_id`. `standardise_names()` in `code/06_empirical/eligibility.R` renames unique
case-insensitive matches. Datasets that store one column per task (`Confidence_1`,
`Confidence_2`, `*_col`, `*_let`) fail the required-column rule and are not analysed.

## Reproduce

Download the same files (`python`-free route: the OSF web interface "Download as zip" of the
`Confidence Database` folder plus `Database_Information.xlsx`) into `data/raw/confidence_db/`,
check them against `raw_manifest.csv`, then run the `v3-empirical-screen` Makefile target.
