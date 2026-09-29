# Project 1 v3 強化：程式實作指南

> 範圍：**只涵蓋程式與分析**（文獻定位、寫作、投稿不在此文件）。
> 對應 repo：`metacognitive-noise-recovery`（目前 `main` = `v1.2.1`，已有 `v2-extensions` 分支）。
> 本輪命名為 **v3**，所有新輸出放在 `v3` 子資料夾，避免和既有 `v2` 輸出混淆。
> 寫於 2026-09-29。依你 repo 現有程式碼（`fit_hmetad.R`、`run_one_cell.R`、`loo_comparison.R`、`g2_ppp_fullfits.R`）設計。

---

## 目錄

- [0. 總覽與規則](#0-總覽與規則)
- [1. 環境準備（半天）](#1-環境準備半天)
- [2. 步驟 1：相對偏差重新分析（1–2 天，不需新擬合）](#2-步驟-1相對偏差重新分析12-天不需新擬合)
- [3. 步驟 2：LOO 穩健化（1–2 天，含背景運算）](#3-步驟-2loo-穩健化12-天含背景運算)
- [4. 步驟 3：難度混合模擬 G3（1–2 天）](#4-步驟-3難度混合模擬-g312-天)
- [5. 步驟 4：Confidence Database 實證分析（1–2 週）](#5-步驟-4confidence-database-實證分析12-週)
- [6. 步驟 5：新圖表](#6-步驟-5新圖表)
- [7. Makefile、測試與收尾](#7-makefile測試與收尾)
- [附錄 A：常見錯誤排除](#附錄-a常見錯誤排除)
- [附錄 B：決定點總表](#附錄-b決定點總表)

---

## 0. 總覽與規則

### 0.1 四個工作包

| 步驟 | 回答的問題 | 需要新擬合？ | 預估時間 |
|---|---|---|---|
| 1 相對偏差 | 錯設本身造成多少偏差？隨 d′、N、T 如何變化？ | 否 | 1–2 天 |
| 2 LOO 穩健化 | 96.2% 的 LOO 結果在 Pareto-k 問題下還成立嗎？ | 是（~150 次重擬合，背景跑） | 1–2 天 |
| 3 G3 混合模擬 | 合併不同難度的試次，是否會讓 LOO 假性偏好 Gumbel-min？ | 是（160 次） | 1–2 天 |
| 4 實證分析 | 真實資料偏好哪個分佈？換分佈後 log(M) 和條件差異改變多少？ | 是（每資料集 2 次） | 1–2 週 |

**順序不可調換**：步驟 3 的結果決定步驟 4 如何處理難度；步驟 2 的方法會在步驟 4 重用。

### 0.2 固定規則（整個 v3 都適用）

1. **分支**：從 `main` 開新分支 `v3-enhancement`。每完成一個子步驟就 commit 一次。
2. **不改動既有輸出**：v1/v2 的 `data/processed/*.csv` 與圖不覆寫。新東西寫到：
   - `data/processed/v3/`（小型結果表，進 Git）
   - `data/interim/v3_*/`（每次擬合的檔案，已被 `.gitignore` 的 `*.qs2` 規則排除）
   - `outputs/figures/v3/`
   - 注意：`compile_results.R` 用的是**非遞迴**的 `list.files(data/interim)`，所以放在子資料夾的 v3 檔案不會污染既有彙整。
3. **修改既有函式時必須向下相容**：預設參數下的行為要和 v1.2.1 完全一樣（第 4.2 節有回歸測試）。
4. **先寫規則、再看結果**：G3 和實證分析的判斷規則寫進 `config/v3.yml` 並 commit + tag，之後才跑擬合。
5. **每一步都在 `docs/analysis_log.md` 記一段**：日期、跑了什麼、結果檔名、任何偏離計劃之處。
6. **符號慣例（全 v3 統一，寫進 `config/v3.yml`）**：
   - `delta_mis = log_M(高斯) − log_M(正確/Gumbel)`：正值 = 高斯模型高估。
   - `elpd_diff = elpd(高斯) − elpd(Gumbel)`：**正值 = 偏好高斯**。
     ⚠️ 這和既有 `g2_elpd_comparison.csv` 的 `elpd_diff_correct_minus_mis` 方向相反（那裡正值 = 偏好正確 = Gumbel）。實證分析沒有「正確模型」，所以改以家族命名。畫圖或寫報告時務必標清楚。

### 0.3 新增檔案一覽

```text
config/v3.yml                                   # 所有 v3 常數與事先規定的規則
config/grid_g3.csv                              # G3 網格（由腳本產生）
config/empirical_manual_coding.csv              # 手動編碼的資料集難度設計（擬合前完成）
code/00_setup/03_create_grid_g3.R
code/01_simulate/simulate_g3_mixture.R
code/02_fit/fit_hmetad.R                        # 修改：新增共變項/多欄聚合參數（向下相容）
code/02_fit/run_one_cell_g3.R
code/03_recovery_analysis/relative_bias.R
code/04_ppc_and_comparison/v3_reloo_stored_fits.R
code/04_ppc_and_comparison/v3_kfold_stored_fits.R   # 可選
code/04_ppc_and_comparison/v3_loo_robust_summary.R
code/04_ppc_and_comparison/ppp_functions.R      # 由 g2_ppp_fullfits.R 抽出並泛化到任意 K
code/04_ppc_and_comparison/v3_g3_summary.R
code/06_empirical/eligibility.R                 # 純函式：篩選規則、merge_sparse_levels、harmonise
code/06_empirical/01_screen_datasets.R
code/06_empirical/02_select_datasets.R
code/06_empirical/03_prepare_datasets.R
code/06_empirical/04_fit_dataset.R
code/06_empirical/05_loo_repair.R
code/06_empirical/06_ppc_dataset.R
code/06_empirical/07_summarise_empirical.R
code/05_figures/fig_6_relative_bias.R
code/05_figures/fig_7_loo_robust.R
code/05_figures/fig_8_g3_mixture.R
code/05_figures/fig_9_empirical.R
tests/test_formula_backcompat.R
tests/test_ppp_functions.R
tests/test_eligibility.R
tests/fixtures/formula_k4_v121.rds              # 修改 fit_hmetad.R 之前產生
docs/v3_plan.md                                 # 就是這份文件
docs/data_access_confidence_db.md
```

---

## 1. 環境準備（半天）

### 1.1 開分支

```bash
cd metacognitive-noise-recovery
git checkout main
git pull
git checkout -b v3-enhancement
```

### 1.2 安裝新套件並更新 lockfile

在 R（專案根目錄，確認 `.libPaths()` 指向 `renv/library/`）：

```r
.libPaths()                 # 第一個路徑必須在 renv/library/ 底下
renv::install(c("readxl"))  # 讀 Confidence Database 的說明試算表
renv::snapshot()
```

`loo`、`brms`、`hmetad`、`qs2`、`posterior`、`testthat` 已在 lockfile 內。

### 1.3 API 確認（每個套件版本行為可能不同，先確認再寫碼）

在 R console 逐條執行，**把輸出貼進 `docs/analysis_log.md`**：

```r
library(brms); library(hmetad)
packageVersion("brms"); packageVersion("hmetad"); packageVersion("loo")

# (a) loo() 是否有 reloo 參數，reloo 的參數長什麼樣
args(brms:::loo.brmsfit)
args(brms::reloo)
# (b) reloo / kfold 預測被留出的受試者時是否允許新層級（new levels）
grep("allow_new_levels", deparse(brms:::reloo.brmsloo), value = TRUE)
grep("allow_new_levels", deparse(brms:::kfold.brmsfit), value = TRUE)
# 若 (b) 沒有找到，這兩個函式可能透過 ... 轉傳；看函式本體確認 ... 傳到 log_lik()
# (c) aggregate_metad 能否接受多個分組欄位
args(hmetad::aggregate_metad)
# (d) epred_draws_metad 是否支援 ndraws（實證資料很大時需要抽樣）
args(hmetad::epred_draws_metad)
```

判斷：

| 檢查 | 若為「是」 | 若為「否」 |
|---|---|---|
| (a) `loo.brmsfit` 有 `reloo` | 用 3.2 節的主要寫法 | 用 `brms::reloo(loo_obj, fit = fit, ...)` 的替代寫法（3.2 節有） |
| (b) 有 `allow_new_levels = TRUE` | 不用額外傳參數 | 在呼叫時手動加 `allow_new_levels = TRUE`；若報錯「unused argument」，記錄下來並只用 kfold |
| (c) `...` 是 tidy-select 分組 | 4.2 節的修改可直接用 | 先在 R 端 `interaction()` 成單一欄位再聚合（4.2 節末尾有備案） |
| (d) 有 `ndraws` | 實證 PPC 用 `ndraws = 1000` | 先 `brms::as_draws_df()` 抽樣後用 `subset_draws()` 做較小的 fit 副本 |

### 1.4 建立 `config/v3.yml`

```yaml
# v3 enhancement constants (docs/v3_plan.md). Locked before any v3 fit.
version: v3
seed_base_v3: 20261001

sign_conventions:
  delta_mis: "log_M(normal) - log_M(correct or gumbel_min); positive = Gaussian higher"
  elpd_diff_empirical: "elpd(normal) - elpd(gumbel_min); positive = Gaussian preferred"

loo_robust:
  k_threshold: 0.7
  kfold_K: 5

g3:
  n_participants: 40
  n_trials_per_level: 200          # 2 levels -> 400 trials/participant, matches largest G0/G2 cell
  replications: 20
  conditions:
    control: [1.25, 1.25]          # same d' in both halves (no mixture), mean d' = 1.25
    mixture: [0.5, 2.0]            # two difficulty levels, mean d' = 1.25
  fit_variants: [normal_pooled, gumbel_pooled, normal_difficulty, gumbel_difficulty]
  # Pre-specified decision rule (evaluated in v3_g3_summary.R):
  # "pooling artefact present" if, in the mixture condition, the pooled comparison
  # favours gumbel_min by > 2 SE in >= 25% of replications AND in the control
  # condition in <= 10% of replications.
  artefact_rule:
    mixture_min_prop: 0.25
    control_max_prop: 0.10

empirical:
  primary_category: perception
  secondary_category: memory         # optional analysis, reported separately
  min_participants: 20
  min_trials_per_participant: 100
  accuracy_range: [0.55, 0.95]       # participant exclusion
  conf_levels_range: [3, 11]         # discrete scales only; > 11 treated as continuous -> excluded
  merge_min_prop: 0.05               # merge adjacent confidence levels used on < 5% of trials
  k_max: 6
  k_min: 3
  max_condition_levels: 4
  difficulty_designs_primary: [constant, recorded_levels]
  difficulty_designs_sensitivity: [staircase]
  max_datasets_primary: 20           # if more are eligible, sample this many with seed_base_v3
  hierarchical_thresholds: true      # REQUIRED for real data (participants differ in criteria)
  loo_repair:
    max_prop_bad_k_for_reloo: 0.10   # above this, use grouped K-fold instead of reloo
  categories:
    two_se_rule: 2                   # |elpd_diff| > 2 * se_diff -> "clear"
```

Commit：

```bash
git add config/v3.yml docs/v3_plan.md renv.lock
git commit -m "v3: add plan and locked v3 constants"
```

---

## 2. 步驟 1：相對偏差重新分析（1–2 天，不需新擬合）

### 2.1 為什麼

目前報告的「偏差 +0.06 到 +0.20」是**相對真值**，裡面混了兩樣東西：錯設本身，以及連正確模型都有的基線偏差（G0 也有的小幅負偏差）。把兩者拆開，主要結論才乾淨。

### 2.2 `code/03_recovery_analysis/relative_bias.R`

```r
# v3 step 1: decompose G2 log_M error into (a) misspecification effect
# delta_mis = log_M(normal fit) - log_M(correct fit), paired on the SAME
# simulated dataset, and (b) baseline error of the correct fit
# bias_correct = log_M(correct) - truth. No refitting; reads
# data/processed/compiled_results.csv and config/grid.csv only.
#
# Run from the project root: Rscript code/03_recovery_analysis/relative_bias.R

suppressPackageStartupMessages(library(dplyr))

cfg   <- yaml::read_yaml(here::here("config", "design.yml"))
truth <- cfg$truth$log_M
out   <- here::here("data", "processed", "v3")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

res  <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE) |>
  select(grid_id, sim_seed)

keys <- c("n_participants", "n_trials", "dprime_target", "rep_id")

# ---- Pair the two G2 fits of each simulated dataset -------------------------
g2 <- res |>
  filter(generator == "g2") |>
  left_join(grid, by = "grid_id") |>
  mutate(covered  = log_M_q025 <= truth & truth <= log_M_q975,
         ci_width = log_M_q975 - log_M_q025) |>
  select(all_of(keys), fit_variant, sim_seed, status, log_M_mean, covered, ci_width)

wide <- g2 |>
  tidyr::pivot_wider(names_from = fit_variant,
                     values_from = c(sim_seed, status, log_M_mean, covered, ci_width))

# Integrity checks: 240 datasets, both variants fitted to the identical data.
stopifnot(nrow(wide) == 240,
          !anyNA(wide$log_M_mean_correct), !anyNA(wide$log_M_mean_misspecified),
          all(wide$sim_seed_correct == wide$sim_seed_misspecified))

by_fit <- wide |>
  mutate(delta_mis    = log_M_mean_misspecified - log_M_mean_correct,
         bias_correct = log_M_mean_correct - truth,
         bias_mis     = log_M_mean_misspecified - truth,
         both_pass    = status_correct == "pass" & status_misspecified == "pass",
         any_error    = status_correct == "error" | status_misspecified == "error")
stopifnot(!any(by_fit$any_error))   # if this fails, drop error rows explicitly and log it
readr::write_csv(by_fit, file.path(out, "g2_relative_bias_by_fit.csv"))

# ---- Per-cell summary (primary = pass + fail, sensitivity = both pass) -------
mcse <- function(x) stats::sd(x) / sqrt(length(x))
summarise_cells <- function(d) d |>
  group_by(n_participants, n_trials, dprime_target) |>
  summarise(n              = n(),
            delta_mean     = mean(delta_mis),
            delta_mcse     = mcse(delta_mis),
            delta_median   = median(delta_mis),
            delta_q025     = quantile(delta_mis, 0.025, names = FALSE),
            delta_q975     = quantile(delta_mis, 0.975, names = FALSE),
            prop_delta_pos = mean(delta_mis > 0),
            base_mean      = mean(bias_correct),
            base_mcse      = mcse(bias_correct),
            cover_correct  = mean(covered_correct),
            cover_mis      = mean(covered_misspecified),
            width_correct  = mean(ci_width_correct),
            width_mis      = mean(ci_width_misspecified),
            .groups = "drop")

cells_primary     <- summarise_cells(by_fit) |> mutate(analysis = "primary")
cells_sensitivity <- summarise_cells(filter(by_fit, both_pass)) |> mutate(analysis = "pass_only")
readr::write_csv(bind_rows(cells_primary, cells_sensitivity),
                 file.path(out, "g2_relative_bias_by_cell.csv"))

# ---- d' contrast: is the misspecification effect larger at low d'? ----------
# Seeds differ across cells, so low- and high-d' cells are INDEPENDENT samples:
# SE of a difference = sqrt(se1^2 + se2^2). Do not pair replications across cells.
dprime_contrast <- cells_primary |>
  mutate(dlev = if_else(dprime_target == 0.75, "low", "high")) |>
  select(n_participants, n_trials, dlev, delta_mean, delta_mcse) |>
  tidyr::pivot_wider(names_from = dlev, values_from = c(delta_mean, delta_mcse)) |>
  mutate(diff_low_minus_high = delta_mean_low - delta_mean_high,
         se_diff = sqrt(delta_mcse_low^2 + delta_mcse_high^2),
         z = diff_low_minus_high / se_diff)
pooled <- dprime_contrast |>
  summarise(n_cells = n(),
            diff_low_minus_high = mean(diff_low_minus_high),
            se_diff = sqrt(sum(se_diff^2)) / n(),
            n_cells_positive = sum(diff_low_minus_high > 0))
readr::write_csv(dprime_contrast, file.path(out, "g2_dprime_contrast_by_NT.csv"))
readr::write_csv(pooled, file.path(out, "g2_dprime_contrast_pooled.csv"))

# ---- Persistence: does delta_mis shrink with more data? ---------------------
# A slope near 0 for log2(n_trials) with a clearly non-zero intercept = the
# misspecification effect does not vanish with data (pseudo-true displacement).
persist_fit <- lm(delta_mis ~ log2(n_trials) + factor(n_participants) + factor(dprime_target),
                  data = by_fit)
persist <- tibble::tibble(term = names(coef(persist_fit)),
                          estimate = coef(persist_fit),
                          lo = confint(persist_fit)[, 1],
                          hi = confint(persist_fit)[, 2])
readr::write_csv(persist, file.path(out, "g2_delta_persistence_lm.csv"))

# "More confidently wrong": interval width shrinks while delta stays.
confidently_wrong <- by_fit |>
  group_by(n_trials, dprime_target) |>
  summarise(mean_width_mis = mean(ci_width_misspecified),
            mean_delta     = mean(delta_mis),
            prop_mis_excludes_truth = mean(!covered_misspecified),
            .groups = "drop")
readr::write_csv(confidently_wrong, file.path(out, "g2_confidently_wrong.csv"))

# ---- Baseline check: G0 bias vs G2-correct bias in the same cells -----------
g0_bias <- res |>
  filter(generator == "g0", status %in% c("pass", "fail")) |>
  group_by(n_participants, n_trials, dprime_target) |>
  summarise(g0_bias = mean(log_M_mean - truth), g0_mcse = mcse(log_M_mean - truth), .groups = "drop")
baseline_cmp <- cells_primary |>
  select(n_participants, n_trials, dprime_target, base_mean, base_mcse) |>
  left_join(g0_bias, by = c("n_participants", "n_trials", "dprime_target")) |>
  mutate(diff = base_mean - g0_bias, se = sqrt(base_mcse^2 + g0_mcse^2))
readr::write_csv(baseline_cmp, file.path(out, "g2_baseline_vs_g0.csv"))

cat("\n=== Pooled d' contrast (low - high) ===\n"); print(pooled)
cat("\n=== Persistence lm ===\n"); print(persist)
cat("\nDone. Outputs in data/processed/v3/\n")
```

### 2.3 執行與預期

```bash
Rscript code/03_recovery_analysis/relative_bias.R
```

用上次在對話中快速算的數字做健全性檢查（該計算是跨 d′ 配對，此腳本改成獨立樣本，數值會很接近但 SE 略不同）：

- `delta_mean` 在 d′ = 0.75 的六格約 +0.19 到 +0.25，d′ = 1.5 約 +0.11 到 +0.15。
- `pooled$diff_low_minus_high` 約 +0.10。
- 若差很多 → 先檢查 `pivot_wider` 是否把兩個 variant 配對錯（`stopifnot` 應該會先擋下）。

### 2.4 理解檢查（寫進 analysis_log）

1. 為什麼跨 d′ 的差異要用獨立樣本 SE，而不是配對？
2. `persist` 的 `log2(n_trials)` 斜率若為 −0.01（CI 含 0），代表什麼？若為 −0.05（CI 不含 0）呢？
3. 如果 `baseline_cmp$diff` 在所有格都接近 0，對「G0 負偏差」的解讀有什麼幫助？

### 2.5 Commit

```bash
git add code/03_recovery_analysis/relative_bias.R data/processed/v3/g2_*.csv
git commit -m "v3 step 1: relative misspecification bias, d' contrast, persistence, baseline vs G0"
```

---

## 3. 步驟 2：LOO 穩健化（1–2 天，含背景運算）

### 3.1 為什麼與限制

- 181/240 個正確模型擬合至少有一個 Pareto k > 0.7。PSIS-LOO 對這些受試者的估計不可靠。
- **只有 rep 1–2 保留完整 `brmsfit`**（48 個擬合 = 24 對），所以精確修補只能在這 24 對上做。其他 216 對只能報告 k 值統計，並說明「在 24 對子集上，修補後結論是否改變」。
- 這裡的 LOO 單位是**一位受試者**（`loo_comparison.R` 已驗證）。留出一位受試者 = 預測一個新受試者，需要對其隨機效應積分，因此必須允許新層級（第 1.3 節檢查 (b)）。

### 3.2 `code/04_ppc_and_comparison/v3_reloo_stored_fits.R`

`reloo` 只會對 k > 0.7 的受試者重新擬合模型（排除該受試者），得到精確的 leave-one-participant-out 值，其餘受試者沿用 PSIS 值。平均每個擬合約 3 位受試者需要重擬合。

```r
# v3 step 2a: exact refits (reloo) for participants with Pareto k > 0.7 on
# the 48 stored G2 full fits. Resumable and shardable:
#   Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R <shard> <n_shards>
# e.g. run "1 3", "2 3", "3 3" in three terminals (each uses 4 cores).

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
# gumbel_min fits: R-side lcdf/lccdf must exist for log_lik() and epred.
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))

args     <- commandArgs(trailingOnly = TRUE)
shard    <- if (length(args) >= 1) as.integer(args[1]) else 1L
n_shards <- if (length(args) >= 2) as.integer(args[2]) else 1L
cfg3     <- yaml::read_yaml(here::here("config", "v3.yml"))
k_thr    <- cfg3$loo_robust$k_threshold

out_dir <- here::here("data", "interim", "v3_reloo")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- sort(list.files(here::here("data", "interim"),
                         pattern = "^g2_.*_rep-0[12]_.*[.]qs2$", full.names = TRUE))
stopifnot(length(files) == 48)
files <- files[(seq_along(files) - 1L) %% n_shards == (shard - 1L)]

for (f in files) {
  out_path <- file.path(out_dir, basename(f))
  if (file.exists(out_path)) { cat("skip", basename(f), "\n"); next }

  r <- qs2::qs_read(f)
  stopifnot(inherits(r$fit, "brmsfit"), !is.null(r$loo))
  k     <- r$loo$diagnostics$pareto_k
  n_bad <- sum(k > k_thr)
  t0    <- Sys.time()

  loo_exact <- if (n_bad == 0) {
    r$loo
  } else {
    tryCatch(
      # Main form (brms >= 2.x with loo(reloo = TRUE)); check args() output from section 1.3.
      brms::loo(r$fit, reloo = TRUE, k_threshold = k_thr,
                reloo_args = list(check = FALSE, cores = 4, refresh = 0)),
      error = function(e) {
        message("loo(reloo=TRUE) failed (", conditionMessage(e), "); trying reloo()")
        tryCatch(
          brms::reloo(r$loo, fit = r$fit, k_threshold = k_thr, check = FALSE,
                      cores = 4, refresh = 0),
          error = function(e2) e2)
      })
  }

  rec <- list(grid_id = r$grid_id, cell_id = r$cell_id, rep_id = r$rep_id,
              fit_variant = r$fit_variant, n_participants = r$n_participants,
              n_trials = r$n_trials, dprime_target = r$dprime_target,
              status = r$status, n_bad_k = n_bad, loo_psis = r$loo,
              loo_exact = loo_exact,
              ok = !inherits(loo_exact, "error"),
              elapsed_secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
  qs2::qs_save(rec, out_path)
  cat(sprintf("%s  n_bad=%d  ok=%s  %.0fs\n", basename(f), n_bad, rec$ok, rec$elapsed_secs))
}
```

**先試一個檔案**（很重要，順便計時）：

```bash
Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R 1 48
```

檢查：
- 產生的 `rec$loo_exact` 的 `diagnostics$pareto_k`，被重擬合的受試者應顯示為 0 或 NA（視 brms 版本）。
- 若報錯 `new levels` 相關訊息 → 在 `reloo_args` 裡加 `allow_new_levels = TRUE, sample_new_levels = "uncertainty"`。
- 若報錯與 `gumbel_min_lcdf` 找不到有關 → 確認有 `source(simulate_g2_gumbel.R)`。

試跑成功後，開 3 個終端機平行跑（每個佔 4 核心，22 核心的機器留足餘裕）：

```bash
Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R 1 3
Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R 2 3
Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R 3 3
```

預估：約 150 次重擬合 × 2–3 分鐘 ÷ 3 ≈ 2–3 小時。

### 3.3 `code/04_ppc_and_comparison/v3_loo_robust_summary.R`

```r
# v3 step 2b: compare PSIS-LOO vs exact-refit LOO on the 24 stored pairs,
# and summarise Pareto k across all 480 fits.

suppressPackageStartupMessages(library(dplyr))
out <- here::here("data", "processed", "v3")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

recs <- purrr::map(list.files(here::here("data", "interim", "v3_reloo"),
                              pattern = "[.]qs2$", full.names = TRUE), qs2::qs_read)
stopifnot(length(recs) == 48, all(purrr::map_lgl(recs, "ok")))

cmp_one <- function(loo_c, loo_m) {
  cmp  <- loo::loo_compare(list(correct = loo_c, misspecified = loo_m))
  diff <- cmp["correct", "elpd_diff"] - cmp["misspecified", "elpd_diff"]  # > 0 favours correct
  se   <- max(cmp[, "se_diff"])
  c(diff = diff, se = se)
}

pairs <- split(recs, purrr::map_chr(recs, ~ paste(.x$cell_id, .x$rep_id)))
by_pair <- purrr::map_dfr(pairs, function(p) {
  v <- purrr::map_chr(p, "fit_variant")
  c_ <- p[[which(v == "correct")]]; m_ <- p[[which(v == "misspecified")]]
  psis  <- cmp_one(c_$loo_psis,  m_$loo_psis)
  exact <- cmp_one(c_$loo_exact, m_$loo_exact)
  tibble::tibble(cell_id = c_$cell_id, rep_id = c_$rep_id,
                 n_participants = c_$n_participants, n_trials = c_$n_trials,
                 dprime_target = c_$dprime_target,
                 n_bad_k_correct = c_$n_bad_k, n_bad_k_mis = m_$n_bad_k,
                 diff_psis = psis[["diff"]], se_psis = psis[["se"]],
                 diff_exact = exact[["diff"]], se_exact = exact[["se"]]) |>
    mutate(favors_psis = diff_psis > 0, favors_exact = diff_exact > 0,
           favors2se_psis = diff_psis > 2 * se_psis, favors2se_exact = diff_exact > 2 * se_exact,
           sign_agree = favors_psis == favors_exact,
           twose_agree = favors2se_psis == favors2se_exact)
})
readr::write_csv(by_pair, file.path(out, "g2_loo_psis_vs_exact_by_pair.csv"))

summary_tbl <- by_pair |>
  summarise(n_pairs = n(),
            prop_favor_psis = mean(favors_psis), prop_favor_exact = mean(favors_exact),
            prop_2se_psis = mean(favors2se_psis), prop_2se_exact = mean(favors2se_exact),
            sign_agreement = mean(sign_agree), twose_agreement = mean(twose_agree),
            median_abs_change = median(abs(diff_exact - diff_psis)))
readr::write_csv(summary_tbl, file.path(out, "g2_loo_psis_vs_exact_summary.csv"))
print(summary_tbl)

# Full-grid Pareto k table (all 480 fits) from the existing per-fit file,
# broken down by cell, for the supplement.
pk <- readr::read_csv(here::here("data", "processed", "g2_pareto_k_by_fit.csv"), show_col_types = FALSE)
pk_cell <- pk |>
  group_by(fit_variant, n_participants, n_trials, dprime_target) |>
  summarise(n_fits = n(), prop_fits_any_bad = mean(n_k_bad > 0),
            prop_obs_bad = sum(n_k_bad) / sum(n_obs), .groups = "drop")
readr::write_csv(pk_cell, file.path(out, "g2_pareto_k_by_cell.csv"))
```

### 3.4 可選：participant-level K-fold（`v3_kfold_stored_fits.R`）

只有在 3.3 發現 PSIS 與精確值**結論不一致**（`twose_agreement` < 0.9）時才做。重點：**同一對的兩個模型必須用相同的 fold 分配**。

```r
suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
out_dir <- here::here("data", "interim", "v3_kfold"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- sort(list.files(here::here("data", "interim"),
                         pattern = "^g2_.*_rep-01_.*[.]qs2$", full.names = TRUE))  # rep 1 only: 24 fits
for (f in files) {
  out_path <- file.path(out_dir, basename(f)); if (file.exists(out_path)) next
  r <- qs2::qs_read(f)
  # Fold ids depend ONLY on the dataset (cell_id, rep_id), so both variants share them.
  set.seed(cfg3$seed_base_v3 + r$cell_id * 100 + r$rep_id)
  folds <- loo::kfold_split_random(K = cfg3$loo_robust$kfold_K, N = nrow(r$fit$data))
  kf <- brms::kfold(r$fit, folds = folds, chains = 4, cores = 4, refresh = 0, save_fits = FALSE)
  qs2::qs_save(list(cell_id = r$cell_id, rep_id = r$rep_id, fit_variant = r$fit_variant,
                    folds = folds, kfold = kf), out_path)
}
```

注意：`cell_id` 在兩個 variant 之間是否相同？`loo_comparison.R` 是用 `(cell_id, rep_id)` 配對，代表相同。若不確定，改用 `sim_seed` 當種子來源。成本：24 × 5 次重擬合 ≈ 4–6 小時。

### 3.5 決定點

- `twose_agreement ≥ 0.9` 且 `prop_favor_exact` 與 PSIS 相差 < 10 個百分點 → 報告「修補後定性結論不變」，進入步驟 3。
- 否則 → 做 3.4 K-fold，並在報告中以 K-fold 為主要 LOO 結果。**不要停下**，這本身就是結果。

```bash
git add code/04_ppc_and_comparison/v3_* data/processed/v3/g2_loo_* data/processed/v3/g2_pareto_k_by_cell.csv
git commit -m "v3 step 2: exact-refit LOO on stored G2 fits; Pareto k by cell"
```

---

## 4. 步驟 3：難度混合模擬 G3（1–2 天）

### 4.1 為什麼

真實資料常把不同難度的試次合併。多個不同 d′ 的高斯分佈混合後，形狀本身就不是高斯。若這會讓 LOO 偏好 Gumbel-min，實證結果就可能是假象。G3 直接測這件事，同時檢驗「把難度放進模型」能否消除假象。

設計：`control`（兩半 d′ 都是 1.25）vs `mixture`（0.5 和 2.0，平均相同）× 20 次重複 × 4 種擬合：

| 擬合 | 分佈 | 資料聚合 | d′/c 共變項 |
|---|---|---|---|
| `normal_pooled` | normal | 受試者 | 無 |
| `gumbel_pooled` | gumbel_min | 受試者 | 無 |
| `normal_difficulty` | normal | 受試者 × 難度 | difficulty |
| `gumbel_difficulty` | gumbel_min | 受試者 × 難度 | difficulty |

⚠️ **LOO 只能在相同資料上比較**：pooled 兩者互比、difficulty 兩者互比。pooled 和 difficulty 的聚合計數不同，似然函數不在同一資料上，不能互比 ELPD。

### 4.2 修改 `code/02_fit/fit_hmetad.R`（向下相容）

**步驟 A：修改之前**先存下 v1.2.1 的公式當作測試基準：

```r
source(here::here("code", "02_fit", "fit_hmetad.R"))
dir.create(here::here("tests", "fixtures"), showWarnings = FALSE)
saveRDS(list(
  k4       = capture.output(print(.build_metad_formula(4))),
  k4_nohier = capture.output(print(.build_metad_formula(4, hierarchical_dprime_c = FALSE))),
  k4_thr   = capture.output(print(.build_metad_formula(4, hierarchical_thresholds = TRUE))),
  pri_k4   = capture.output(print(.build_metad_priors(4, "normal(0, 1)", "normal(0, 1)")))
), here::here("tests", "fixtures", "formula_k4_v121.rds"))
```

```bash
git add tests/fixtures/formula_k4_v121.rds
git commit -m "tests: snapshot v1.2.1 formula/prior output before extending fit wrapper"
```

**步驟 B：替換 `.build_metad_formula` 和 `.build_metad_priors`**：

```r
.build_metad_formula <- function(K, group = "participant",
                                  hierarchical_dprime_c = TRUE,
                                  hierarchical_thresholds = FALSE,
                                  dprime_c_covariates = NULL,
                                  log_M_covariates = NULL) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_rhs <- paste(gap_params, collapse = " + ")
  re <- paste0("(1|", group, ")")
  fixed <- function(covs) paste(c("1", covs), collapse = " + ")

  mu_form <- stats::as.formula(paste0("N ~ ", fixed(log_M_covariates), " + ", re))
  dprime_c_rhs <- if (hierarchical_dprime_c) paste0(fixed(dprime_c_covariates), " + ", re)
                  else fixed(dprime_c_covariates)
  dprime_c_form <- stats::as.formula(paste0("dprime + c ~ ", dprime_c_rhs))
  thresholds_rhs <- if (hierarchical_thresholds) paste0("1 + ", re) else "1"
  thresholds_form <- stats::as.formula(paste0(gap_rhs, " ~ ", thresholds_rhs))

  brms::bf(mu_form, dprime_c_form, thresholds_form)
}

.build_metad_priors <- function(K, log_M_prior, metac2_prior,
                                log_M_b_prior = NULL) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_priors <- Reduce(`c`, lapply(
    gap_params,
    function(p) brms::set_prior(metac2_prior, class = "Intercept", dpar = p)
  ))
  pri <- gap_priors + brms::set_prior(log_M_prior, class = "Intercept")
  # Only when log_M has covariates: prior on its condition coefficients
  # (class "b" with no dpar = the mu / log_M part of the model).
  if (!is.null(log_M_b_prior)) pri <- pri + brms::set_prior(log_M_b_prior, class = "b")
  pri
}
```

**步驟 C：`fit_one_hmetad()` 新增四個參數**（放在 `extra_stanvars` 之前），並改兩處：

```r
fit_one_hmetad <- function(data, K = 4, group = "participant",
                            distribution = "normal", metac_absolute = TRUE,
                            hierarchical_dprime_c = TRUE, hierarchical_thresholds = FALSE,
                            log_M_prior = "normal(0, 1)", metac2_prior = "normal(0, 1)",
                            # --- v3 additions (defaults reproduce v1.2.1 exactly) ---
                            agg_by = NULL,               # extra grouping columns, e.g. "difficulty"
                            dprime_c_covariates = NULL,  # e.g. "difficulty"
                            log_M_covariates = NULL,     # e.g. "condition" (empirical only)
                            log_M_b_prior = if (is.null(log_M_covariates)) NULL else "normal(0, 1)",
                            # ---------------------------------------------------------
                            chains = 4, cores = chains, warmup = 1000, iter_sampling = 1000,
                            adapt_delta = 0.95, max_treedepth = 12,
                            rhat_max = 1.01, bulk_ess_min = 400, tail_ess_min = 400,
                            seed, extra_stanvars = NULL, metadata = list(), ...) {
  .validate_metad_input(data, k = K, group = group)
  if (!is.null(agg_by)) {
    miss <- setdiff(agg_by, names(data))
    if (length(miss)) stop("fit_one_hmetad: agg_by column(s) not in data: ", paste(miss, collapse = ", "))
  }
  if (!all(c(dprime_c_covariates, log_M_covariates) %in% agg_by)) {
    stop("fit_one_hmetad: every covariate must also be listed in agg_by")
  }

  formula <- .build_metad_formula(
    K, group = group,
    hierarchical_dprime_c = hierarchical_dprime_c,
    hierarchical_thresholds = hierarchical_thresholds,
    dprime_c_covariates = dprime_c_covariates,
    log_M_covariates = log_M_covariates
  )
  priors <- .build_metad_priors(K, log_M_prior = log_M_prior, metac2_prior = metac2_prior,
                                log_M_b_prior = log_M_b_prior)
  agg <- hmetad::aggregate_metad(data, !!!rlang::syms(c(group, agg_by)), K = K)
  # ... the rest of the function is unchanged ...
```

在 `base_record` 的 list 裡加上 `agg_by = agg_by, dprime_c_covariates = dprime_c_covariates, log_M_covariates = log_M_covariates`，方便之後追溯。

**備案**（若第 1.3 節檢查 (c) 顯示 `aggregate_metad` 不能多欄分組）：在呼叫前自己建一個合併欄位，

```r
data$pgroup <- interaction(data[[group]], data[[agg_by]], drop = TRUE, sep = "_")
```

然後用 `pgroup` 聚合，再把 `participant` 和 `difficulty` 從 `pgroup` 拆回 `agg` 的欄位。這比較麻煩，優先確認 (c)。

**步驟 D：`tests/test_formula_backcompat.R`**

```r
source(here::here("code", "02_fit", "fit_hmetad.R"))
ref <- readRDS(here::here("tests", "fixtures", "formula_k4_v121.rds"))

test_that("default formula and priors are unchanged from v1.2.1", {
  expect_identical(capture.output(print(.build_metad_formula(4))), ref$k4)
  expect_identical(capture.output(print(.build_metad_formula(4, hierarchical_dprime_c = FALSE))), ref$k4_nohier)
  expect_identical(capture.output(print(.build_metad_formula(4, hierarchical_thresholds = TRUE))), ref$k4_thr)
  expect_identical(capture.output(print(.build_metad_priors(4, "normal(0, 1)", "normal(0, 1)"))), ref$pri_k4)
})

test_that("covariates enter the intended parts of the formula", {
  f <- capture.output(print(.build_metad_formula(4, dprime_c_covariates = "difficulty")))
  expect_true(any(grepl("dprime ~ 1 \\+ difficulty", f)))
  expect_false(any(grepl("N ~ 1 \\+ difficulty", f)))
  g <- capture.output(print(.build_metad_formula(4, log_M_covariates = "condition")))
  expect_true(any(grepl("N ~ 1 \\+ condition", g)))
})
```

（`print(bf)` 的精確格式依 brms 版本而定；若第二個測試的正則式不符，先 `print()` 看實際輸出再調整。第一個測試不需要調整。）

```bash
Rscript -e 'testthat::test_dir("tests")'
git add code/02_fit/fit_hmetad.R tests/test_formula_backcompat.R
git commit -m "fit wrapper: optional agg_by/covariates (defaults reproduce v1.2.1; regression test)"
```

**步驟 E（強烈建議）：重現性抽查**。用修改後的程式碼重跑 grid 721（`run_one_cell.R` 會跳過已存在的輸出，所以先把原檔案暫時搬走），確認 draws 與原檔完全相同，然後把原檔搬回來。README 記載 v1.2.1 曾對 cell 721 做過相同檢查，照同一方式。

### 4.3 `code/01_simulate/simulate_g3_mixture.R`

```r
# G3: equal-variance Gaussian meta-d' data with a within-participant
# mixture of difficulty levels (two halves, each simulated by simulate_g0()).
# Known log_M is shared by both levels. Thresholds are drawn independently
# per half (sd_z_c2 = 0.1 in simulate_g0), a small, documented deviation from
# a participant having identical thresholds across difficulty levels.

source(here::here("code", "01_simulate", "simulate_g0.R"))

simulate_g3_mixture <- function(n_participants, n_trials_per_level, dprimes,
                                log_M, k = 4, seed) {
  stopifnot(length(dprimes) >= 2)
  out <- purrr::imap_dfr(dprimes, function(dp, i) {
    d <- simulate_g0(n_participants = n_participants, n_trials = n_trials_per_level,
                     dprime_target = dp, log_M = log_M, k = k,
                     seed = seed + (i - 1L) * 100000L)
    d$difficulty   <- paste0("L", i)
    d$dprime_level <- dp
    d
  })
  out$difficulty <- factor(out$difficulty)
  out
}
```

加一個測試到 `tests/test_simulate_g3.R`：每位受試者每個難度有 `n_trials_per_level` 筆（或 `sim_metad_participant` 的等價定義，先 `table(d$participant, d$difficulty)` 看）；`mixture` 的 L1 準確率 < L2 準確率。

### 4.4 `code/00_setup/03_create_grid_g3.R`

```r
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))$g3
seed0 <- yaml::read_yaml(here::here("config", "v3.yml"))$seed_base_v3

grid <- tidyr::expand_grid(
  condition   = names(cfg3$conditions),
  rep_id      = seq_len(cfg3$replications),
  fit_variant = cfg3$fit_variants
) |>
  dplyr::mutate(
    cond_idx = match(condition, names(cfg3$conditions)),
    sim_seed = seed0 + cond_idx * 1000L + rep_id,         # identical across fit variants
    fit_seed = sim_seed + 1000000L,
    g3_id    = dplyr::row_number()
  ) |>
  dplyr::select(g3_id, condition, rep_id, fit_variant, sim_seed, fit_seed)

stopifnot(nrow(grid) == 2 * cfg3$replications * 4)
readr::write_csv(grid, here::here("config", "grid_g3.csv"))
```

### 4.5 `code/02_fit/run_one_cell_g3.R`

```r
# Usage: Rscript code/02_fit/run_one_cell_g3.R <g3_id>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript run_one_cell_g3.R <g3_id>")
g3_id <- as.integer(args[1])

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))   # gumbel_min_* + stanvars
source(here::here("code", "01_simulate", "simulate_g3_mixture.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
grid <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)
row  <- as.list(grid[grid$g3_id == g3_id, ])
stopifnot(length(row$g3_id) == 1)

out_dir  <- here::here("data", "interim", "v3_g3")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, sprintf("g3_%s_rep-%02d_%s_id-%03d.qs2",
                                       row$condition, row$rep_id, row$fit_variant, row$g3_id))
if (file.exists(out_path)) { cat("exists:", out_path, "\n"); quit(save = "no") }

spec <- switch(row$fit_variant,
  normal_pooled     = list(dist = "normal",     agg_by = NULL,         cov = NULL),
  gumbel_pooled     = list(dist = "gumbel_min", agg_by = NULL,         cov = NULL),
  normal_difficulty = list(dist = "normal",     agg_by = "difficulty", cov = "difficulty"),
  gumbel_difficulty = list(dist = "gumbel_min", agg_by = "difficulty", cov = "difficulty"),
  stop("unknown fit_variant"))

result <- tryCatch({
  data <- simulate_g3_mixture(
    n_participants = cfg3$g3$n_participants,
    n_trials_per_level = cfg3$g3$n_trials_per_level,
    dprimes = unlist(cfg3$g3$conditions[[row$condition]]),
    log_M = cfg$truth$log_M, k = cfg$confidence$k, seed = row$sim_seed)

  fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = spec$dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    agg_by = spec$agg_by, dprime_c_covariates = spec$cov,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min,
    seed = seed,
    extra_stanvars = if (spec$dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row)

  a <- fit_once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, row$fit_seed)
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- fit_once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth,
                  row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  if (!is.null(a$fit)) {
    dr <- posterior::as_draws_df(a$fit)
    a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
    a$loo <- tryCatch(brms::loo(a$fit), error = function(e) NULL)
  }
  if (row$rep_id > cfg$execution$keep_full_fit_max_rep_id) a$fit <- NULL
  a
}, error = function(e) list(status = "error", error_message = conditionMessage(e), fit = NULL))

result$g3_id <- row$g3_id
qs2::qs_save(result, out_path)
cat("Saved", out_path, "status:", result$status, "\n")
```

**先試兩個**：一個 `normal_difficulty`、一個 `gumbel_pooled`，確認都能跑、`b_Intercept` 存在、`loo` 不是 NULL。

```bash
Rscript code/00_setup/03_create_grid_g3.R
Rscript code/02_fit/run_one_cell_g3.R 3   # check which id is which in config/grid_g3.csv first
```

**正式跑**（Windows 沒有 `make` 時，用一個小的 PowerShell 迴圈分成 4 份在 4 個終端機跑）。建一個 `code/02_fit/run_g3_shard.R`：

```r
args <- commandArgs(trailingOnly = TRUE)
shard <- as.integer(args[1]); n_shards <- as.integer(args[2])
ids <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)$g3_id
for (id in ids[(ids - 1L) %% n_shards == (shard - 1L)]) {
  system2("Rscript", c(here::here("code", "02_fit", "run_one_cell_g3.R"), id))
}
```

```bash
Rscript code/02_fit/run_g3_shard.R 1 4    # terminal 1
Rscript code/02_fit/run_g3_shard.R 2 4    # terminal 2  ... up to 4
```

預估：160 次 × ~2.5 分鐘 ÷ 4 ≈ 2 小時（受散熱影響可能 3 小時）。可中斷後重跑，已完成的會跳過。

### 4.6 `code/04_ppc_and_comparison/v3_g3_summary.R`

```r
suppressPackageStartupMessages(library(dplyr))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
out  <- here::here("data", "processed", "v3")

recs <- purrr::map(list.files(here::here("data", "interim", "v3_g3"), "[.]qs2$", full.names = TRUE),
                   qs2::qs_read)
grid <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)

by_fit <- purrr::map_dfr(recs, function(r) {
  x <- if (!is.null(r$draws_b_sd)) r$draws_b_sd$b_Intercept else NA_real_
  tibble::tibble(g3_id = r$g3_id, status = r$status,
                 log_M_mean = mean(x), log_M_q025 = quantile(x, .025, names = FALSE, na.rm = TRUE),
                 log_M_q975 = quantile(x, .975, names = FALSE, na.rm = TRUE),
                 has_loo = !is.null(r$loo))
}) |> left_join(grid, by = "g3_id") |>
  mutate(bias = log_M_mean - cfg$truth$log_M,
         covered = log_M_q025 <= cfg$truth$log_M & cfg$truth$log_M <= log_M_q975)
readr::write_csv(by_fit, file.path(out, "g3_by_fit.csv"))

loo_of <- setNames(purrr::map(recs, "loo"), purrr::map_int(recs, "g3_id"))

# elpd(normal) - elpd(gumbel); > 0 favours Gaussian (v3 sign convention)
cmp_family <- function(id_normal, id_gumbel) {
  a <- loo_of[[as.character(id_normal)]]; b <- loo_of[[as.character(id_gumbel)]]
  if (is.null(a) || is.null(b)) return(c(diff = NA, se = NA))
  cmp <- loo::loo_compare(list(normal = a, gumbel = b))
  c(diff = cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"], se = max(cmp[, "se_diff"]))
}

loo_tbl <- grid |>
  mutate(agg = if_else(grepl("pooled", fit_variant), "pooled", "difficulty"),
         fam = sub("_.*", "", fit_variant)) |>
  select(condition, rep_id, agg, fam, g3_id) |>
  tidyr::pivot_wider(names_from = fam, values_from = g3_id, names_prefix = "id_") |>
  rowwise() |>
  mutate(res = list(cmp_family(id_normal, id_gumbel))) |>
  ungroup() |>
  mutate(elpd_diff = purrr::map_dbl(res, "diff"), se = purrr::map_dbl(res, "se"),
         favors_gumbel_2se = elpd_diff < -2 * se) |>
  select(-res)
readr::write_csv(loo_tbl, file.path(out, "g3_loo_by_rep.csv"))

rates <- loo_tbl |>
  group_by(condition, agg) |>
  summarise(n = n(), prop_favors_gumbel_2se = mean(favors_gumbel_2se, na.rm = TRUE),
            mean_elpd_diff = mean(elpd_diff, na.rm = TRUE), .groups = "drop")
readr::write_csv(rates, file.path(out, "g3_loo_rates.csv"))
print(rates)

# Pre-specified verdict (config/v3.yml g3$artefact_rule), pooled comparisons only
r_mix <- rates$prop_favors_gumbel_2se[rates$condition == "mixture" & rates$agg == "pooled"]
r_con <- rates$prop_favors_gumbel_2se[rates$condition == "control" & rates$agg == "pooled"]
verdict <- if (r_mix >= cfg3$g3$artefact_rule$mixture_min_prop &&
               r_con <= cfg3$g3$artefact_rule$control_max_prop) "pooling artefact present" else
           "no pooling artefact by the pre-specified rule"
cat("\nG3 verdict:", verdict, "\n")
writeLines(verdict, file.path(out, "g3_verdict.txt"))

bias_tbl <- by_fit |>
  group_by(condition, fit_variant) |>
  summarise(n = n(), bias = mean(bias), mcse = sd(log_M_mean) / sqrt(n()),
            coverage = mean(covered), n_fail = sum(status != "pass"), .groups = "drop")
readr::write_csv(bias_tbl, file.path(out, "g3_bias.csv"))
print(bias_tbl)
```

### 4.7 如何解讀 G3（決定點）

- **有假象**（合併時常偏好 Gumbel，控制組很少）→ 實證分析**必須**把難度放進模型；難度未記錄的資料集一律排除。這本身也是論文的一個發現。
- **沒有假象** → 實證分析仍然照原計劃放入難度（有記錄就放），但難度未記錄的資料集可以放進敏感度分析，而不是直接排除。
- 無論哪種，`difficulty` 版本的 Δlog(M)（normal − gumbel）應該接近 0，因為資料本來就是高斯。若不接近 0，要先查清楚才進入步驟 4。

```bash
git add code/00_setup/03_create_grid_g3.R config/grid_g3.csv code/01_simulate/simulate_g3_mixture.R \
        code/02_fit/run_one_cell_g3.R code/02_fit/run_g3_shard.R \
        code/04_ppc_and_comparison/v3_g3_summary.R data/processed/v3/g3_* tests/test_simulate_g3.R
git commit -m "v3 step 3: G3 difficulty-mixture simulation and pre-specified artefact verdict"
```

---

## 5. 步驟 4：Confidence Database 實證分析（1–2 週）

### 5.0 階段總覽

```text
5.1 下載與紀錄 → 5.2 自動篩選 → 5.3 手動編碼難度設計 → 5.4 選定資料集（tag 預先規定）
→ 5.5 整理成 hmetad 格式 → 5.6 PPC 函式泛化 → 5.7 擬合（先試跑 2 個）
→ 5.8 LOO 修補 → 5.9 PPC → 5.10 彙整與分類
```

**5.4 的 tag 打下去之前，不可以擬合任何真實資料。**

### 5.1 下載與紀錄

1. 到 Confidence Database 的 OSF 頁面（Rahnev et al., 2020, *Nature Human Behaviour* 的資料連結）下載：
   - 所有 `data_*.csv`
   - 資料庫的說明試算表（資料集層級的 metadata，例如類別、信心量表、論文出處）
   - 所有資料集的 readme（若有）
2. 放到 `data/raw/confidence_db/`（`.gitignore` 已排除 `data/raw/*`）。
3. 建立 `docs/data_access_confidence_db.md`，記錄：下載日期、OSF 網址、資料庫版本、**授權條款（到 OSF 頁面確認，照抄）**、引用方式（資料庫論文 + 每個使用資料集的原始論文）。
4. 產生雜湊值清單，讓別人能確認拿到相同檔案：

```r
files <- list.files(here::here("data", "raw", "confidence_db"), full.names = TRUE)
manifest <- tibble::tibble(file = basename(files), md5 = unname(tools::md5sum(files)),
                           bytes = file.size(files))
dir.create(here::here("data", "processed", "v3", "empirical"), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(manifest, here::here("data", "processed", "v3", "empirical", "raw_manifest.csv"))
```

5. **先手動打開 2–3 個 CSV**，確認欄位名稱。以下程式假設標準欄位為 `Subj_idx`、`Stimulus`、`Response`、`Confidence`，部分資料集有 `Condition`、`Accuracy`。若實際名稱不同，改 `eligibility.R` 最上方的 `REQUIRED_COLS`，並記錄在 analysis_log。

### 5.2 `code/06_empirical/eligibility.R`（純函式，全部可測）

```r
# Pure functions for the empirical stage: no file I/O, all unit-tested.

REQUIRED_COLS <- c("Subj_idx", "Stimulus", "Response", "Confidence")

# ---- dataset-level screening from a raw data frame ------------------------
screen_raw <- function(d, min_trials) {
  if (!all(REQUIRED_COLS %in% names(d))) {
    return(tibble::tibble(has_required = FALSE))
  }
  d <- d[stats::complete.cases(d[, REQUIRED_COLS]), ]
  per_subj  <- table(d$Subj_idx)
  conf_vals <- sort(unique(d$Confidence))
  stim_vals <- unique(d$Stimulus)
  tibble::tibble(
    has_required     = TRUE,
    n_rows           = nrow(d),
    n_subj           = length(per_subj),
    n_subj_min_trials = sum(per_subj >= min_trials),
    median_trials    = stats::median(as.numeric(per_subj)),
    n_stim           = length(stim_vals),
    n_resp           = length(unique(d$Response)),
    resp_in_stim     = all(unique(d$Response) %in% stim_vals),
    conf_numeric     = is.numeric(d$Confidence),
    conf_integer     = is.numeric(d$Confidence) && all(conf_vals == round(conf_vals)),
    n_conf_levels    = length(conf_vals),
    has_condition    = "Condition" %in% names(d),
    n_condition      = if ("Condition" %in% names(d)) length(unique(stats::na.omit(d$Condition))) else NA_integer_
  )
}

# ---- automatic eligibility rules (config/v3.yml$empirical) -----------------
apply_auto_rules <- function(s, e) {
  s |>
    dplyr::mutate(
      rule_required   = has_required,
      rule_binary     = n_stim == 2 & n_resp == 2 & resp_in_stim,
      rule_discrete   = conf_integer & n_conf_levels >= e$conf_levels_range[[1]] &
                        n_conf_levels <= e$conf_levels_range[[2]],
      rule_sample     = n_subj_min_trials >= e$min_participants,
      auto_eligible   = rule_required & rule_binary & rule_discrete & rule_sample
    )
}

# ---- merge sparse adjacent confidence levels -------------------------------
# Deterministic: repeatedly merge the sparsest level into its sparser adjacent
# neighbour until every level holds >= min_prop of trials and K <= k_max.
# Assumes larger raw values = higher confidence (checked separately).
merge_sparse_levels <- function(x, min_prop = 0.05, k_max = 6) {
  old <- sort(unique(x))
  grp <- seq_along(old)
  counts <- tabulate(match(x, old), length(old))
  repeat {
    gp <- as.numeric(tapply(counts, grp, sum)) / length(x)
    ng <- length(gp)
    if (ng <= 2 || (all(gp >= min_prop) && ng <= k_max)) break
    j    <- which.min(gp)
    nbrs <- c(j - 1L, j + 1L); nbrs <- nbrs[nbrs >= 1 & nbrs <= ng]
    m    <- nbrs[which.min(gp[nbrs])]
    grp[grp == max(j, m)] <- min(j, m)
    grp  <- as.integer(factor(grp))       # renumber consecutively, order preserved
  }
  tibble::tibble(old = old, new = grp)
}

# ---- harmonise one dataset to hmetad input format --------------------------
# difficulty_col: name of the column that records difficulty/condition, or NULL.
harmonise_dataset <- function(d, e, difficulty_col = NULL) {
  keep_cols <- c(REQUIRED_COLS, difficulty_col, intersect("Accuracy", names(d)))
  d <- d[stats::complete.cases(d[, c(REQUIRED_COLS, difficulty_col)]), keep_cols]
  stim_levels <- sort(unique(d$Stimulus))
  stopifnot(length(stim_levels) == 2, all(unique(d$Response) %in% stim_levels))

  out <- tibble::tibble(
    subj_raw  = d$Subj_idx,
    stimulus  = as.integer(match(d$Stimulus, stim_levels) - 1L),
    response  = as.integer(match(d$Response, stim_levels) - 1L),
    conf_raw  = d$Confidence,
    condition_raw = if (is.null(difficulty_col)) "all" else as.character(d[[difficulty_col]])
  )
  out$correct <- as.integer(out$stimulus == out$response)

  # Cross-check against the dataset's own Accuracy column if present.
  acc_agreement <- if ("Accuracy" %in% names(d)) mean(out$correct == d$Accuracy) else NA_real_

  # Confidence direction check: mean accuracy should rise with confidence.
  conf_acc_rho <- suppressWarnings(stats::cor(out$conf_raw, out$correct, method = "spearman"))

  # Participant exclusions (pre-specified).
  ps <- out |> dplyr::group_by(subj_raw) |>
    dplyr::summarise(n = dplyr::n(), acc = mean(correct), .groups = "drop")
  keep <- ps$subj_raw[ps$n >= e$min_trials_per_participant &
                      ps$acc >= e$accuracy_range[[1]] & ps$acc <= e$accuracy_range[[2]]]
  out <- out[out$subj_raw %in% keep, ]

  # Confidence levels: merge sparse ones (after exclusions).
  cmap <- merge_sparse_levels(out$conf_raw, e$merge_min_prop, e$k_max)
  out$confidence <- cmap$new[match(out$conf_raw, cmap$old)]

  # Syntactic, stable condition labels L1, L2, ... (brms coefficient names).
  cond_levels <- sort(unique(out$condition_raw))
  out$condition <- factor(paste0("L", match(out$condition_raw, cond_levels)))
  out$participant <- as.integer(factor(out$subj_raw))

  list(
    data = out[, c("participant", "stimulus", "response", "confidence", "condition",
                   "subj_raw", "conf_raw", "condition_raw", "correct")],
    K = max(cmap$new),
    conf_map = cmap,
    condition_map = tibble::tibble(label = paste0("L", seq_along(cond_levels)), raw = cond_levels),
    n_participants_raw = nrow(ps),
    n_participants_kept = length(keep),
    acc_agreement = acc_agreement,
    conf_acc_rho = conf_acc_rho
  )
}
```

### 5.3 `tests/test_eligibility.R`

```r
source(here::here("code", "06_empirical", "eligibility.R"))

test_that("merge_sparse_levels leaves a balanced scale untouched", {
  x <- rep(1:4, each = 25)
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_equal(m$new, 1:4)
})

test_that("a sparse top level merges into its neighbour", {
  x <- c(rep(1, 40), rep(2, 30), rep(3, 28), rep(4, 2))   # level 4 = 2%
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_equal(m$new, c(1L, 2L, 3L, 3L))
})

test_that("k_max is respected and mapping is monotone", {
  x <- rep(1:10, each = 10)
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_lte(max(m$new), 6)
  expect_true(all(diff(m$new) >= 0))
  expect_equal(nrow(m), 10)
})

test_that("harmonise codes stimulus/response on the same mapping", {
  e <- list(min_trials_per_participant = 1, accuracy_range = c(0, 1),
            merge_min_prop = 0, k_max = 6)
  d <- data.frame(Subj_idx = 1, Stimulus = c("L", "R", "R"), Response = c("L", "L", "R"),
                  Confidence = c(1, 2, 3))
  h <- harmonise_dataset(d, e)
  expect_equal(h$data$stimulus, c(0L, 1L, 1L))
  expect_equal(h$data$response, c(0L, 0L, 1L))
  expect_equal(h$data$correct,  c(1L, 0L, 1L))
})

test_that("auto rules reject continuous confidence and non-binary tasks", {
  e <- list(conf_levels_range = list(3, 11), min_participants = 1)
  s <- tibble::tibble(has_required = TRUE, n_stim = c(2, 3), n_resp = c(2, 3),
                      resp_in_stim = TRUE, conf_integer = c(FALSE, TRUE),
                      n_conf_levels = c(50, 4), n_subj_min_trials = 10)
  r <- apply_auto_rules(s, e)
  expect_false(any(r$auto_eligible))
})
```

```bash
Rscript -e 'testthat::test_dir("tests")'
```

### 5.4 自動篩選 → 手動編碼 → 選定（然後 tag）

**`code/06_empirical/01_screen_datasets.R`**

```r
suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "eligibility.R"))
e <- yaml::read_yaml(here::here("config", "v3.yml"))$empirical
raw_dir <- here::here("data", "raw", "confidence_db")
out_dir <- here::here("data", "processed", "v3", "empirical")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- sort(list.files(raw_dir, pattern = "^data_.*[.]csv$", full.names = TRUE))
screen <- purrr::map_dfr(files, function(f) {
  d <- readr::read_csv(f, show_col_types = FALSE, guess_max = 100000)
  dplyr::bind_cols(tibble::tibble(dataset = sub("^data_(.*)[.]csv$", "\\1", basename(f))),
                   screen_raw(d, e$min_trials_per_participant))
})
screen <- apply_auto_rules(screen, e)

# Join dataset-level metadata (category etc.). CHECK the sheet and column
# names in the information spreadsheet first and edit these two lines.
info <- readxl::read_excel(file.path(raw_dir, "Database_Information.xlsx"))
info <- info |> dplyr::transmute(dataset = .data[["Name_in_database"]],
                                 category = tolower(.data[["Category"]]))
screen <- screen |> left_join(info, by = "dataset")

readr::write_csv(screen, file.path(out_dir, "screening_table.csv"))
cat("Auto-eligible:", sum(screen$auto_eligible, na.rm = TRUE), "of", nrow(screen), "\n")
print(count(filter(screen, auto_eligible), category))
```

⚠️ 說明試算表的檔名、工作表和欄位名（上面的 `Database_Information.xlsx`、`Name_in_database`、`Category`）**是推測的**，請先用 `readxl::excel_sheets()` 和 `names()` 看實際名稱再改。

**手動編碼**：對每個 `auto_eligible` 且 `category == "perception"`（加上你想做次要分析的 memory）的資料集，讀它的 readme 或原始論文的 Methods，填 `config/empirical_manual_coding.csv`：

```csv
dataset,difficulty_design,difficulty_column,conf_higher_is_more,notes,coded_on
Example_2019,recorded_levels,Condition,TRUE,"3 contrast levels in Condition",2026-10-xx
```

`difficulty_design` 只能是以下之一：

| 值 | 意思 | 用途 |
|---|---|---|
| `constant` | 全程單一難度 | 主要分析 |
| `recorded_levels` | 多個難度，且有欄位記錄（≤ 4 級） | 主要分析，難度放入模型 |
| `staircase` | 階梯法逐試次調整難度 | 敏感度分析 |
| `unrecorded_varied` | 難度有變化但沒記錄 | 排除（若 G3 無假象，可進敏感度分析） |
| `unclear` | 無法判斷 | 排除 |

**編碼時不可以看任何模型結果。** 若 `Condition` 同時包含非難度的操弄（例如注意力提示），在 `notes` 註明；只要它是 ≤ 4 級的離散因子，仍可作為 `condition` 放入 d′、c 和 log(M)。

**`code/06_empirical/02_select_datasets.R`**

```r
suppressPackageStartupMessages(library(dplyr))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
out_dir <- here::here("data", "processed", "v3", "empirical")
screen <- readr::read_csv(file.path(out_dir, "screening_table.csv"), show_col_types = FALSE)
manual <- readr::read_csv(here::here("config", "empirical_manual_coding.csv"), show_col_types = FALSE)

cand <- screen |> inner_join(manual, by = "dataset") |>
  filter(auto_eligible, conf_higher_is_more) |>
  mutate(set = case_when(
    category == e$primary_category & difficulty_design %in% e$difficulty_designs_primary ~ "primary",
    category == e$primary_category & difficulty_design %in% e$difficulty_designs_sensitivity ~ "sensitivity",
    category == e$secondary_category & difficulty_design %in% e$difficulty_designs_primary ~ "secondary",
    TRUE ~ "excluded"),
    n_cond_ok = is.na(n_condition) | n_condition <= e$max_condition_levels) |>
  mutate(set = if_else(!n_cond_ok & set != "excluded", "excluded", set)) |>
  arrange(set, dataset)

# Cap the primary set by seeded random sampling (pre-specified).
prim <- filter(cand, set == "primary")
if (nrow(prim) > e$max_datasets_primary) {
  set.seed(cfg3$seed_base_v3)
  keep <- sample(prim$dataset, e$max_datasets_primary)
  cand <- cand |> mutate(set = if_else(set == "primary" & !dataset %in% keep, "primary_not_sampled", set))
}
readr::write_csv(cand, file.path(out_dir, "selected_datasets.csv"))
print(count(cand, set))
```

**預先規定的 tag（在任何真實資料擬合之前）**：

```bash
git add code/06_empirical config/empirical_manual_coding.csv tests/test_eligibility.R \
        data/processed/v3/empirical/screening_table.csv data/processed/v3/empirical/selected_datasets.csv \
        data/processed/v3/empirical/raw_manifest.csv docs/data_access_confidence_db.md
git commit -m "v3 empirical: pre-specified screening, manual difficulty coding and dataset selection"
git tag v3-prereg-empirical
git push origin v3-enhancement --tags
```

（可選：把這個 commit 的 `config/v3.yml` + `selected_datasets.csv` 上傳到 OSF 註冊，時間戳記更可信。）

### 5.5 `code/06_empirical/03_prepare_datasets.R`

```r
suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "06_empirical", "eligibility.R"))
e <- yaml::read_yaml(here::here("config", "v3.yml"))$empirical
raw_dir <- here::here("data", "raw", "confidence_db")
prep_dir <- here::here("data", "interim", "v3_empirical", "prepared")
dir.create(prep_dir, recursive = TRUE, showWarnings = FALSE)

sel <- readr::read_csv(here::here("data", "processed", "v3", "empirical", "selected_datasets.csv"),
                       show_col_types = FALSE) |>
  filter(set %in% c("primary", "sensitivity", "secondary"))

prep_log <- purrr::map_dfr(seq_len(nrow(sel)), function(i) {
  s <- sel[i, ]
  d <- readr::read_csv(file.path(raw_dir, paste0("data_", s$dataset, ".csv")),
                       show_col_types = FALSE, guess_max = 100000)
  dcol <- if (s$difficulty_design == "recorded_levels") s$difficulty_column else NULL
  h <- harmonise_dataset(d, e, difficulty_col = dcol)
  h$dataset <- s$dataset; h$set <- s$set
  usable <- h$K >= e$k_min && h$n_participants_kept >= e$min_participants
  if (usable) qs2::qs_save(h, file.path(prep_dir, paste0(s$dataset, ".qs2")))
  tibble::tibble(dataset = s$dataset, set = s$set, K = h$K,
                 n_cond = nlevels(h$data$condition),
                 n_participants_raw = h$n_participants_raw,
                 n_participants_kept = h$n_participants_kept,
                 n_trials = nrow(h$data), acc_agreement = h$acc_agreement,
                 conf_acc_rho = h$conf_acc_rho, usable = usable)
})
readr::write_csv(prep_log, here::here("data", "processed", "v3", "empirical", "prepare_log.csv"))
print(prep_log, n = Inf)
```

檢查 `prepare_log.csv`：
- `acc_agreement` 應該 ≥ 0.99。若低，代表 stimulus/response 編碼方向和資料集的 Accuracy 定義不同，**停下來查**。
- `conf_acc_rho` 應為正。若 ≤ 0，這個資料集的信心方向或欄位有問題，排除並記錄。

### 5.6 泛化 PPC 函式：`code/04_ppc_and_comparison/ppp_functions.R`

`g2_ppp_fullfits.R` 寫死了 K = 4（`col_map`、每組 8 欄、16 個格子、`1:7` 迴圈）且只以 participant 分組。實證資料的 K 會變，還有 condition 分組。抽出並泛化：

```r
# Generalised replicated-data posterior predictive p-values for hmetad fits
# with any K and any grouping columns. For K = 4 and group_cols = "participant"
# this must reproduce g2_ppp_fullfits.R exactly (tests/test_ppp_functions.R).

make_col_map <- function(K) {
  expand.grid(confidence = seq_len(K), response = 0:1, stimulus = 0:1) |>
    dplyr::mutate(col = stimulus * 2L * K +
                    ifelse(response == 0, K - confidence + 1L, K + confidence)) |>
    dplyr::arrange(col) |>
    dplyr::select(stimulus, response, confidence, col) |>
    tibble::as_tibble()
}

ppp_one_fit_general <- function(fit, agg, K, group_cols = "participant", seed, ndraws = NULL) {
  col_map <- make_col_map(K)
  width   <- 2L * K                                   # columns per group x stimulus

  ep <- if (is.null(ndraws)) hmetad::epred_draws_metad(fit, agg)
        else hmetad::epred_draws_metad(fit, agg, ndraws = ndraws)
  ep <- ep |> dplyr::ungroup() |>
    dplyr::arrange(.draw, dplyr::across(dplyr::all_of(group_cols)), stimulus, response, confidence)
  n_draws <- dplyr::n_distinct(ep$.draw)
  n_cols  <- nrow(ep) / n_draws
  stopifnot(n_cols == round(n_cols), n_cols %% width == 0)
  P <- matrix(ep$.epred, nrow = n_draws, byrow = TRUE)

  cols <- ep |> dplyr::filter(.draw == min(.draw)) |>
    dplyr::select(dplyr::all_of(group_cols), stimulus, response, confidence) |>
    dplyr::left_join(col_map, by = c("stimulus", "response", "confidence"))
  stopifnot(nrow(cols) == n_cols, !anyNA(cols$col))
  n_groups <- n_cols / width

  arr  <- array(P, c(n_draws, width, n_groups))
  sums <- apply(arr, c(1, 3), sum)
  stopifnot(max(abs(sums - 1)) < 1e-8)

  key  <- function(df) do.call(paste, c(df[group_cols], sep = "|"))
  pidx <- match(key(cols), key(agg))
  stopifnot(!anyNA(pidx))
  obs  <- agg$N[cbind(pidx, cols$col)]
  n_ps <- ifelse(cols$stimulus == 0, agg$N_0[pidx], agg$N_1[pidx])

  n_cells <- 4L * K
  A <- outer(cols$col, seq_len(n_cells), `==`) * 1
  cell_stim   <- col_map$stimulus[order(col_map$col)]
  tot_by_cell <- ifelse(cell_stim == 0, sum(agg$N_0), sum(agg$N_1))
  conf_top    <- col_map$col[col_map$confidence == K]
  n_rows      <- nrow(agg)
  df3         <- n_rows * n_cells - n_rows * 2

  E   <- sweep(P, 2, n_ps, `*`)
  E16 <- E %*% A
  discrepancies <- function(Y) {
    d <- sweep(Y %*% A - E16, 2, tot_by_cell, `/`)
    cbind(stat1_rmse     = sqrt(rowMeans(d^2)),
          stat2_highconf = rowMeans(abs(d[, conf_top, drop = FALSE])),
          stat3_x2_df    = rowSums((Y - E)^2 / E) / df3)
  }

  set.seed(seed)
  n_rem <- matrix(rep(n_ps[seq(1, n_cols, by = width)], each = n_draws), n_draws, n_groups)
  p_rem <- matrix(1, n_draws, n_groups)
  Yarr  <- array(0L, c(n_draws, width, n_groups))
  for (k in seq_len(width - 1L)) {
    pk <- arr[, k, ]
    q  <- pmin(pmax(pk / pmax(p_rem, 1e-300), 0), 1)
    yk <- matrix(stats::rbinom(length(n_rem), n_rem, q), n_draws, n_groups)
    Yarr[, k, ] <- yk
    n_rem <- n_rem - yk
    p_rem <- p_rem - pk
  }
  Yarr[, width, ] <- n_rem
  Yrep <- matrix(Yarr, n_draws, n_cols)

  T_obs <- discrepancies(matrix(obs, n_draws, n_cols, byrow = TRUE))
  T_rep <- discrepancies(Yrep)
  p <- colMeans(T_rep >= T_obs)
  tibble::tibble(n_draws = n_draws,
                 p_stat1_rmse = p[["stat1_rmse"]],
                 p_stat2_highconf = p[["stat2_highconf"]],
                 p_stat3_x2_df = p[["stat3_x2_df"]],
                 mean_obs_stat2 = mean(T_obs[, "stat2_highconf"]),
                 mean_rep_stat2 = mean(T_rep[, "stat2_highconf"]))
}
```

注意 `n_ps[seq(1, n_cols, by = width)]` 依賴「同一組 × 刺激的 `width` 個欄位連續排列」，這由上面的 `arrange()` 保證（與原腳本相同的假設）。

**`tests/test_ppp_functions.R`（回歸測試，必做）**

```r
source(here::here("code", "04_ppc_and_comparison", "ppp_functions.R"))

test_that("make_col_map(4) reproduces the hard-coded K = 4 layout", {
  ref <- tibble::tribble(
    ~stimulus, ~response, ~confidence, ~col,
    0, 0, 4, 1,  0, 0, 3, 2,  0, 0, 2, 3,  0, 0, 1, 4,
    0, 1, 1, 5,  0, 1, 2, 6,  0, 1, 3, 7,  0, 1, 4, 8,
    1, 0, 4, 9,  1, 0, 3, 10, 1, 0, 2, 11, 1, 0, 1, 12,
    1, 1, 1, 13, 1, 1, 2, 14, 1, 1, 3, 15, 1, 1, 4, 16)
  got <- make_col_map(4)
  expect_equal(as.data.frame(lapply(got, as.numeric)), as.data.frame(lapply(ref, as.numeric)))
})

test_that("generalised PPP reproduces the stored v2 p-values on stored G2 fits", {
  skip_if_not(dir.exists(here::here("data", "interim")))
  source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
  seed_base <- yaml::read_yaml(here::here("config", "design.yml"))$seed_base
  ref <- readr::read_csv(here::here("data", "processed", "v2", "g2_ppp_by_fit.csv"), show_col_types = FALSE)
  files <- sort(list.files(here::here("data", "interim"),
                           pattern = "^g2_.*_rep-0[12]_.*[.]qs2$", full.names = TRUE))[1:2]
  for (f in files) {
    r   <- qs2::qs_read(f)
    got <- ppp_one_fit_general(r$fit, r$agg, K = 4, group_cols = "participant",
                               seed = seed_base + r$grid_id)
    exp <- ref[ref$grid_id == r$grid_id, ]
    expect_equal(got$p_stat1_rmse,     exp$p_stat1_rmse,     tolerance = 1e-12)
    expect_equal(got$p_stat2_highconf, exp$p_stat2_highconf, tolerance = 1e-12)
    expect_equal(got$p_stat3_x2_df,    exp$p_stat3_x2_df,    tolerance = 1e-12)
  }
})
```

第二個測試通過，才代表泛化版本沒有改變 v1.2 的結果。若不通過，最常見的原因是 `arrange()` 順序或 `set.seed` 的位置和原腳本不同。

### 5.7 `code/06_empirical/04_fit_dataset.R`

```r
# Usage: Rscript code/06_empirical/04_fit_dataset.R <dataset> <normal|gumbel_min>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2, args[2] %in% c("normal", "gumbel_min"))
dataset <- args[1]; family <- args[2]

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical

prep <- qs2::qs_read(here::here("data", "interim", "v3_empirical", "prepared", paste0(dataset, ".qs2")))
out_dir <- here::here("data", "interim", "v3_empirical", "fits")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, sprintf("%s__%s.qs2", dataset, family))
if (file.exists(out_path)) { cat("exists\n"); quit(save = "no") }

multi_cond <- nlevels(prep$data$condition) > 1
# Same seed for both families of a dataset: derived from the dataset name only.
seed <- cfg3$seed_base_v3 + sum(utf8ToInt(dataset)) * 7L

fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
  prep$data, K = prep$K, group = "participant",
  distribution = family, metac_absolute = cfg$fitting$metac_absolute,
  hierarchical_dprime_c = TRUE,
  hierarchical_thresholds = e$hierarchical_thresholds,       # TRUE for real data
  log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
  agg_by = if (multi_cond) "condition" else NULL,
  dprime_c_covariates = if (multi_cond) "condition" else NULL,
  log_M_covariates = if (multi_cond) "condition" else NULL,
  chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
  iter_sampling = cfg$sampling$iter_sampling,
  adapt_delta = adapt_delta, max_treedepth = max_treedepth,
  rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
  tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
  extra_stanvars = if (family == "gumbel_min") gumbel_min_stanvars() else NULL,
  metadata = list(dataset = dataset, family = family, set = prep$set))

a <- fit_once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, seed)
a$escalated <- FALSE
if (identical(a$status, "refit")) {
  a <- fit_once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth, seed + 1L)
  a$escalated <- TRUE
  if (identical(a$status, "refit")) a$status <- "fail"
}
if (!is.null(a$fit)) {
  a$loo <- tryCatch(brms::loo(a$fit), error = function(err) NULL)
  dr <- posterior::as_draws_df(a$fit)
  a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
}
a$condition_map <- prep$condition_map
a$K <- prep$K
qs2::qs_save(a, out_path)   # full fit kept: needed for LOO repair and PPC
cat(dataset, family, "status:", a$status, " elapsed:", round(a$elapsed_secs), "s\n")
```

**LOO 單位**：多條件時資料按「受試者 × 條件」聚合，所以一個 LOO 觀察值 = 一位受試者在一個條件下的計數，和模擬（一位受試者）不同。這要寫進報告。K-fold 修補時則以受試者為單位分組（5.8）。

**試跑**：選 `prepare_log.csv` 中受試者最少和最多的兩個資料集，各跑兩個家族：

```bash
Rscript code/06_empirical/04_fit_dataset.R <smallest_dataset> normal
Rscript code/06_empirical/04_fit_dataset.R <smallest_dataset> gumbel_min
Rscript code/06_empirical/04_fit_dataset.R <largest_dataset> normal
Rscript code/06_empirical/04_fit_dataset.R <largest_dataset> gumbel_min
```

試跑決定點：
- 四個都跑完、`status` 為 `pass` 或經升級後 `pass` → 繼續。
- 最大的資料集一次超過 ~2 小時 → 在 `config/v3.yml` 加一條 `max_participants_for_fit`，**寫進 analysis_log 並在正式跑之前 commit**，超過者隨機抽受試者（固定種子）。這是對預先規定的偏離，要明確記錄。
- `hierarchical_thresholds = TRUE` 造成大量 divergence → 記錄，先試 `adapt_delta = 0.99` 作為起始值（同樣要記錄為偏離）。

正式跑用與 G3 相同的分片方式，`code/06_empirical/run_empirical_shard.R`：

```r
args <- commandArgs(trailingOnly = TRUE)
shard <- as.integer(args[1]); n_shards <- as.integer(args[2])
prep_dir <- here::here("data", "interim", "v3_empirical", "prepared")
jobs <- tidyr::expand_grid(dataset = sort(sub("[.]qs2$", "", list.files(prep_dir, "[.]qs2$"))),
                           family  = c("normal", "gumbel_min"))
idx <- seq_len(nrow(jobs))
for (i in idx[(idx - 1L) %% n_shards == (shard - 1L)]) {
  system2("Rscript", c(here::here("code", "06_empirical", "04_fit_dataset.R"),
                       jobs$dataset[i], jobs$family[i]))
}
```

```bash
Rscript code/06_empirical/run_empirical_shard.R 1 3   # terminals 1-3
```

### 5.8 `code/06_empirical/05_loo_repair.R`

```r
# For each fit: if bad-k share <= max_prop_bad_k_for_reloo -> reloo;
# otherwise grouped K-fold by participant with folds shared by both families.
suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
dir.create(rep_dir, recursive = TRUE, showWarnings = FALSE)

datasets <- unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$")))
for (ds in datasets) {
  fits <- purrr::map(c("normal", "gumbel_min"),
                     ~ qs2::qs_read(file.path(fit_dir, sprintf("%s__%s.qs2", ds, .x))))
  prop_bad <- purrr::map_dbl(fits, ~ mean(.x$loo$diagnostics$pareto_k > cfg3$loo_robust$k_threshold))
  method <- if (all(prop_bad <= e$loo_repair$max_prop_bad_k_for_reloo)) "reloo" else "kfold"

  if (method == "kfold") {
    # One fold per participant, shared across the two families.
    part <- fits[[1]]$fit$data$participant
    set.seed(cfg3$seed_base_v3 + sum(utf8ToInt(ds)))
    pf <- loo::kfold_split_random(K = cfg3$loo_robust$kfold_K, N = length(unique(part)))
    folds <- pf[match(part, sort(unique(part)))]
  }
  for (j in 1:2) {
    fam <- c("normal", "gumbel_min")[j]
    out_path <- file.path(rep_dir, sprintf("%s__%s.qs2", ds, fam))
    if (file.exists(out_path)) next
    f <- fits[[j]]
    res <- if (method == "reloo") {
      tryCatch(brms::loo(f$fit, reloo = TRUE, k_threshold = cfg3$loo_robust$k_threshold,
                         reloo_args = list(check = FALSE, cores = 4, refresh = 0)),
               error = function(err) err)
    } else {
      tryCatch(brms::kfold(f$fit, folds = folds, chains = 4, cores = 4, refresh = 0,
                           save_fits = FALSE),
               error = function(err) err)
    }
    qs2::qs_save(list(dataset = ds, family = fam, method = method,
                      prop_bad_k = prop_bad[j], loo_repaired = res,
                      ok = !inherits(res, "error")), out_path)
    cat(ds, fam, method, "ok:", !inherits(res, "error"), "\n")
  }
}
```

⚠️ `reloo` 和 `kfold` 的結果不能互相比較。同一資料集的兩個家族**一定用同一種方法**（上面程式碼已保證）。

### 5.9 `code/06_empirical/06_ppc_dataset.R`

```r
suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "04_ppc_and_comparison", "ppp_functions.R"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")

files <- sort(list.files(fit_dir, "[.]qs2$", full.names = TRUE))
ppc <- purrr::map_dfr(files, function(f) {
  a <- qs2::qs_read(f)
  if (is.null(a$fit)) return(NULL)
  gcols <- setdiff(names(a$agg), c("N", "N_0", "N_1"))   # CHECK: inspect names(a$agg) once first
  res <- ppp_one_fit_general(a$fit, a$agg, K = a$K, group_cols = gcols,
                             seed = cfg3$seed_base_v3 + sum(utf8ToInt(basename(f))),
                             ndraws = 1000)
  dplyr::bind_cols(tibble::tibble(dataset = a$dataset, family = a$family), res)
})
readr::write_csv(ppc, here::here("data", "processed", "v3", "empirical", "ppc_by_fit.csv"))
```

先對一個擬合執行 `names(a$agg)`，確認除了分組欄位與 `N`、`N_0`、`N_1` 之外沒有其他欄位；若有，把它們加進 `setdiff()` 的排除清單。

### 5.10 `code/06_empirical/07_summarise_empirical.R`

```r
suppressPackageStartupMessages(library(dplyr))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
out <- here::here("data", "processed", "v3", "empirical")
sel <- readr::read_csv(file.path(out, "selected_datasets.csv"), show_col_types = FALSE)

# Condition-level log_M draws: L1 = intercept, Lk = intercept + b_conditionLk.
logM_levels <- function(draws, labels) {
  sapply(labels, function(l) {
    nm <- paste0("b_condition", l)
    if (nm %in% names(draws)) draws$b_Intercept + draws[[nm]] else draws$b_Intercept
  })
}

one_dataset <- function(ds) {
  f <- purrr::map(c(normal = "normal", gumbel = "gumbel_min"),
                  ~ qs2::qs_read(file.path(fit_dir, sprintf("%s__%s.qs2", ds, .x))))
  r <- purrr::map(c(normal = "normal", gumbel = "gumbel_min"),
                  ~ qs2::qs_read(file.path(rep_dir, sprintf("%s__%s.qs2", ds, .x))))
  statuses <- purrr::map_chr(f, "status")
  repaired_ok <- all(purrr::map_lgl(r, "ok"))

  # elpd(normal) - elpd(gumbel): > 0 favours Gaussian
  if (repaired_ok) {
    cmp <- loo::loo_compare(list(normal = r$normal$loo_repaired, gumbel = r$gumbel$loo_repaired))
    diff <- cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"]; se <- max(cmp[, "se_diff"])
  } else { diff <- NA_real_; se <- NA_real_ }

  category <- dplyr::case_when(
    any(!statuses %in% c("pass")) | !repaired_ok ~ "unreliable",
    diff >  e$categories$two_se_rule * se ~ "clear_gaussian",
    diff < -e$categories$two_se_rule * se ~ "clear_gumbel",
    TRUE ~ "inconclusive")

  labels <- f$normal$condition_map$label
  LN <- logM_levels(f$normal$draws_b_sd, labels)
  LG <- logM_levels(f$gumbel$draws_b_sd, labels)
  overall_N <- rowMeans(as.matrix(LN)); overall_G <- rowMeans(as.matrix(LG))

  base <- tibble::tibble(
    dataset = ds, method = r$normal$method, status_normal = statuses[["normal"]],
    status_gumbel = statuses[["gumbel"]], elpd_diff = diff, se = se, category = category,
    logM_normal = mean(overall_N), logM_gumbel = mean(overall_G),
    delta_logM = mean(overall_N) - mean(overall_G),   # same sign as simulation delta_mis
    n_levels = length(labels))

  contrasts <- if (length(labels) > 1) purrr::map_dfr(labels[-1], function(l) {
    cN <- LN[, l] - LN[, labels[1]]; cG <- LG[, l] - LG[, labels[1]]
    excl <- function(x) { q <- quantile(x, c(.025, .975)); q[1] > 0 | q[2] < 0 }
    tibble::tibble(dataset = ds, contrast = paste(l, "-", labels[1]),
                   contrast_normal = mean(cN), contrast_gumbel = mean(cG),
                   change = mean(cN) - mean(cG),
                   excl0_normal = excl(cN), excl0_gumbel = excl(cG),
                   conclusion_flip = excl(cN) != excl(cG))
  }) else NULL
  list(base = base, contrasts = contrasts)
}

ds_list <- unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$")))
res <- purrr::map(ds_list, one_dataset)
by_ds <- purrr::map_dfr(res, "base") |> left_join(select(sel, dataset, set, difficulty_design), by = "dataset")
contr <- purrr::map_dfr(res, "contrasts")
ppc <- readr::read_csv(file.path(out, "ppc_by_fit.csv"), show_col_types = FALSE)

readr::write_csv(by_ds, file.path(out, "empirical_by_dataset.csv"))
readr::write_csv(contr, file.path(out, "empirical_condition_contrasts.csv"))

summary_tbl <- by_ds |> count(set, category) |> group_by(set) |> mutate(prop = n / sum(n))
readr::write_csv(summary_tbl, file.path(out, "empirical_category_summary.csv"))
print(summary_tbl)
cat("\nMedian delta_logM (normal - gumbel) by set:\n")
print(by_ds |> group_by(set) |> summarise(median_delta = median(delta_logM), n = n()))
cat("\nCondition contrasts with a conclusion flip:", sum(contr$conclusion_flip), "of", nrow(contr), "\n")
```

主要結果（在 5.4 已經 tag 規定）：

1. 每組資料集（primary / sensitivity / secondary）的四類比例：`clear_gaussian`、`clear_gumbel`、`inconclusive`、`unreliable`。
2. `delta_logM` 的分佈（方向是否和模擬一致：資料偏 Gumbel 時，高斯模型給的 log(M) 較高）。
3. 條件對比的改變量與 `conclusion_flip` 次數。
4. PPC：兩個家族在最高信心格的 `p_stat2_highconf`。

```bash
git add code/06_empirical data/processed/v3/empirical
git commit -m "v3 empirical: fits, LOO repair, PPC and pre-specified summary"
```

---

## 6. 步驟 5：新圖表

新圖放 `outputs/figures/v3/`，沿用 `fig_1`–`fig_5` 的 ggplot 主題（打開 `fig_4_g2_misspecification.R` 複製主題設定）。

| 腳本 | 內容 | 資料來源 |
|---|---|---|
| `fig_6_relative_bias.R` | A：`delta_mean ± 2·mcse` 對 `n_trials`（log2 軸），顏色 = d′，形狀 = N。B：`base_mean`（G2 正確）與 G0 偏差並列 | `g2_relative_bias_by_cell.csv`、`g2_baseline_vs_g0.csv` |
| `fig_7_loo_robust.R` | `diff_psis` vs `diff_exact` 散佈圖加 y = x 線；點形狀 = 是否有 bad k | `g2_loo_psis_vs_exact_by_pair.csv` |
| `fig_8_g3_mixture.R` | A：各條件 × 聚合方式的 ELPD 差分佈（0 與 ±2SE 參考線）。B：各擬合的 log(M) 偏差 | `g3_loo_by_rep.csv`、`g3_bias.csv` |
| `fig_9_empirical.R` | A：每個資料集的 `elpd_diff ± 2·se` 森林圖，依類別上色。B：`delta_logM` 對 `elpd_diff` | `empirical_by_dataset.csv` |

`fig_6` 範例骨架：

```r
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
d <- readr::read_csv(here::here("data", "processed", "v3", "g2_relative_bias_by_cell.csv"),
                     show_col_types = FALSE) |> filter(analysis == "primary")
p <- ggplot(d, aes(n_trials, delta_mean, colour = factor(dprime_target),
                   shape = factor(n_participants))) +
  geom_hline(yintercept = 0, linetype = 2) +
  geom_pointrange(aes(ymin = delta_mean - 2 * delta_mcse, ymax = delta_mean + 2 * delta_mcse),
                  position = position_dodge(width = 0.15)) +
  scale_x_continuous(trans = "log2", breaks = c(100, 200, 400)) +
  labs(x = "Trials per participant", y = expression(Delta[mis] ~ "= log M (Gaussian) - log M (correct)"),
       colour = "d'", shape = "N")
dir.create(here::here("outputs", "figures", "v3"), recursive = TRUE, showWarnings = FALSE)
ggsave(here::here("outputs", "figures", "v3", "fig_6_relative_bias.png"), p, width = 6, height = 4, dpi = 300)
```

---

## 7. Makefile、測試與收尾

### 7.1 Makefile 新增目標

```make
.PHONY: v3-relbias v3-reloo v3-g3 v3-empirical-screen v3-empirical-fit v3-empirical-summary v3-figures

v3-relbias:
	$(RSCRIPT) code/03_recovery_analysis/relative_bias.R

v3-reloo:   # ~2-3 h; needs stored full fits (reps 1-2)
	$(RSCRIPT) code/04_ppc_and_comparison/v3_reloo_stored_fits.R 1 1
	$(RSCRIPT) code/04_ppc_and_comparison/v3_loo_robust_summary.R

v3-g3:      # ~2-3 h at 4 shards; single-process target shown here
	$(RSCRIPT) code/00_setup/03_create_grid_g3.R
	$(RSCRIPT) code/02_fit/run_g3_shard.R 1 1
	$(RSCRIPT) code/04_ppc_and_comparison/v3_g3_summary.R

v3-empirical-screen:
	$(RSCRIPT) code/06_empirical/01_screen_datasets.R
	$(RSCRIPT) code/06_empirical/02_select_datasets.R
	$(RSCRIPT) code/06_empirical/03_prepare_datasets.R

v3-empirical-fit:
	$(RSCRIPT) code/06_empirical/run_empirical_shard.R 1 1
	$(RSCRIPT) code/06_empirical/05_loo_repair.R
	$(RSCRIPT) code/06_empirical/06_ppc_dataset.R

v3-empirical-summary:
	$(RSCRIPT) code/06_empirical/07_summarise_empirical.R

v3-figures:
	$(RSCRIPT) code/05_figures/fig_6_relative_bias.R
	$(RSCRIPT) code/05_figures/fig_7_loo_robust.R
	$(RSCRIPT) code/05_figures/fig_8_g3_mixture.R
	$(RSCRIPT) code/05_figures/fig_9_empirical.R
```

Windows 沒有 `make` 時，比照 `code/run_downstream.R` 寫一個 `code/run_v3.R` 依序 `source()` 不需重擬合的步驟（relbias、summary、figures）。

### 7.2 測試清單（全部通過才可以合併回 `main`）

| 測試檔 | 保護什麼 |
|---|---|
| `test_formula_backcompat.R` | 修改 fit wrapper 後，v1.2.1 的公式與先驗不變 |
| `test_ppp_functions.R` | 泛化 PPC 在 K = 4 時與 v1.2 的 p 值完全一致 |
| `test_eligibility.R` | 信心級數合併、刺激/反應編碼、篩選規則 |
| `test_simulate_g3.R` | 混合模擬的試次數與難度方向 |
| 既有三個測試 | v1 的產生器與資料格式 |

```bash
Rscript -e 'testthat::test_dir("tests")'
```

### 7.3 收尾清單

- [ ] `docs/analysis_log.md`：每個步驟都有日期、腳本、輸出、偏離。
- [ ] `docs/design_decisions.md`：新增「v3 deviations」段落（例如 `max_participants_for_fit`、adapt_delta 調整）。
- [ ] `docs/computational_environment.md`：記錄 v3 跑的 R、brms、hmetad、loo 版本和機器。
- [ ] `README.md`：新增 v3 狀態、重現指令、四張新圖、實證資料取得方式（不附原始資料）。
- [ ] `CITATION.cff`：版本改為 `2.0.0`。
- [ ] 合併：`git checkout main && git merge --no-ff v3-enhancement`，tag `v2.0.0`，push。
- [ ] 透過 Zenodo–GitHub 整合取得這個版本的 DOI（預印本引用用）。

---

## 附錄 A：常見錯誤排除

| 症狀 | 可能原因 | 處理 |
|---|---|---|
| `could not find function "gumbel_min_lcdf"` | 沒有 source `simulate_g2_gumbel.R` | 所有會做 `log_lik`、`epred`、`reloo`、`kfold` 的腳本最上方都要 source |
| `priors do not correspond to any model parameter` | 共變項沒有進公式，卻設了 `class = "b"` 先驗 | `log_M_b_prior` 只在有 `log_M_covariates` 時傳入（預設已如此） |
| reloo/kfold 報 `new levels` 錯誤 | 未允許新層級 | 在 `reloo_args` 或 `kfold(...)` 加 `allow_new_levels = TRUE, sample_new_levels = "uncertainty"` |
| reloo 每次都重新編譯 Stan（很慢） | rstan 模型物件未隨 `.qs2` 保存 | 正常現象，每個擬合編譯一次約 1 分鐘；已計入時間預估 |
| `epred_draws_metad` 記憶體不足 | 實證資料受試者多 | 用 `ndraws = 1000`（見 1.3 (d)） |
| `pivot_wider` 產生 list 欄位 | 某個 key 組合重複（例如 v1 有重跑的列） | `count(g2, across(all_of(keys)), fit_variant) |> filter(n > 1)` 找出並記錄 |
| VS Code 的 R 用了全域套件庫 | `.Rprofile` 沒被讀取 | 關掉 R 終端機重開，確認 `.libPaths()`（原計劃已記載） |
| `make` 找不到 | Windows | 直接用 `Rscript` 指令，或 `code/run_v3.R` |

## 附錄 B：決定點總表

| 位置 | 條件 | 若成立 | 若不成立 |
|---|---|---|---|
| 1.3 API 確認 | 四項 API 行為符合預期 | 照主要寫法 | 用各節的備案，記錄在 analysis_log |
| 2.3 相對偏差 | 數值與健全性檢查一致 | 進入步驟 2 | 先查配對錯誤 |
| 3.5 LOO | `twose_agreement ≥ 0.9` | 報告「修補後不變」 | 做 3.4 K-fold，以它為主要結果（不停） |
| 4.7 G3 | 預先規定的假象規則 | 實證必須建模難度；未記錄難度者排除 | 未記錄難度者可進敏感度分析 |
| 4.7 G3 | difficulty 版本 Δlog(M) ≈ 0 | 進入步驟 4 | 先查清楚，不進入實證 |
| 5.5 準備 | `acc_agreement ≥ 0.99`、`conf_acc_rho > 0` | 保留資料集 | 排除並記錄 |
| 5.7 試跑 | 四個試跑擬合正常、時間可接受 | 正式跑 | 記錄偏離（受試者上限或 adapt_delta）後再跑 |
| 5.10 結果 | 任何類別比例 | **照實報告** | 不因結果不理想而改規則 |
