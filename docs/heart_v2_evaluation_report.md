# Heart Disease Risk Prediction v2 — Scientific Evaluation & External Validation Report

> Educational / research evaluation generated directly from `scripts/evaluate_heart.py`. Not a clinical diagnostic device.

## 1. Training Hyperparameter Selection (Cleveland `X_train`, N=242)

Hyperparameter regularization `C` was selected strictly inside the stratified 80% training split (`N=242`, `random_state=42`) using 5-fold stratified CV (`ROC-AUC`) over `C in [0.01, 0.1, 1.0, 10.0]` before any evaluation on `X_test` (`N=61`):

| Mode | Input Features | Output Features | Selected `C` | 5-Fold Train CV ROC-AUC |
|---|---|---|---|---|
| Full Clinical (`full_13`) | 13 | 28 | `1.0` | `0.9025 ± 0.0144` |
| Non-Invasive (`non_invasive_11`) | 11 | 21 | `0.1` | `0.8602 ± 0.0402` |

## 2. Internal Cleveland Validation (`10×5 Repeated Stratified CV`, N=303)

All preprocessing steps (median/mode imputation, standardization, one-hot encoding) were fit strictly inside each fold across 50 total splits (`RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)`).

| Model | ROC-AUC (95% fold range 2.5–97.5%) | PR-AUC (95% fold range) | Brier (95% fold range) | 10-Bin ECE (95% fold range) | Log-Loss (95% fold range) |
|---|---|---|---|---|---|
| Logistic Regression (`full_13`, C=1.0) | 0.914 ± 0.032 [0.847, 0.964] | 0.913 ± 0.034 [0.852, 0.966] | 0.115 ± 0.024 [0.076, 0.160] | 0.113 ± 0.022 [0.071, 0.152] | 0.373 ± 0.067 [0.260, 0.504] |
| Random Forest (`full_13`, tuned benchmark) | 0.912 ± 0.034 [0.837, 0.965] | 0.909 ± 0.037 [0.835, 0.962] | 0.123 ± 0.018 [0.097, 0.162] | 0.124 ± 0.028 [0.074, 0.181] | 0.395 ± 0.044 [0.330, 0.493] |
| Logistic Regression (`non_invasive_11`, C=0.1) | 0.879 ± 0.035 [0.815, 0.940] | 0.873 ± 0.039 [0.800, 0.933] | 0.143 ± 0.019 [0.113, 0.173] | 0.119 ± 0.023 [0.079, 0.158] | 0.444 ± 0.046 [0.367, 0.515] |

**Nested `10×5` CV Verification (inner 5-fold `C` grid inside every outer fold):** `full_13` ROC-AUC = `0.912 ± 0.033` (vs fixed `C=1.0`: `0.914 ± 0.032`, selected `C` counts `{'0.01': 0, '0.1': 28, '1.0': 22, '10.0': 0}`); `non_invasive_11` ROC-AUC = `0.875 ± 0.037` (vs fixed `C=0.1`: `0.879 ± 0.035`, selected `C` counts `{'0.01': 1, '0.1': 32, '1.0': 17, '10.0': 0}`).

## 3. Held-Out Cleveland Test Set (`test_61`, N=61) & Calibration

| Model | ROC-AUC | PR-AUC | Brier | 10-Bin ECE | Log-Loss | Recall @0.5 | Precision @0.5 | TN / FP / FN / TP |
|---|---|---|---|---|---|---|---|---|
| Logistic Regression (`full_13`) | 0.9665 | 0.9634 | 0.0797 | 0.0825 | 0.2595 | 0.9286 | 0.8387 | 28 / 5 / 2 / 26 |
| Random Forest (`full_13`) | 0.9545 | 0.9463 | 0.1023 | 0.1042 | 0.3475 | 0.8929 | 0.8065 | 27 / 6 / 3 / 25 |
| Logistic Regression (`non_invasive_11`) | 0.9589 | 0.9462 | 0.1036 | 0.1632 | 0.3548 | 0.8571 | 0.8889 | 30 / 3 / 4 / 24 |

### Held-Out `test_61` 10-Bin Reliability Table (`logreg_full_13` & `logreg_non_invasive_11`)

| Prob Bin | Full-13 Count | Full-13 Mean Pred | Full-13 Obs Freq | Non-Inv Count | Non-Inv Mean Pred | Non-Inv Obs Freq |
|---|---|---|---|---|---|---|
| `0.0-0.1` | 17 | 0.041 | 0.000 | 4 | 0.086 | 0.000 |
| `0.1-0.2` | 4 | 0.148 | 0.000 | 14 | 0.150 | 0.000 |
| `0.2-0.3` | 3 | 0.237 | 0.333 | 4 | 0.255 | 0.000 |
| `0.3-0.4` | 4 | 0.339 | 0.000 | 5 | 0.371 | 0.000 |
| `0.4-0.5` | 2 | 0.462 | 0.500 | 7 | 0.443 | 0.571 |
| `0.5-0.6` | 2 | 0.520 | 0.500 | 5 | 0.577 | 0.800 |
| `0.6-0.7` | 3 | 0.664 | 0.333 | 4 | 0.625 | 0.750 |
| `0.7-0.8` | 4 | 0.731 | 0.750 | 6 | 0.742 | 0.833 |
| `0.8-0.9` | 5 | 0.844 | 0.800 | 8 | 0.842 | 1.000 |
| `0.9-1.0` | 17 | 0.959 | 1.000 | 4 | 0.922 | 1.000 |

## 4. Split-Brain Discrepancy Analysis (`RandomForest` vs `LogisticRegression`)

- On `test_61`: mean `|p_RF - p_LR| = 0.0988`, max `|p_RF - p_LR| = 0.3478`, class flips (`@0.5`) = `2/61`, risk-band flips = `12/61`.
- Across all `N=303` Cleveland patients: mean `|p_RF - p_LR| = 0.0813`, max `|p_RF - p_LR| = 0.3705`, class flips (`@0.5`) = `19/303`, risk-band flips = `49/303`.
- Canonical default patient (male, 55): `LogReg full_13 = 0.0561` vs `Random Forest = 0.1769`. Retiring `model.pkl` and routing all runtimes through `model.json` v2 eliminates this cross-platform divergence.

## 5. Mode-Imputation False-Reassurance Trap (`ca`/`thal` Missing)

In `full_13`, mode imputation fills missing `ca` with `0.0` (`coef = -1.4986`) and missing `thal` with `3.0` (`coef = -0.5402`). Together they shift log-odds by **`-2.0389`** (multiplying odds by `0.130x`).

- On the `28` positive patients in `test_61` when `ca` and `thal` are masked (`NaN`):
  - True `full_13` (observed `ca`/`thal`): recall = `0.9286` (FN = `2`), mean prob = `0.8492`
  - Naive `full_13` (mode-imputing missing `ca=0, thal=3`): recall = `0.5714` (FN = `12`), mean prob = `0.5129`
  - Safe `non_invasive_11` (auto-routed when `ca`/`thal` missing): recall = `0.8571` (FN = `4`), mean prob = `0.7141`
- Symptomatic high-risk profile (`high_risk_non_invasive` preset): naive mode-imputed `full_13` drops to **`90.1%`**, whereas auto-routed `non_invasive_11` retains **`94.5%`** (and with confirmed `ca=2, thal=7`, `full_13` gives `99.7%`).

## 6. Collinearity & Referral-Bias Analysis (`full_13` vs Cleveland Cohort)

- **Why `num__age` is slightly negative (`-0.0609`) in `full_13`:** Univariately, older age strongly *increases* risk in Cleveland (`Pearson r = +0.2231`, `p = 8.96e-05`, univariate standardized `LogReg` coef = `+0.4301`). However, age correlates positively with `ca` (`r = +0.363`), `trestbps` (`r = +0.285`), and `oldpeak` (`r = +0.204`), and negatively with `thalach` (`r = -0.394`). Once fluoroscopy (`ca`), thallium scan (`thal`), blood pressure, and peak heart rate are conditioned on simultaneously in `N=242` training rows, the residual partial slope on age becomes slightly negative (`-0.0609`), and similarly stays tiny (`+0.1344`) in `non_invasive_11`.
- **Why `cat__fbs_1.0` is slightly negative (`-0.1033`):** Only `45/303` Cleveland patients have `fbs > 120 mg/dl`, with essentially identical disease prevalence (`fbs=0`: `0.453`, `fbs=1`: `0.489`, Fisher `p = 0.746`), so the small negative weight reflects sampling noise rather than any protective effect of hyperglycemia.
- **Angiography referral bias on chest pain (`cp=4`):**

| `cp` Code | Description | Cleveland N | Disease Cases | Prevalence | `full_13` coef | `non_invasive_11` coef |
|---|---|---|---|---|---|---|
| `1` | Typical angina | 23 | 7 | 0.304 | `-0.6192` | `-0.2179` |
| `2` | Atypical angina | 50 | 9 | 0.180 | `+0.1529` | `-0.1420` |
| `3` | Non-anginal pain | 86 | 18 | 0.209 | `-0.5748` | `-0.3266` |
| `4` | Asymptomatic | 144 | 105 | 0.729 | `+1.0306` | `+0.6861` |

Patients coded `cp=4` (asymptomatic) in a catheterization lab cohort were referred due to other abnormal clinical findings (silent ischemia / positive stress test), producing high disease prevalence and a strongly positive weight—an ascertainment artifact specific to referred clinical cohorts.

## 7. Zero-Retraining External Validation (UCI Hungarian, Switzerland, VA Long Beach)

Cleveland-trained `non_invasive_11` (`C=0.1`) was applied **with zero retraining** to three independent UCI hospitals (cached in `data/external/`). Because Switzerland (`123/123` = 100%) and VA Long Beach (`49/200` = 24.5%) encode missing serum cholesterol as `0`, and VA Long Beach has `1` impossible `trestbps == 0` entry, we report **both** raw `?`-only parsing and cleaned `chol/trestbps == 0 -> NaN` (imputed to Cleveland training medians `244.5` and `130.0`).

### 7a. Cohort Profiles & Missingness Audit

| Cohort | N | Positives (Prevalence) | `ca` Missing | `thal` Missing | `slope` Missing | `chol == 0` | `trestbps == 0` |
|---|---|---|---|---|---|---|---|
| UCI Hungarian | 294 | 106 (0.361) | 99.0% | 90.5% | 64.6% | 0 (0.0%) | 0 (0.0%) |
| UCI Switzerland | 123 | 115 (0.935) | 95.9% | 42.3% | 13.8% | 123 (100.0%) | 0 (0.0%) |
| UCI VA Long Beach | 200 | 149 (0.745) | 99.0% | 83.0% | 51.0% | 49 (24.5%) | 1 (0.5%) |
| Pooled External | 617 | 370 (0.600) | 98.4% | 78.4% | 50.1% | 172 (27.9%) | 1 (0.2%) |

### 7b. Zero-Retraining Performance (`non_invasive_11`)

| Cohort | Variant | ROC-AUC | PR-AUC | Brier | 10-Bin ECE | Log-Loss | Mean Pred Prob vs True Prev |
|---|---|---|---|---|---|---|---|
| UCI Hungarian | Raw (`?` -> NaN) | 0.8913 | 0.8531 | 0.1259 | 0.0793 | 0.4074 | 0.410 vs 0.361 |
| UCI Hungarian | Cleaned (`chol/trestbps=0` -> NaN) | 0.8913 | 0.8531 | 0.1259 | 0.0793 | 0.4074 | 0.410 vs 0.361 |
| UCI Switzerland | Raw (`?` -> NaN) | 0.7620 | 0.9790 | 0.2711 | 0.4347 | 0.7573 | 0.500 vs 0.935 |
| UCI Switzerland | Cleaned (`chol/trestbps=0` -> NaN) | 0.7620 | 0.9790 | 0.1708 | 0.3044 | 0.5131 | 0.632 vs 0.935 |
| UCI VA Long Beach | Raw (`?` -> NaN) | 0.7284 | 0.8764 | 0.1996 | 0.1585 | 0.5832 | 0.586 vs 0.745 |
| UCI VA Long Beach | Cleaned (`chol/trestbps=0` -> NaN) | 0.7442 | 0.8813 | 0.1836 | 0.1243 | 0.5446 | 0.621 vs 0.745 |
| Pooled External | Raw (`?` -> NaN) | 0.8302 | 0.8717 | 0.1787 | 0.1145 | 0.5341 | 0.485 vs 0.600 |
| Pooled External | Cleaned (`chol/trestbps=0` -> NaN) | 0.8649 | 0.8947 | 0.1536 | 0.0914 | 0.4729 | 0.522 vs 0.600 |

**Interpretation of Domain & Calibration Shift:** Discrimination (`ROC-AUC`) on Hungarian (`0.8913`) remains strong without retraining, and pooled external ROC-AUC improves from `0.8302` to `0.8649` when coding impossible `chol/trestbps == 0` entries as missing rather than severe negative z-scores. However, calibration degrades severely in Switzerland (`93.5%` disease prevalence) and VA Long Beach (`74.5%` prevalence) because Cleveland's `45.9%` prior intercept under-predicts risk in higher-prevalence referral hospitals (cleaned mean predicted probability `0.632` vs `0.935` in Switzerland, and `0.621` vs `0.745` in VA Long Beach), confirming why uncalibrated external deployment without site-specific intercept recalibration is unsafe.
