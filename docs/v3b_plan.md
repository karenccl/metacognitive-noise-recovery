# Project 1 v3b：投稿前補強計劃與程式指南

> **狀態（2026-10-14）：暫停，等決定投稿時再啟動。** 本計劃沒有執行任何部分：沒有 `config/v3b.yml`、沒有 `v3b-prereg` tag、沒有 v3b 的擬合或分析。`v2.0.0` 已在本計劃之前發佈。重新啟動時，先依目前的 `main` 更新本文件中的 HEAD 和分支名稱（v3 已合併進 `main`，`v3-enhancement` 不再使用），再從工作包 A 開始。

> 範圍：v3 實證擬合跑完之前和之後，為了**一次順利投稿**而追加的工作。
> 原則：**審稿人很可能要求、且 ≤ 約 2 天能完成的，現在做；其餘寫進 `docs/deferred.md`。**
> 對應 repo：`metacognitive-noise-recovery`，分支 `v3-enhancement`（目前 HEAD = `dc2124c`）。
> 寫於 2026-10-02。所有程式碼依 repo 現有函式寫成（`fit_one_hmetad()`、`simulate_g2_gumbel()`、`run_one_cell.R` 的紀錄格式、`v3_sdprior_hetero_validation.R` 的分片寫法）。
> 標示 **⚠️ 先確認** 的地方，是我無法在你的 Windows R 上實際執行驗證的細節，第一次執行時請先看輸出再繼續。

---

## 目錄

- [0. 總覽](#0-總覽)
- [1. 工作包 A：準備與事先規定（半天）](#1-工作包-a準備與事先規定半天)
- [2. 工作包 B：d′ 混淆的偽陽性再分析（1 天，不需新擬合）](#2-工作包-bd-混淆的偽陽性再分析1-天不需新擬合)
- [3. 工作包 C：兩組單一模型檢定（1 天 + 背景運算）](#3-工作包-c兩組單一模型檢定1-天--背景運算)
- [4. 工作包 D：不等變異數生成器 G4（1–1.5 天 + 背景運算）](#4-工作包-d不等變異數生成器-g411.5-天--背景運算)
- [5. 工作包 E：圖](#5-工作包-e圖)
- [6. 工作包 F：實證分析收尾](#6-工作包-f實證分析收尾)
- [7. 工作包 G：寫作](#7-工作包-g寫作)
- [8. 工作包 H：投稿前清單與發佈](#8-工作包-h投稿前清單與發佈)
- [附錄 A：常見錯誤排除](#附錄-a常見錯誤排除)
- [附錄 B：決定點總表](#附錄-b決定點總表)
- [附錄 C：時間表](#附錄-c時間表)

---

## 0. 總覽

### 0.1 工作包

| 包 | 內容 | 回答哪個審稿問題 | 新擬合 | 時間 |
|---|---|---|---|---|
| A | 設定檔、`deferred.md`、事先規定 tag | 「這些分析是看了結果才加的嗎？」 | 否 | 半天 |
| B | 用現有 480 個 G2 擬合算「分組各自擬合」時的偽陽性率 | 「偏差有實際後果嗎？」 | 否 | 1 天 |
| C | 兩組（d′ 不同、log M 相同）放進**同一個模型**檢定組別差異 | 同上，用正式的組間模型 | 40 | 1 天 + 2–5 h |
| D | 不等變異數高斯（UV）生成器，看 LOO 會不會因此偏好 Gumbel-min | 「偏好 Gumbel 會不會只是不等變異數？」 | 80 | 1–1.5 天 + 4–10 h |
| E | 圖 10（主圖）、圖 S（補充） | — | 否 | 半天 |
| F | 實證：LOO 修補 → PPC → 彙整 → 圖 9 | 主要實證結果 | 已在跑 | 依運算 |
| G | 文獻定位、效果量基準、UV 討論、和 Meyer-Grant 對照、改寫論文 | 新穎性、主張範圍 | 否 | 4–6 天 |
| H | 投稿必備項目、真人閱讀、v2.0.0、DOI、預印本、投稿 | 行政和品質 | 否 | 2 天 + 等待 |

**凍結點**：B、C、D 的結果出來，F 完成之後，**不再新增任何分析**。結果不論方向，都照事先規定的寫法寫進論文。

### 0.2 固定規則

1. **分支**：繼續在 `v3-enhancement` 上做。每完成一個子步驟就 commit。
2. **不要在分片執行中修改 `config/v3.yml`**。v3b 的所有常數放在新檔 `config/v3b.yml`。
3. **新輸出的位置**（都不會覆寫 v1、v2、v3 的檔案）：
   - `data/interim/v3b/`：每次擬合的紀錄（`.qs2` 已經被 `.gitignore` 排除）
   - `data/processed/v3b/`：小型結果表，進 Git
   - `outputs/figures/v3b/`
4. **先規定、再執行**：`config/v3b.yml` 裡的判斷規則先 commit 並 tag `v3b-prereg`，之後才跑任何 v3b 的分析，包括 B 的再分析。
5. **每一步都在 `docs/analysis_log.md` 記一段**：日期、跑了什麼、輸出檔名、任何偏離。
6. **擬合設定**：B、C、D 都是模擬，所以用 **v1 的正式設定**（`config/design.yml`：預設 SD 先驗、閾值不分層、1000 + 1000、adapt_delta 0.95），和 G2 一致，結果才能直接和 G2 比較。**不要**用實證的設定。
7. **符號慣例**（v3b 統一，已寫進 `config/v3b.yml`）：
   - `diff_high_minus_low = log M(高 d′ 組) − log M(低 d′ 組)`；真值 = 0。和 C 裡 `b_groupB` 的方向相同。
   - `elpd_diff = elpd(normal) − elpd(gumbel_min)`：正值 = 偏好高斯（沿用 v3）。

### 0.3 運算排程

實證擬合目前用 4 個分片，每個 4 條鏈，共 16 條。這台機器有 22 個邏輯核心，所以 v3b **只開 1 個分片**（再加 4 條鏈，共 20 條），依序跑 C（job 1–40），再跑 D（job 41–120）。單一分片會依 job 編號順序執行，C 會先完成。

### 0.4 新增檔案一覽

```text
config/v3b.yml
config/grid_v3b.csv                                   # 由腳本產生
docs/v3b_plan.md                                      # 本文件
docs/deferred.md
docs/positioning.md                                   # 工作包 G
code/00_setup/04_create_grid_v3b.R
code/01_simulate/simulate_v3b_two_group.R
code/01_simulate/simulate_g4_uv.R
code/02_fit/run_v3b_jobs.R
code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R
code/04_ppc_and_comparison/v3b_two_group_summary.R
code/04_ppc_and_comparison/v3b_g4_summary.R
code/05_figures/fig_10_dprime_confound.R
code/05_figures/fig_S_g4_uv.R
tests/test_simulate_v3b_two_group.R
tests/test_simulate_g4_uv.R
```

---

## 1. 工作包 A：準備與事先規定（半天）

### 1.1 確認起點

```bash
cd metacognitive-noise-recovery
git status            # 應該只有 renv.lock、v3_reloo_stored_fits.R（只差換行字元）和 enhancement_plan_v2.md
git log --oneline -1  # dc2124c
mkdir -p data/processed/v3b data/interim/v3b outputs/figures/v3b
```

順便處理 `docs/enhancement_plan_v2.md`：在檔案最上面加一行 `> SUPERSEDED by docs/v3_plan.md and docs/v3b_plan.md; kept for the record.`，然後在 1.5 和其他檔案一起 commit。

### 1.2 `config/v3b.yml`

完整內容，直接建立：

```yaml
# v3b pre-submission additions (docs/v3b_plan.md). Locked before any v3b analysis
# (tag v3b-prereg). Simulation-only; fits use the v1 production settings in
# config/design.yml (same as G2), NOT the empirical configuration in config/v3.yml.
version: v3b
seed_base_v3b: 20261003

sign_conventions:
  diff_high_minus_low: "log_M(high-d' group) - log_M(low-d' group); truth = 0; same sign as b_groupB"
  elpd_diff: "elpd(normal) - elpd(gumbel_min); positive = Gaussian preferred (as in v3)"

# Work package B: spurious group differences when two groups that differ only in
# d' are fitted SEPARATELY (common practice), using the stored G2 fits.
reanalysis:
  interval: 0.95
  pair_seed_offset: 7              # seed for the random pairing of posterior draws
  statuses_primary: [pass, fail]   # as in v3 relative_bias.R; sensitivity = pass only

# Work package C: the same question in ONE model with a group covariate.
two_group:
  n_per_group: 20
  n_trials: 200
  dprime_groups: {A: 0.75, B: 1.5}  # A = low d', B = high d'; true log_M equal (design.yml truth)
  replications: 20
  fit_variants: [correct, misspecified]   # gumbel_min, normal

# Pre-specified framing rule for B + C (decides the headline wording, not whether
# the result is reported). "Practically relevant spurious-difference problem" if the
# misspecified false-positive rate is >= 0.20 in any N x T cell of B, OR its pooled
# rate exceeds the correct model's by >= 0.10 in B or in C.
framing_rule:
  cell_fpr_min: 0.20
  pooled_excess_min: 0.10

# Work package D: does unequal-variance Gaussian evidence make LOO prefer gumbel_min?
g4:
  n_participants: 40
  n_trials: 200
  dprimes: [0.75, 1.5]             # mean separation in units of the S1 (stimulus 0) SD
  sigma_ratio: {ev: 1.0, uv: 1.25} # SD(stimulus 1) / SD(stimulus 0); zROC slope = 1/ratio
  sigma_meta: 1.0                  # Gaussian noise added to the evidence before confidence
  conf_thresholds: [0.5, 1.0, 1.5] # distance from the criterion; K = 4
  sd_threshold_jitter: 0.1         # per-participant jitter of the confidence thresholds
  sd_criterion: 0.2                # per-participant type-1 criterion, mean 0
  replications: 10                 # ev and uv share sim_seed within (d', rep): paired datasets
  fit_variants: [normal, gumbel_min]
  # Pre-specified rule, mirrors the G3 artefact rule: "UV mimics gumbel_min" if,
  # pooled over d', LOO favours gumbel_min by > 2 SE in >= 25% of uv datasets AND
  # in <= 10% of ev datasets.
  mimicry_rule:
    uv_min_prop: 0.25
    ev_max_prop: 0.10
    two_se: 2
```

**為什麼是這些數字**：
- C 的格子用 N = 20 + 20、T = 200。這樣總人數 40 和 G2 的 N = 40 一致，運算量也小。
- D 的 `sigma_ratio = 1.25` 對應 zROC 斜率 0.8，是再認記憶文獻裡常見的值；知覺作業的斜率通常較接近 1，所以 1.25 偏向「明顯的違反」。這一點要寫進 limitations。
- D 不評估 log M 的真值回復，因為這個生成器不是 meta-d′ 模型，在 UV 下「真實 M」沒有明確定義。D 只比較 UV 和 EV 對照組之間的差異。

### 1.3 `docs/deferred.md`

```markdown
# Deferred (do not start before submission; revisit only if a reviewer asks)

Rule: a new idea is written here first, never implemented the same day.

| Idea | Why deferred | Trigger to revisit |
|---|---|---|
| UV generator with other ratios (e.g. 0.8, 1.5) or fitting a UV model | v3b G4 answers the mimicry question with one ratio | Reviewer request |
| JAGS HMeta-d / MLE meta-d' cross-check | Different estimator, large new pipeline | Reviewer request |
| Other true log_M values, K != 4, more replications | Generalisation stated as a limitation | Reviewer request |
| K-fold for all G2 fits | Reloo on 24 pairs already agrees with PSIS (v3 step 2) | Reviewer request |
| More empirical datasets / dataset-by-dataset match with Meyer-Grant et al. | Qualitative comparison only (v3b G) | Reviewer request |
| New PPC statistics, new figures beyond Fig. 10 / Fig. S | Main-figure budget is five | Reviewer request |
```

### 1.4 analysis log 條目（範本）

在 `docs/analysis_log.md` 最後加上：

```markdown
## 2026-10-0X - v3b set-up: pre-submission additions, rules locked before any v3b analysis

- Plan: `docs/v3b_plan.md`. Constants and decision rules: `config/v3b.yml` (framing rule for
  the d' confound, G4 mimicry rule). Tag `v3b-prereg` placed on this commit before any v3b
  analysis was run.
- Already known before this commit (so not a pre-specified finding): the v3 step 1 d' contrast
  in Delta_mis (+0.097, SE 0.011, low minus high). Not yet computed: any false-positive rate
  for group comparisons, any two-group fit, any G4 fit.
- Fits in C and D use the v1 production settings (`config/design.yml`), matching G2.
- `docs/deferred.md` lists what is explicitly out of scope before submission.
```

### 1.5 Commit 和 tag

```bash
git add config/v3b.yml docs/v3b_plan.md docs/deferred.md docs/analysis_log.md docs/enhancement_plan_v2.md
git commit -m "v3b: plan, locked constants and decision rules (d' confound framing, G4 mimicry) before any v3b analysis"
git tag v3b-prereg
git push origin v3-enhancement --tags
```

### 1.6 理解檢查

1. 為什麼 C 和 D 要用 v1 的擬合設定，而不是實證的設定？
2. B 裡的 d′ 對比（+0.097）已經知道了，為什麼還要事先規定？事先規定的到底是什麼？

---

## 2. 工作包 B：d′ 混淆的偽陽性再分析（1 天，不需新擬合）

### 2.1 為什麼

G2 的每個格子是分開擬合的。實務上，很多研究也是**每組各自擬合**再比較兩組的 log M（例如病人組和健康組）。如果兩組的真實 log M 相同、只有 d′ 不同，而錯設偏差會隨 d′ 改變，那「兩組 log M 差異的 95% CrI 不含 0」的比例就是**偽陽性率**。B 直接用現有的 480 個擬合回答這個問題：

- 同一個 (N, T, rep) 下，d′ = 0.75 的格子當作「低 d′ 組」，d′ = 1.5 的格子當作「高 d′ 組」。
- 兩個擬合的後驗是獨立的，所以差異的後驗可以把兩邊的 draws 隨機配對後相減。
- 用正確模型（Gumbel-min）做同樣的計算當作基準：正確模型本身也可能有隨 d′ 改變的小偏差（G0 的負偏差就是），所以比較的是**兩種模型的偽陽性率之差**，而不是單純和 5% 比。

每個 fit_variant 有 6 個 N×T 格子 × 20 次 = 120 對。

### 2.2 `code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R`

```r
# v3b work package B: false-positive rate for a between-group difference in log_M
# when two groups differ ONLY in d' and each group is fitted separately.
# Uses the stored G2 fits (draws_b_sd$b_Intercept). No refitting.
# Low-d' group = d' 0.75 cell, high-d' group = d' 1.5 cell, same (N, T, rep, fit_variant).
# diff_high_minus_low: truth = 0 (both cells share log_M = design.yml truth).
#
# Run from the project root: Rscript code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R

suppressPackageStartupMessages(library(dplyr))

cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
ra   <- cfgb$reanalysis
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# ---- Locate the 480 G2 records ---------------------------------------------
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE) |>
  filter(generator == "g2")
grid$path <- here::here("data", "interim", sprintf(
  "g2_cell-%04d_rep-%02d_%s_grid-%05d.qs2",
  grid$cell_id, grid$rep_id, grid$fit_variant, grid$grid_id))
stopifnot(nrow(grid) == 480, all(file.exists(grid$path)))

# ---- Read status + log_M draws (compact record, every rep) -----------------
recs <- lapply(grid$path, function(p) {
  r <- qs2::qs_read(p)
  list(status = r$status,
       x = if (is.null(r$draws_b_sd)) NULL else r$draws_b_sd$b_Intercept)
})
grid$status  <- vapply(recs, function(r) r$status, character(1))
grid$n_draws <- vapply(recs, function(r) length(r$x), integer(1))
draws <- setNames(lapply(recs, `[[`, "x"), grid$grid_id)
cat("status counts:\n"); print(table(grid$fit_variant, grid$status))

# ---- Pair low-d' and high-d' cells -------------------------------------------
keys <- c("fit_variant", "n_participants", "n_trials", "rep_id")
lev  <- grid |> select(grid_id, all_of(keys), dprime_target, status, n_draws)
pairs <- inner_join(filter(lev, dprime_target == 0.75), filter(lev, dprime_target == 1.5),
                    by = keys, suffix = c("_low", "_high"))
stopifnot(nrow(pairs) == 240)

# ---- Posterior of the difference, per pair ----------------------------------
set.seed(cfgb$seed_base_v3b + ra$pair_seed_offset)
lo_p <- (1 - ra$interval) / 2
by_pair <- pairs |>
  mutate(diff_mean = NA_real_, diff_q_lo = NA_real_, diff_q_hi = NA_real_, excl0 = NA)
for (i in seq_len(nrow(by_pair))) {
  a <- draws[[as.character(by_pair$grid_id_low[i])]]
  b <- draws[[as.character(by_pair$grid_id_high[i])]]
  if (is.null(a) || is.null(b)) next
  n <- min(length(a), length(b))
  d <- sample(b, n) - sample(a, n)                 # high minus low; independent posteriors
  q <- stats::quantile(d, c(lo_p, 1 - lo_p), names = FALSE)
  by_pair$diff_mean[i] <- mean(d)
  by_pair$diff_q_lo[i] <- q[1]; by_pair$diff_q_hi[i] <- q[2]
  by_pair$excl0[i]     <- q[1] > 0 | q[2] < 0
}
by_pair <- by_pair |>
  mutate(primary   = status_low %in% ra$statuses_primary & status_high %in% ra$statuses_primary,
         pass_only = status_low == "pass" & status_high == "pass")
readr::write_csv(by_pair, file.path(out, "b_dprime_confound_by_pair.csv"))

# ---- Summaries ---------------------------------------------------------------
wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(ctr - hw, ctr + hw)
}
# Output columns are named mean_diff / mcse_diff (not diff_mean): inside summarise(),
# re-using an input column name would make later expressions see the summarised value.
summarise_fpr <- function(d, ...) d |>
  group_by(...) |>
  summarise(n = n(), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            prop_diff_neg = mean(diff_mean < 0),
            .groups = "drop")

prim <- filter(by_pair, primary, !is.na(excl0))
sens <- filter(by_pair, pass_only, !is.na(excl0))

by_cell <- bind_rows(
  summarise_fpr(prim, fit_variant, n_participants, n_trials) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant, n_participants, n_trials) |> mutate(analysis = "pass_only"))
pooled <- bind_rows(
  summarise_fpr(prim, fit_variant) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant) |> mutate(analysis = "pass_only"))
readr::write_csv(by_cell, file.path(out, "b_dprime_confound_by_cell.csv"))
readr::write_csv(pooled,  file.path(out, "b_dprime_confound_pooled.csv"))

# Paired on the same simulated datasets: which variant produced the false positive?
paired <- prim |>
  select(n_participants, n_trials, rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_pairs")
readr::write_csv(paired, file.path(out, "b_dprime_confound_paired.csv"))

# ---- Pre-specified framing rule (config/v3b.yml framing_rule) --------------
fr <- cfgb$framing_rule
cell_max_mis <- max(by_cell$fpr[by_cell$analysis == "primary" & by_cell$fit_variant == "misspecified"])
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_B <- cell_max_mis >= fr$cell_fpr_min || (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(c(sprintf("max cell FPR (misspecified) = %.3f", cell_max_mis),
             sprintf("pooled FPR misspecified = %.3f, correct = %.3f, excess = %.3f", p_mis, p_cor, p_mis - p_cor),
             sprintf("framing rule met in B: %s", verdict_B)),
           file.path(out, "b_framing_rule.txt"))

cat("\n=== Pooled ===\n"); print(as.data.frame(pooled), digits = 3)
cat("\n=== By cell (primary) ===\n"); print(as.data.frame(filter(by_cell, analysis == "primary")), digits = 3)
cat("\n=== Paired ===\n"); print(paired)
cat("\nframing rule met in B:", verdict_B, "\n")
```

### 2.3 執行與檢查

```bash
Rscript code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R
```

健全性檢查（依已知結果推估，不是要達成的目標）：

| 檢查 | 預期 | 若不符 |
|---|---|---|
| `status counts` | 480 個中只有少數 `fail`，沒有 `error` | 有 `error` 就先查是哪個檔案 |
| 每個擬合的 `n_draws` | 4000 | 若不是 4000，確認 `draws_b_sd` 是否被截短 |
| misspecified 的 `mean_diff` | 負值，大約 −0.10（因為 Δ_mis 在低 d′ 較大，高減低就是負的） | 正值代表配對方向寫反了 |
| correct 的 `mean_diff` | 接近 0，也可能有小幅系統偏差 | 不要因為不接近 0 就改程式；這正是要和 misspecified 比較的原因 |
| `fpr` 的大小 | 預期在 T = 400 的格子最高（後驗最窄、偏差仍在） | 若 T = 100 最高，先檢查 `interval` 是否讀成 0.5 |

### 2.4 理解檢查（寫進 analysis log）

1. 為什麼兩個格子的 draws 可以隨機配對相減？如果兩個擬合用的是**同一份**資料，這樣做還對嗎？
2. 為什麼「偽陽性率」要和正確模型比，而不是和 0.05 比？
3. 如果 misspecified 的 FPR 在 T = 400 最高，這和 v3 步驟 1 的「越來越有信心地錯」有什麼關係？

### 2.5 Commit

```bash
git add code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R data/processed/v3b/b_* docs/analysis_log.md
git commit -m "v3b B: false-positive rate for group differences under separate fits (stored G2 fits, no refitting)"
```

---

## 3. 工作包 C：兩組單一模型檢定（1 天 + 背景運算）

### 3.1 為什麼

B 用的是「兩組各自擬合」，審稿人會問：如果把兩組放進**同一個階層模型**，加上組別共變項（多數方法學論文推薦的做法），偽陽性還在嗎？C 回答這個問題：

- 資料：A 組 20 人、d′ = 0.75；B 組 20 人、d′ = 1.5；兩組 log M 都是 −1；資料由 Gumbel-min 產生。
- 模型：log M、d′、c 都加上 `group` 共變項；關鍵參數是 **`b_groupB`**（B 組減 A 組的 log M 差，真值 = 0）。
- 兩種擬合：`correct`（Gumbel-min）和 `misspecified`（高斯），同一份資料。

### 3.2 `code/01_simulate/simulate_v3b_two_group.R`

```r
# v3b work package C: two groups of participants that differ ONLY in d'
# (same true log_M), simulated from the gumbel_min generator used for G2.
# Group B participants get ids offset by the size of group A, so ids are unique.
# Requires code/01_simulate/simulate_g2_gumbel.R to be sourced first.

simulate_two_group_g2 <- function(n_per_group, n_trials, dprime_groups, log_M,
                                  k = 4, seed) {
  stopifnot(all(c("A", "B") %in% names(dprime_groups)))
  a <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["A"]], log_M, k = k, seed = seed)
  b <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["B"]], log_M, k = k,
                          seed = seed + 100000L)
  a$participant <- as.integer(a$participant)
  b$participant <- as.integer(b$participant) + max(a$participant)
  a$group <- "A"; b$group <- "B"
  out <- dplyr::bind_rows(a, b)
  out$group <- factor(out$group, levels = c("A", "B"))
  out
}
```

⚠️ **先確認**：`hmetad::sim_metad_participant()` 輸出的 `participant` 欄位型別。在 R console 執行：

```r
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
d <- simulate_g2_gumbel(3, 20, 1, -1, seed = 1); str(d$participant); head(d)
```

如果 `participant` 是 factor 而且 level 不是 1, 2, 3…，`as.integer()` 會變成 level 的編號，仍然唯一，所以沒問題；但請確認 `head(d)` 的欄位裡有 `stimulus`、`response`、`confidence`。

### 3.3 `tests/test_simulate_v3b_two_group.R`

```r
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))

test_that("two groups, unique participant ids, balanced sizes", {
  d <- simulate_two_group_g2(5, 40, c(A = 0.75, B = 1.5), log_M = -1, seed = 11)
  expect_setequal(levels(d$group), c("A", "B"))
  ids <- tapply(d$participant, d$group, function(x) sort(unique(x)))
  expect_length(intersect(ids$A, ids$B), 0)
  expect_equal(length(unique(d$participant)), 10)
})

test_that("the high-d' group is more accurate", {
  d <- simulate_two_group_g2(20, 200, c(A = 0.75, B = 1.5), log_M = -1, seed = 12)
  acc <- tapply(d$stimulus == d$response, d$group, mean)
  expect_gt(acc[["B"]], acc[["A"]])
})
```

### 3.4 `code/00_setup/04_create_grid_v3b.R`（C 和 D 共用）

```r
# v3b job table for work packages C (two_group) and D (g4). Run once.
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
b <- as.integer(cfgb$seed_base_v3b)

tg <- tidyr::expand_grid(rep_id = seq_len(cfgb$two_group$replications),
                         fit_variant = unlist(cfgb$two_group$fit_variants)) |>
  dplyr::mutate(study = "two_group", condition = "g2", dprime = NA_real_,
                sim_seed = b + 10000L + rep_id)            # same data for both variants

dps <- unlist(cfgb$g4$dprimes)
g4 <- tidyr::expand_grid(dprime = dps, condition = names(cfgb$g4$sigma_ratio),
                         rep_id = seq_len(cfgb$g4$replications),
                         fit_variant = unlist(cfgb$g4$fit_variants)) |>
  dplyr::mutate(study = "g4",
                # ev and uv share the seed within (d', rep): paired datasets (same stimuli,
                # same standard-normal draws, only the S2 SD differs)
                sim_seed = b + 20000L + match(dprime, dps) * 1000L + rep_id)

grid <- dplyr::bind_rows(tg, g4) |>
  dplyr::mutate(job_id = dplyr::row_number(), fit_seed = sim_seed + 1000000L) |>
  dplyr::select(job_id, study, condition, dprime, rep_id, fit_variant, sim_seed, fit_seed)

stopifnot(nrow(grid) == 2 * cfgb$two_group$replications +
                         length(dps) * 2 * cfgb$g4$replications * 2)   # 40 + 80
readr::write_csv(grid, here::here("config", "grid_v3b.csv"))
print(dplyr::count(grid, study, condition, fit_variant))
```

```bash
Rscript code/00_setup/04_create_grid_v3b.R
```

預期：two_group 40 列（job 1–40），g4 80 列（job 41–120）。

### 3.5 `code/02_fit/run_v3b_jobs.R`（C 和 D 共用的執行器）

這個腳本要等工作包 D 的 `simulate_g4_uv.R` 也寫好才能跑 D 的 job，但 C 的 job 可以先跑：腳本只在需要時才呼叫 G4 的模擬器。

```r
# v3b runner for work packages C (two_group) and D (g4). Resumable, shardable.
# Usage: Rscript code/02_fit/run_v3b_jobs.R <job_id>
#        Rscript code/02_fit/run_v3b_jobs.R --shard <s> <n>
# Fits use the v1 production settings (config/design.yml), matching G2.

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))
g4_file <- here::here("code", "01_simulate", "simulate_g4_uv.R")
if (file.exists(g4_file)) source(g4_file)
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
grid <- readr::read_csv(here::here("config", "grid_v3b.csv"), show_col_types = FALSE)
out_dir <- here::here("data", "interim", "v3b")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
ids <- if (length(args) >= 3 && args[1] == "--shard") {
  s <- as.integer(args[2]); n <- as.integer(args[3])
  grid$job_id[(grid$job_id - 1L) %% n == (s - 1L)]
} else as.integer(args[1])
stopifnot(length(ids) >= 1, all(ids %in% grid$job_id))

simulate_job <- function(row) {
  if (row$study == "two_group") {
    tg <- cfgb$two_group
    simulate_two_group_g2(tg$n_per_group, tg$n_trials, unlist(tg$dprime_groups),
                          log_M = cfg$truth$log_M, k = cfg$confidence$k, seed = row$sim_seed)
  } else if (row$study == "g4") {
    if (!exists("simulate_g4_uv")) stop("simulate_g4_uv.R not written yet (work package D)")
    g4 <- cfgb$g4
    simulate_g4_uv(g4$n_participants, g4$n_trials, dprime = row$dprime,
                   sigma_ratio = g4$sigma_ratio[[row$condition]], sigma_meta = g4$sigma_meta,
                   conf_thresholds = unlist(g4$conf_thresholds),
                   sd_threshold_jitter = g4$sd_threshold_jitter,
                   sd_criterion = g4$sd_criterion, seed = row$sim_seed)
  } else stop("unknown study: ", row$study)
}

fit_job <- function(row, data) {
  dist <- if (row$fit_variant %in% c("correct", "gumbel_min")) "gumbel_min" else "normal"
  two  <- row$study == "two_group"
  once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    agg_by = if (two) "group" else NULL,
    dprime_c_covariates = if (two) "group" else NULL,
    log_M_covariates = if (two) "group" else NULL,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
    extra_stanvars = if (dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row)
  a <- once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, row$fit_seed)
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth,
              row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  a
}

for (id in ids) {
  row <- as.list(grid[grid$job_id == id, ])
  out_path <- file.path(out_dir, sprintf("%s_%s_d%s_rep-%02d_%s_job-%03d.qs2",
                                         row$study, row$condition,
                                         ifelse(is.na(row$dprime), "NA", format(row$dprime)),
                                         row$rep_id, row$fit_variant, id))
  if (file.exists(out_path)) { cat("exists", id, "\n"); next }
  t0 <- Sys.time()
  rec <- tryCatch({
    data <- simulate_job(row)
    stopifnot(max(data$confidence) <= cfg$confidence$k)
    a <- fit_job(row, data)
    if (!is.null(a$fit)) {
      dr <- posterior::as_draws_df(a$fit)
      a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
      if (row$study == "g4") a$loo <- tryCatch(brms::loo(a$fit), error = function(e) NULL)
    }
    a$fit <- NULL                       # compact record only
    a
  }, error = function(e) list(status = "error", error_message = conditionMessage(e)))
  rec$job <- row
  qs2::qs_save(rec, out_path)
  cat(sprintf("job %3d %-9s %-3s %-12s rep %2d: %s (%.0f s)\n", id, row$study, row$condition,
              row$fit_variant, row$rep_id, rec$status,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
```

### 3.6 試跑（重要）

```bash
Rscript -e 'testthat::test_file("tests/test_simulate_v3b_two_group.R")'
Rscript code/02_fit/run_v3b_jobs.R 1     # two_group, rep 1, correct
Rscript code/02_fit/run_v3b_jobs.R 2     # two_group, rep 1, misspecified
```

在 R console 打開其中一個紀錄，**確認參數名稱**：

```r
r <- qs2::qs_read(list.files("data/interim/v3b", "job-001", full.names = TRUE))
r$status; grep("group", names(r$draws_b_sd), value = TRUE)
```

⚠️ **先確認**：預期會看到 `b_groupB`（log M 的組別效果）、`b_dprime_groupB`、`b_c_groupB`。如果名稱不同（例如 `b_groupB` 不存在），把 3.7 摘要腳本裡的 `"b_groupB"` 改成實際名稱，並記在 analysis log。

試跑成功後，開**一個**分片背景執行（C 的 40 個會先跑完，然後接著跑 D；D 的模擬器還沒寫好時，D 的 job 會以 `error` 結束並寫入紀錄）。

⚠️ 因為錯誤紀錄也會被當成「已完成」而跳過，所以**不要在 D 的模擬器寫好之前就讓分片跑到 job 41**。做法：先只跑 C 的 job。

```bash
# PowerShell: run jobs 3-40 sequentially in one terminal
for ($i = 3; $i -le 40; $i++) { Rscript code/02_fit/run_v3b_jobs.R $i }
```

### 3.7 `code/04_ppc_and_comparison/v3b_two_group_summary.R`

```r
# v3b work package C summary: false-positive rate for b_groupB (log_M difference,
# truth 0) when two groups differ only in d', fitted in ONE model.
suppressPackageStartupMessages(library(dplyr))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

files <- list.files(here::here("data", "interim", "v3b"), "^two_group_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == 2 * cfgb$two_group$replications)

param <- "b_groupB"   # CHECK against the trial fit (section 3.6)
by_fit <- purrr::map_dfr(files, function(f) {
  r <- qs2::qs_read(f); j <- r$job
  x <- if (!is.null(r$draws_b_sd) && param %in% names(r$draws_b_sd)) r$draws_b_sd[[param]] else NA_real_
  q <- stats::quantile(x, c(.025, .975), names = FALSE, na.rm = TRUE)
  tibble::tibble(job_id = j$job_id, rep_id = j$rep_id, fit_variant = j$fit_variant,
                 status = r$status, escalated = isTRUE(r$escalated),
                 diff_mean = mean(x), diff_q025 = q[1], diff_q975 = q[2],
                 excl0 = q[1] > 0 | q[2] < 0,
                 logM_groupA = if (is.null(r$draws_b_sd)) NA_real_ else mean(r$draws_b_sd$b_Intercept))
})
readr::write_csv(by_fit, file.path(out, "c_two_group_by_fit.csv"))

wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n; ctr <- (p + z^2 / (2 * n)) / den
  hw <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den; c(ctr - hw, ctr + hw)
}
summ <- function(d, label) d |>
  filter(!is.na(excl0)) |>
  group_by(fit_variant) |>
  summarise(n = n(), n_pass = sum(status == "pass"), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            .groups = "drop") |>
  mutate(analysis = label)
pooled <- bind_rows(summ(filter(by_fit, status %in% c("pass", "fail")), "primary"),
                    summ(filter(by_fit, status == "pass"), "pass_only"))
readr::write_csv(pooled, file.path(out, "c_two_group_summary.csv"))

paired <- by_fit |> filter(status %in% c("pass", "fail")) |>
  select(rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_reps")
readr::write_csv(paired, file.path(out, "c_two_group_paired.csv"))

fr <- cfgb$framing_rule
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_C <- (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(sprintf("C: FPR misspecified = %.3f, correct = %.3f, excess = %.3f; framing rule met in C: %s",
                   p_mis, p_cor, p_mis - p_cor, verdict_C),
           file.path(out, "c_framing_rule.txt"))
print(as.data.frame(pooled), digits = 3); print(paired)
cat("framing rule met in C:", verdict_C, "\n")
```

### 3.8 解讀（事先規定的寫法）

`framing_rule` 在 B **或** C 成立時：

| 結果 | 論文主軸的寫法 |
|---|---|
| 規則成立 | 「訊號分佈錯設造成的偏差會隨 d′ 改變，因此在 d′ 不同的組別之間會產生**假的 log M 差異**。」作為主要發現之一，放主圖 |
| 規則不成立 | 「偏差主要是各組共同的位移；組間比較大致穩健，但**絕對**的 log M 值（例如和 1 比、跨研究比較）會受影響。」也是有用的結論，放主圖但語氣保守 |

兩種結果**都要報告**，不能因為結果不明顯就刪掉。

### 3.9 理解檢查

1. `b_groupB` 的真值為什麼是 0？如果 C 的正確模型（Gumbel-min）偽陽性率也明顯高於 5%，可能是什麼原因？
2. 為什麼 d′ 和 c 也要放 `group` 共變項？如果只在 log M 放，會發生什麼？

### 3.10 Commit

```bash
git add code/01_simulate/simulate_v3b_two_group.R tests/test_simulate_v3b_two_group.R \
        code/00_setup/04_create_grid_v3b.R config/grid_v3b.csv code/02_fit/run_v3b_jobs.R \
        code/04_ppc_and_comparison/v3b_two_group_summary.R data/processed/v3b/c_* docs/analysis_log.md
git commit -m "v3b C: two-group single-model test of a spurious log_M difference (40 fits)"
```

（腳本寫好、試跑成功時可以先 commit 一次程式碼，結果出來後再 commit 一次結果。）

---

## 4. 工作包 D：不等變異數生成器 G4（1–1.5 天 + 背景運算）

### 4.1 為什麼和設計

如果實證資料偏好 Gumbel-min，審稿人一定會問：「這會不會只是因為訊號的變異數不相等？」Gumbel-min 和不等變異數高斯（UV）都會讓 ROC 不對稱。D 只回答一個問題：**UV 資料會不會讓 LOO 偏好 Gumbel-min？**

設計：
- 生成器：S1 的證據 ~ N(−d′/2, 1)，S2 的證據 ~ N(+d′/2, σ)。EV 對照組 σ = 1，UV 組 σ = 1.25。
- 回應：證據 > 該受試者的標準 c_j 時回答 1。
- 信心：在證據上再加一個雜訊 ε ~ N(0, σ_meta)，用「往所選方向離標準多遠」來分 4 級。這讓後設認知不完美，比較接近真實資料。
- **配對**：同一個 (d′, rep) 下 EV 和 UV 用同一個種子，所以刺激、標準和所有標準常態亂數都一樣，只差 S2 的 SD。兩組的差異幾乎全部來自變異數，Monte Carlo 雜訊很小。
- 每份資料擬合兩次：高斯和 Gumbel-min。2 個 d′ × 2 條件 × 10 次 × 2 種擬合 = 80 個擬合。

D 回報的結果：
1. LOO 偏好 Gumbel-min（> 2 SE）的比例：UV 對 EV，套用事先規定的 `mimicry_rule`。
2. UV 造成的 log M 位移：同一配對下，高斯擬合的 log M(UV) − log M(EV)。
3. 家族差：log M(normal) − log M(gumbel)，在 EV 和 UV 下各是多少。

### 4.2 `code/01_simulate/simulate_g4_uv.R`

```r
# G4 (v3b work package D): Gaussian signal detection with UNEQUAL variance plus
# Gaussian metacognitive noise, generated outside hmetad. This is NOT the meta-d'
# generative model, so it has no "true log_M"; G4 is analysed only as a paired
# contrast between ev (sigma_ratio = 1) and uv (sigma_ratio != 1) datasets that
# share a seed. "dprime" = mean separation in units of the stimulus-0 SD.
#
# Trial: stimulus s in {0, 1} (exactly n_trials/2 each, shuffled);
#   x ~ N(-d/2, 1) if s = 0, N(+d/2, sigma_ratio) if s = 1   (drawn as mu + sd * z)
#   response = 1 if x > c_j
#   y = x + N(0, sigma_meta);  dist = (y - c_j) * (2 * response - 1)
#   confidence = 1 + number of thresholds below dist  (dist < first threshold -> 1)

simulate_g4_uv <- function(n_participants, n_trials, dprime, sigma_ratio, sigma_meta,
                           conf_thresholds, sd_threshold_jitter = 0.1,
                           sd_criterion = 0.2, seed) {
  stopifnot(n_trials %% 2 == 0, sigma_ratio > 0, sigma_meta >= 0,
            !is.unsorted(conf_thresholds))
  withr::with_seed(seed, {
    purrr::map_dfr(seq_len(n_participants), function(j) {
      stim <- sample(rep(0:1, each = n_trials / 2))
      z_x  <- stats::rnorm(n_trials)                       # common random numbers:
      z_m  <- stats::rnorm(n_trials)                       # identical across sigma_ratio
      c_j  <- stats::rnorm(1, 0, sd_criterion)
      thr  <- sort(conf_thresholds + stats::rnorm(length(conf_thresholds), 0, sd_threshold_jitter))
      mu   <- ifelse(stim == 1, dprime / 2, -dprime / 2)
      sdv  <- ifelse(stim == 1, sigma_ratio, 1)
      x    <- mu + sdv * z_x
      resp <- as.integer(x > c_j)
      y    <- x + sigma_meta * z_m
      dist <- (y - c_j) * (2 * resp - 1)
      conf <- 1L + findInterval(dist, thr)
      tibble::tibble(participant = j, trial = seq_len(n_trials), stimulus = as.integer(stim),
                     response = resp, confidence = as.integer(conf),
                     correct = as.integer(stim == resp))
    })
  })
}

# Slope of the type-1 zROC built from the 2K-point rating scale (response x confidence).
# Used by the tests: with sigma_meta = 0 the slope is exactly 1 / sigma_ratio.
zroc_slope <- function(d, K) {
  rating <- ifelse(d$response == 1, K + d$confidence, K + 1L - d$confidence)
  cuts <- 2:(2 * K)
  hr  <- vapply(cuts, function(k) mean(rating[d$stimulus == 1] >= k), numeric(1))
  far <- vapply(cuts, function(k) mean(rating[d$stimulus == 0] >= k), numeric(1))
  ok  <- hr > 0 & hr < 1 & far > 0 & far < 1
  unname(stats::coef(stats::lm(stats::qnorm(hr[ok]) ~ stats::qnorm(far[ok])))[2])
}
```

**為什麼要分開抽 `z_x` 和 `z_m`**：這樣 EV 和 UV 在同一個種子下用的是完全相同的亂數，只是 S2 的證據乘上不同的 SD。如果改成 `rnorm(n, mu, sd)` 交錯抽取，兩組還是會配對，但寫成標準常態乘以 SD 比較清楚，也比較容易檢查。

### 4.3 `tests/test_simulate_g4_uv.R`

```r
source(here::here("code", "01_simulate", "simulate_g4_uv.R"))
thr <- c(0.5, 1.0, 1.5)

test_that("coding, balance and K", {
  d <- simulate_g4_uv(5, 100, 1, 1, 1, thr, seed = 1)
  expect_true(all(d$stimulus %in% 0:1))
  expect_true(all(d$response %in% 0:1))
  expect_true(all(d$confidence %in% 1:4))
  expect_equal(as.vector(table(d$participant, d$stimulus)), rep(50L, 10))
})

test_that("zROC slope equals 1 / sigma_ratio without metacognitive noise", {
  for (s in c(1, 1.25)) {
    d <- simulate_g4_uv(1, 200000, 1.5, s, 0, thr, sd_threshold_jitter = 0,
                        sd_criterion = 0, seed = 2)
    expect_equal(zroc_slope(d, 4), 1 / s, tolerance = 0.03)
  }
})

test_that("ev and uv with the same seed are paired", {
  e <- simulate_g4_uv(3, 100, 1, 1.00, 1, thr, seed = 3)
  u <- simulate_g4_uv(3, 100, 1, 1.25, 1, thr, seed = 3)
  expect_identical(e$stimulus, u$stimulus)
  expect_identical(e$response[e$stimulus == 0], u$response[u$stimulus == 0])  # S1 trials identical
  expect_gt(mean(e$response == u$response), 0.9)
})

test_that("every confidence level is used at production settings", {
  for (dp in c(0.75, 1.5)) for (s in c(1, 1.25)) {
    d <- simulate_g4_uv(40, 200, dp, s, 1, thr, seed = 4)
    expect_true(all(prop.table(table(factor(d$confidence, levels = 1:4))) > 0.05))
  }
})

test_that("accuracy rises with d'", {
  lo <- mean(simulate_g4_uv(40, 200, 0.75, 1, 1, thr, seed = 5)$correct)
  hi <- mean(simulate_g4_uv(40, 200, 1.50, 1, 1, thr, seed = 5)$correct)
  expect_gt(hi, lo)
})
```

```bash
Rscript -e 'testthat::test_file("tests/test_simulate_g4_uv.R")'
```

**如果「每個信心等級都 > 5%」的測試失敗**：代表 `conf_thresholds` 對這個證據尺度不合適。只能在**送出任何 G4 擬合之前**調整 `config/v3b.yml` 的 `conf_thresholds`，記進 analysis log，commit 之後再跑。這屬於生成器校準，不是看結果後的修改，但仍然要記錄。

另外做一次目視檢查（不進測試）：

```r
d_ev <- simulate_g4_uv(40, 200, 1.5, 1.00, 1, c(.5, 1, 1.5), seed = 9)
d_uv <- simulate_g4_uv(40, 200, 1.5, 1.25, 1, c(.5, 1, 1.5), seed = 9)
c(ev = zroc_slope(d_ev, 4), uv = zroc_slope(d_uv, 4))   # 預期 uv < ev
prop.table(table(d_uv$confidence))
```

### 4.4 執行

C 的 40 個 job 跑完（或至少確認 job 1–2 正常）之後：

```bash
Rscript code/02_fit/run_v3b_jobs.R 41      # g4, d' 0.75, ev, rep 1, normal
Rscript code/02_fit/run_v3b_jobs.R 42      # 同一份資料, gumbel_min
```

確認兩個紀錄的 `status` 和 `loo`（不是 NULL）：

```r
r <- qs2::qs_read(list.files("data/interim/v3b", "job-041", full.names = TRUE)); r$status; class(r$loo)
```

沒問題的話依序跑完：

```powershell
for ($i = 43; $i -le 120; $i++) { Rscript code/02_fit/run_v3b_jobs.R $i }
```

### 4.5 `code/04_ppc_and_comparison/v3b_g4_summary.R`

```r
# v3b work package D summary: does unequal-variance evidence make LOO prefer gumbel_min?
suppressPackageStartupMessages(library(dplyr))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml")); g4 <- cfgb$g4
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

files <- list.files(here::here("data", "interim", "v3b"), "^g4_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == length(unlist(g4$dprimes)) * 2 * g4$replications * 2)
recs <- lapply(files, qs2::qs_read)

by_fit <- purrr::map_dfr(recs, function(r) {
  j <- r$job
  x <- if (is.null(r$draws_b_sd)) NA_real_ else r$draws_b_sd$b_Intercept
  tibble::tibble(job_id = j$job_id, dprime = j$dprime, condition = j$condition,
                 rep_id = j$rep_id, fit_variant = j$fit_variant, status = r$status,
                 logM_mean = mean(x), has_loo = !is.null(r$loo))
})
readr::write_csv(by_fit, file.path(out, "d_g4_by_fit.csv"))
loo_of <- setNames(lapply(recs, `[[`, "loo"), vapply(recs, function(r) as.numeric(r$job$job_id), numeric(1)))

# elpd(normal) - elpd(gumbel_min): > 0 favours Gaussian (v3 sign convention)
cmp_family <- function(id_n, id_g) {
  a <- loo_of[[as.character(id_n)]]; b <- loo_of[[as.character(id_g)]]
  if (is.null(a) || is.null(b)) return(c(diff = NA_real_, se = NA_real_))
  cmp <- loo::loo_compare(list(normal = a, gumbel = b))
  c(diff = cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"], se = max(cmp[, "se_diff"]))
}

pairs <- by_fit |>
  select(dprime, condition, rep_id, fit_variant, job_id, status, logM_mean) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = c(job_id, status, logM_mean))
res <- t(mapply(cmp_family, pairs$job_id_normal, pairs$job_id_gumbel_min))
pairs <- pairs |>
  mutate(elpd_diff = res[, "diff"], se = res[, "se"],
         favors_gumbel_2se = elpd_diff < -g4$mimicry_rule$two_se * se,
         favors_normal_2se = elpd_diff >  g4$mimicry_rule$two_se * se,
         family_gap = logM_mean_normal - logM_mean_gumbel_min,
         both_ok = status_normal %in% c("pass", "fail") & status_gumbel_min %in% c("pass", "fail"))
readr::write_csv(pairs, file.path(out, "d_g4_by_dataset.csv"))

rates <- pairs |> filter(both_ok, !is.na(elpd_diff)) |>
  group_by(condition, dprime) |>
  summarise(n = n(), prop_gumbel_2se = mean(favors_gumbel_2se),
            prop_normal_2se = mean(favors_normal_2se),
            median_elpd_diff = median(elpd_diff),
            mean_family_gap = mean(family_gap), .groups = "drop")
rates_pooled <- pairs |> filter(both_ok, !is.na(elpd_diff)) |>
  group_by(condition) |>
  summarise(n = n(), prop_gumbel_2se = mean(favors_gumbel_2se),
            prop_normal_2se = mean(favors_normal_2se),
            median_elpd_diff = median(elpd_diff), .groups = "drop")
readr::write_csv(rates, file.path(out, "d_g4_rates_by_dprime.csv"))
readr::write_csv(rates_pooled, file.path(out, "d_g4_rates_pooled.csv"))

# UV-induced shift in the Gaussian fit's log_M, paired on (d', rep)
shift <- pairs |>
  select(dprime, rep_id, condition, logM_mean_normal) |>
  tidyr::pivot_wider(names_from = condition, values_from = logM_mean_normal) |>
  mutate(uv_shift = uv - ev) |>
  group_by(dprime) |>
  summarise(n = n(), mean_uv_shift = mean(uv_shift), mcse = sd(uv_shift) / sqrt(n()),
            .groups = "drop")
readr::write_csv(shift, file.path(out, "d_g4_uv_shift.csv"))

mr <- g4$mimicry_rule
p_uv <- rates_pooled$prop_gumbel_2se[rates_pooled$condition == "uv"]
p_ev <- rates_pooled$prop_gumbel_2se[rates_pooled$condition == "ev"]
verdict <- if (p_uv >= mr$uv_min_prop && p_ev <= mr$ev_max_prop) "UV mimics gumbel_min" else
           "no UV mimicry by the pre-specified rule"
writeLines(c(verdict, sprintf("uv prop favours gumbel (>2SE) = %.3f; ev = %.3f", p_uv, p_ev)),
           file.path(out, "d_g4_verdict.txt"))
print(as.data.frame(rates), digits = 3); print(as.data.frame(shift), digits = 3)
cat("\nG4 verdict:", verdict, "\n")
```

### 4.6 解讀（事先規定）

| G4 結果 | 對實證結果的解讀 |
|---|---|
| **UV 會模仿 Gumbel-min** | 實證資料偏好 Gumbel-min 時，只能寫成「證據分佈**不對稱或變異數不相等**」，**不能**寫成「Gumbel-min 特別適合」 |
| **UV 不會模仿** | 實證資料偏好 Gumbel-min 時，可以寫「偏好不是由這種程度的不等變異數造成」，但仍要說明只測了一個變異數比 |
| EV 對照組本身就常偏好 Gumbel-min（> 10%） | 代表這個生成器（加了後設認知雜訊）本身就偏離兩個模型；照實報告，並在 limitations 說明 |

### 4.7 理解檢查

1. 為什麼 G4 沒有「log M 真值」？為什麼用 EV 對照組就能回答我們要的問題？
2. 為什麼 σ_meta = 0 時 zROC 斜率剛好是 1/σ？σ_meta > 0 時為什麼不是？
3. 如果 UV 讓高斯擬合的 log M 往上移，這和 G2 的 Δ_mis 方向一致嗎？代表什麼？

### 4.8 Commit

```bash
git add code/01_simulate/simulate_g4_uv.R tests/test_simulate_g4_uv.R \
        code/04_ppc_and_comparison/v3b_g4_summary.R data/processed/v3b/d_* docs/analysis_log.md
git commit -m "v3b D: unequal-variance generator (G4) and pre-specified mimicry verdict (80 fits)"
```

---

## 5. 工作包 E：圖

主圖預算最多 5 張（見 7.5）。B + C 的結果是主圖候選，D 放補充材料。沿用 `fig_6_relative_bias.R` 的主題和 Okabe–Ito 色票。

### 5.1 `code/05_figures/fig_10_dprime_confound.R`

```r
# Fig. 10 (v3b): spurious log_M group differences when groups differ only in d'.
# A: false-positive rate by N x T, separate fits (work package B), correct vs Gaussian.
# B: posterior mean of the group difference, single two-group model (work package C).
suppressPackageStartupMessages({ library(dplyr); library(ggplot2); library(patchwork) })
okabe_v <- c(correct = "#009E73", misspecified = "#D55E00")
lab_v   <- c(correct = "Correct (Gumbel-min)", misspecified = "Gaussian (misspecified)")

b <- readr::read_csv(here::here("data", "processed", "v3b", "b_dprime_confound_by_cell.csv"),
                     show_col_types = FALSE) |> filter(analysis == "primary")
pA <- ggplot(b, aes(n_trials, fpr, colour = fit_variant, shape = factor(n_participants))) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = fpr_lo, ymax = fpr_hi), position = position_dodge(width = 0.2)) +
  scale_x_continuous(trans = "log2", breaks = c(100, 200, 400)) +
  scale_colour_manual(values = okabe_v, labels = lab_v) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(subtitle = "A. Separate fits per group: 95% CrI of the difference excludes 0",
       x = "Trials per participant (log scale)", y = "False-positive rate (Wilson 95% CI)",
       colour = NULL, shape = "N per group") +
  theme_minimal() + theme(legend.position = "top")

c2 <- readr::read_csv(here::here("data", "processed", "v3b", "c_two_group_by_fit.csv"),
                      show_col_types = FALSE) |> filter(status %in% c("pass", "fail"))
pB <- ggplot(c2, aes(fit_variant, diff_mean, colour = fit_variant)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = diff_q025, ymax = diff_q975, alpha = excl0),
                  position = position_jitter(width = 0.25, seed = 1)) +
  scale_alpha_manual(values = c(`FALSE` = 0.35, `TRUE` = 1), name = "CrI excludes 0") +
  scale_colour_manual(values = okabe_v, labels = lab_v, guide = "none") +
  scale_x_discrete(labels = lab_v) +
  labs(subtitle = "B. One model with a group effect (N = 20 + 20, T = 200)",
       x = NULL, y = "log M (high d') - log M (low d'); truth = 0") +
  theme_minimal() + theme(legend.position = "top")

dir.create(here::here("outputs", "figures", "v3b"), recursive = TRUE, showWarnings = FALSE)
ggsave(here::here("outputs", "figures", "v3b", "fig_10_dprime_confound.png"),
       pA + pB + plot_layout(widths = c(1.4, 1)), width = 11, height = 4.5, dpi = 300)
```

### 5.2 `code/05_figures/fig_S_g4_uv.R`

```r
# Fig. S (v3b): G4 unequal-variance check. elpd(normal) - elpd(gumbel_min) per dataset,
# ev vs uv, by d'. Reference lines at 0; points coloured by > 2 SE preference.
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
d <- readr::read_csv(here::here("data", "processed", "v3b", "d_g4_by_dataset.csv"),
                     show_col_types = FALSE) |> filter(both_ok) |>
  mutate(pref = case_when(favors_gumbel_2se ~ "Gumbel-min > 2 SE",
                          favors_normal_2se ~ "Gaussian > 2 SE", TRUE ~ "Inconclusive"))
p <- ggplot(d, aes(condition, elpd_diff, colour = pref)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = elpd_diff - 2 * se, ymax = elpd_diff + 2 * se),
                  position = position_jitter(width = 0.2, seed = 1)) +
  facet_wrap(~ dprime, labeller = label_both) +
  scale_colour_manual(values = c("Gumbel-min > 2 SE" = "#D55E00", "Gaussian > 2 SE" = "#0072B2",
                                 "Inconclusive" = "grey60")) +
  scale_x_discrete(labels = c(ev = "Equal variance", uv = "Unequal (SD ratio 1.25)")) +
  labs(x = NULL, y = "elpd(Gaussian) - elpd(Gumbel-min)  (+/- 2 SE)", colour = NULL) +
  theme_minimal() + theme(legend.position = "top")
ggsave(here::here("outputs", "figures", "v3b", "fig_S_g4_uv.png"), p, width = 8, height = 4.5, dpi = 300)
```

```bash
Rscript code/05_figures/fig_10_dprime_confound.R
Rscript code/05_figures/fig_S_g4_uv.R
git add code/05_figures/fig_10_dprime_confound.R code/05_figures/fig_S_g4_uv.R outputs/figures/v3b
git commit -m "v3b figures: Fig. 10 (d' confound) and Fig. S (G4 unequal variance)"
```

### 5.3 Makefile 和 `run_v3.R`

在 `Makefile` 最後加上：

```make
.PHONY: v3b-reanalysis v3b-fits v3b-summary v3b-figures

v3b-reanalysis:
	$(RSCRIPT) code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R

v3b-fits:     # 120 fits (40 two-group + 80 G4), single process
	$(RSCRIPT) code/00_setup/04_create_grid_v3b.R
	$(RSCRIPT) code/02_fit/run_v3b_jobs.R --shard 1 1

v3b-summary:
	$(RSCRIPT) code/04_ppc_and_comparison/v3b_two_group_summary.R
	$(RSCRIPT) code/04_ppc_and_comparison/v3b_g4_summary.R

v3b-figures:
	$(RSCRIPT) code/05_figures/fig_10_dprime_confound.R
	$(RSCRIPT) code/05_figures/fig_S_g4_uv.R
```

在 `code/run_v3.R` 不需重擬合的步驟清單裡，加上 `v3b_dprime_confound_reanalysis.R`、兩個 summary 和兩個圖的腳本，順序同上。

---

## 6. 工作包 F：實證分析收尾

這部分的程式碼都已經存在（`docs/v3_plan.md` §5.8–5.10），這裡只列順序和檢查點。

### 6.1 擬合完成後的步驟

```bash
# 1. 確認 90 個擬合都在
Rscript -e 'length(list.files("data/interim/v3_empirical/fits", "[.]qs2$"))'   # 90
# 2. LOO 修補（reloo 或分組 K-fold，依事先規定的比例）
Rscript code/06_empirical/05_loo_repair.R
# 3. PPC
Rscript code/06_empirical/06_ppc_dataset.R
# 4. 彙整：主要分類 + 事先規定的探索性分析 + SD 先驗檢查
Rscript code/06_empirical/07_summarise_empirical.R
# 5. 圖 9
Rscript code/05_figures/fig_9_empirical.R
```

### 6.2 檢查點

| 檢查 | 位置 | 若不符 |
|---|---|---|
| 每個資料集的兩個家族都用同一種 LOO 修補方法 | `05_loo_repair.R` 的輸出 `method` | 程式已保證；若不一致，先查 `prop_bad` |
| `exploratory_*.csv` 四個檔都產生了 | `data/processed/v3/empirical/` | 確認 `07_summarise_empirical.R` 沒有在中途停止 |
| `flag_sd_prior` 欄位存在 | `empirical_by_dataset.csv` | 照 `config/v3.yml` 的 `sd_prior_check` |
| 類別比例 | `empirical_category_summary.csv` | **照實報告**，不因結果改規則 |

### 6.3 用 v3b 的結果解讀實證（事先規定）

| 實證結果 | G4 有模仿 | G4 沒有模仿 |
|---|---|---|
| 多數偏好 Gumbel-min | 「證據分佈不對稱或變異數不等」 | 「偏好不是由這種程度的不等變異數造成」 |
| 多數偏好高斯 | 「在這些資料中高斯假設大致適當」 | 同左 |
| 多數不明確 | 「在常見資料量下，分佈假設難以辨識；但模擬顯示偏差仍存在」 | 同左 |

再加上 B/C 的結論：若實證中**有條件差異**的資料集裡，兩個家族的條件對比結論翻轉（`conclusion_flip`），就是 B/C 在真實資料中的例證；沒有翻轉也照實報告。

### 6.4 Commit

```bash
git add data/processed/v3/empirical outputs/figures/v3 docs/analysis_log.md
git commit -m "v3 empirical: LOO repair, PPC, pre-specified summary and exploratory tables; Fig. 9"
```

---

## 7. 工作包 G：寫作

### 7.1 `docs/positioning.md`（半天）

三段，總長 ≤ 1 頁：

1. **他們做了什麼**：
   - Rausch, Hellmann & Zehetleitner（*Psychological Methods*）：改變信心機制，訊號都是高斯。**卷期和 DOI 要自己核對。**
   - Meyer-Grant, Kellen, Harding & Singmann（*Psychological Review*）：在再認記憶的信心 ROC 上比較 Gumbel-min 和高斯，樣本外預測多半偏好 Gumbel-min。
   - Rahnev（2025, *Nature Communications*）：用實證資料評估 17 種指標，全部假設等變異數高斯。
   - `hmetad` 的 alternative distributions vignette：只示範正確設定下的參數回復。
2. **本研究補上什麼**：在 meta-d′ type-2 框架和階層模型中，量化分佈錯設對 log M 的影響（包括隨 d′ 改變的偏差和由此產生的假組間差異）、它能不能被偵測、它和不等變異數的關係，以及在知覺信心資料中的實證關聯。
3. **本研究不主張什麼**：meta-d′ 無效；第一個發現 meta-d′ 依賴假設；Gumbel-min 是人類證據的真實分佈；log M 測量的是 σ_c。

「第一個」一律改成「據我們所知」。

### 7.2 效果量基準（半天，**最多 3 篇**）

目的：把 Δ_mis（約 0.1–0.25 log 單位）和 B/C 的組間差異，放在實際研究的尺度上比較。

做法：
1. 從你已知的文獻裡挑 2–3 篇有報告**組間或條件間 M-ratio（或 log M-ratio）差異**的研究。可以優先找 Confidence Database 相關論文，或用 HMeta-d 分析臨床族群的研究。
2. 每篇記下：族群或條件、M-ratio 的組平均、差異值、是否在 log 尺度。換算方式：log M 差 = log(M₁) − log(M₂)。
3. 做成一個小表放進 Discussion：「Δ_mis 約等於這些研究報告的組間差異的 X%」。

**規則**：只用你自己從原文讀到的數字。我沒有替你查這些數值，所以文件裡沒有放任何數字，不要從二手來源抄。

### 7.3 不等變異數的討論段落（含 G4 結果）

結構（約 200 字）：
1. 不等變異數高斯是知覺和記憶研究中最常見的違反（zROC 斜率 ≠ 1）。
2. Gumbel-min 也會產生不對稱的 ROC，兩者可能互相模仿。
3. G4 的結果：UV（SD 比 1.25）是否讓 LOO 偏好 Gumbel-min，以及它對高斯擬合 log M 的位移（引用 `d_g4_*` 的數字）。
4. 限制：只測一個 SD 比；只有一種生成器（加了後設認知雜訊的 SDT）。

### 7.4 和 Meyer-Grant et al. 的對照（一段）

只做質性比較：你的**記憶**資料集（次要分析）偏好的方向，和他們的結果一致嗎？不逐一比對資料集（已寫進 `deferred.md`）。

### 7.5 改寫論文

結構沿用 `docs/enhancement_plan_v2.md` 的 Stage 4，更新如下：

**主要結果順序**
1. 健全性檢查（G0 校準，簡短；G1 移到補充材料）
2. 錯設的後果：Δ_mis、隨 d′ 改變、不隨資料量消失、覆蓋率
3. **假的組間差異**（B + C）
4. 可偵測性：LOO（修補後）、最高信心格的 PPC
5. 替代解釋：G3（難度混合）、G4（不等變異數）
6. 實證：類別比例、log M 和條件對比的改變、SD 先驗檢查、探索性的診斷表

**主圖（最多 5 張）**

| # | 內容 | 來源 |
|---|---|---|
| 1 | 設計總覽（更新 `fig_1_design.R`，加入 G3、G4、兩組設計） | — |
| 2 | Δ_mis 和覆蓋率 | 圖 6 |
| 3 | 假的組間差異 | 圖 10 |
| 4 | 可偵測性：LOO 修補前後 + 目標式 PPC | 圖 7 + v1.2 的 PPC 圖 |
| 5 | 實證結果 | 圖 9 |

補充材料：G1、G3（圖 8）、G4（圖 S）、v1 的圖 5–7、所有探索性表格。

**Methods 要明確寫出的事**
- 每個事先規定的 tag 和 commit（`v3-prereg-g3`、`v3-prereg-empirical`、`v3b-prereg`），以及每一次偏離（取樣設定、受試者上限 100、SD 先驗），附上 commit hash。
- 實證的 LOO 單位是「受試者 × 條件」的聚合計數。
- 已知限制：一種錯設家族加一個 UV 比、一個 log M 真值、K = 4、只用 `hmetad`/brms。

**寫作規則**：「與……相關」、「與……一致」；每個數字都能追溯到 `data/processed/` 的某個 CSV；**摘要最後寫**，從數字寫起（五步：問題 → 設計 → 後果 → 可偵測性 → 實證）。

---

## 8. 工作包 H：投稿前清單與發佈

### 8.1 投稿必備項目

- [ ] 資料與程式碼可得性聲明（GitHub + Zenodo DOI；原始資料不附，附下載說明和 `raw_manifest.csv`）
- [ ] 事先規定的聲明：tag、commit、偏離清單，並說明這不是正式的預先註冊（沒有第三方時間戳記）
- [ ] Confidence Database 的授權和引用：資料庫論文（Rahnev et al., 2020）＋**每個用到的資料集的原始論文**
- [ ] 二手資料的倫理聲明（公開、去識別化的資料；依期刊要求寫）
- [ ] CRediT 作者貢獻、利益衝突、經費聲明
- [ ] **AI 使用聲明**（依期刊政策，寫明哪些部分用了 AI 協助）
- [ ] `README.md`：v2.0 狀態、重現指令（`make v3b-*` 等）、新圖、資料取得方式
- [ ] `CITATION.cff` 改成 2.0.0；`docs/deliverables_checklist.md` 更新
- [ ] 期刊格式、字數、圖數限制；投稿信；推薦審稿人（避開利益衝突）
- [ ] 全部測試通過：`Rscript -e 'testthat::test_dir("tests")'`
- [ ] 從乾淨的 clone 重跑不需擬合的步驟（`code/run_downstream.R`、`code/run_v3.R`），確認數字一致

### 8.2 真人閱讀（最容易跳過，價值最高）

- 找 1–2 位讀者：導師、實驗室同事，或做後設認知、計算建模的人。
- 請他們回答三個問題：
  1. 貢獻相對於 Rausch et al. 和 Meyer-Grant et al. 清楚嗎？
  2. 有沒有說過頭的地方？
  3. 哪一個結果最有說服力？哪一個最弱？
- 給他們 1–2 週。他們的意見只用來**改寫**，不用來新增分析（除非指出明確的錯誤）。

### 8.3 發佈和投稿

```bash
git checkout main
git merge --no-ff v3-enhancement
git tag v2.0.0
git push origin main --tags
```

1. 透過 Zenodo–GitHub 整合取得 v2.0.0 的 DOI。
2. 上傳 PsyArXiv，連結 GitHub 和 DOI。
3. 讀 2–3 本候選期刊的 aims & scope 和預印本政策（建議順序：*Behavior Research Methods* → *Computational Brain & Behavior* → *Meta-Psychology* 或 *Neuroscience of Consciousness*），選一本投稿。
4. 投稿後才把 CV 改成「Preprint (under review)」。

---

## 附錄 A：常見錯誤排除

| 症狀 | 可能原因 | 處理 |
|---|---|---|
| `could not find function "gumbel_min_lcdf"` | 沒有 source `simulate_g2_gumbel.R` | `run_v3b_jobs.R` 第一行已經 source；自己寫的測試腳本也要加 |
| `fit_one_hmetad: every covariate must also be listed in agg_by` | C 的 `agg_by` 沒有設成 `"group"` | 檢查 `fit_job()` 的 `two` 判斷 |
| 找不到 `b_groupB` | 因子 level 名稱不同 | 照 3.6 的方法看實際名稱，改摘要腳本並記錄 |
| `priors do not correspond to any model parameter` | 有設 `log_M_b_prior` 但公式裡沒有 log M 共變項 | 只有 two_group 會傳 `log_M_covariates`；預設值已處理 |
| G4 的 job 狀態是 `error`，訊息提到 `simulate_g4_uv.R not written yet` | 在 D 的模擬器寫好之前就跑到 job 41 以後 | 刪除那些 `g4_*` 的錯誤紀錄後重跑（只刪 `status == "error"` 的） |
| `confidence must be coded 1:K` | G4 的閾值數和 `design.yml` 的 K 不一致 | `conf_thresholds` 必須是 3 個值（K = 4） |
| 測試 zROC 斜率失敗 | 試次不夠或閾值落在極端 | 用 200000 個試次；確認 `sd_threshold_jitter = 0`、`sd_criterion = 0` |
| 加上 v3b 分片後實證擬合明顯變慢 | CPU 爭用 | 正常；必要時先暫停 v3b 的迴圈（Ctrl+C，已完成的不會重跑） |
| `pivot_wider` 產生 list 欄位 | 某個 key 組合重複 | `count(..., fit_variant) |> filter(n > 1)` 找出重複並記錄 |

## 附錄 B：決定點總表

| 位置 | 條件 | 成立 | 不成立 |
|---|---|---|---|
| 1.5 | `v3b-prereg` 已 tag 並 push | 開始 B | 先完成 |
| 2.3 | B 的健全性檢查符合 | 進入 C | 先查配對方向和檔名 |
| 3.6 | C 的試跑有 `b_groupB` | 跑完 40 個 | 改參數名稱並記錄 |
| 3.8 | `framing_rule` 在 B 或 C 成立 | 主軸：「假的組間差異」 | 主軸：「共同位移，絕對值受影響」（兩者都報告） |
| 4.3 | G4 測試全部通過 | 送出 80 個擬合 | 只能調整 `conf_thresholds`，記錄後再 commit |
| 4.6 | `mimicry_rule` 成立 | 實證偏好 Gumbel 時寫成「不對稱或變異數不等」 | 寫「不是由這種程度的 UV 造成」 |
| 6.2 | 實證類別比例 | **照實報告** | 不因結果改規則 |
| 8.2 | 真人讀者指出明確錯誤 | 修正 | 其他意見只用來改寫 |

## 附錄 C：時間表

以「工作天」計算，運算在背景進行；實證擬合大約還要 2–3 天。

| 天 | 前景工作 | 背景運算 |
|---|---|---|
| 1 | A（設定、tag）＋ B（再分析） | 實證擬合 |
| 2 | C 的程式、測試、試跑 → 送出 C | 實證 + C（2–5 h） |
| 3 | D 的模擬器、測試、試跑 → 送出 D；C 的摘要 | 實證 + D（4–10 h） |
| 4 | D 的摘要；圖 10、圖 S；`positioning.md` | 實證（應接近完成） |
| 5 | 效果量基準、UV 討論、Meyer-Grant 段落 | — |
| 6 | 實證收尾（F） | LOO 修補（reloo/K-fold，數小時） |
| 7–10 | 改寫論文（G 的 7.5） | — |
| 11 | 投稿清單（H 的 8.1）→ 送給真人讀者 | — |
| 等待 1–2 週 | — | — |
| 之後 1–2 天 | 依意見改寫 → v2.0.0 → DOI → 預印本 → 投稿 | — |

**凍結點**在第 6 天結束：這之後只寫作，不再新增分析。
