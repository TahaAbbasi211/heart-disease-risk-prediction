# Heart Disease Risk Prediction

End-to-end machine learning project on the UCI Heart Disease datasets: exploratory analysis, leakage-free dual-mode preprocessing, repeated cross-validation and calibration evaluation, zero-retraining external validation across three independent UCI hospital cohorts, a pure-Python runtime inference/explainability package (`heart_risk/`), and a bilingual (English / فارسی) Streamlit app backed by a single-source-of-truth JSON formula (`mobile_export/model.json` v2).

> **Research & educational prototype. Not a medical diagnostic device.**

---

## Architecture: Single Source of Truth (`model.json` v2)

Previously, the Streamlit app loaded a pickled `RandomForestClassifier` (`model.pkl`) while mobile/formula consumers used `LogisticRegression` (`model.json` v1), creating a **Split-Brain discrepancy** (`49/303` risk-band flips across Cleveland; `0.0561` vs `0.1769` on the canonical default male patient) and a **mode-imputation false-reassurance trap** where missing invasive tests (`ca`, `thal`) silently defaulted to healthy modes (`ca=0, thal=3`, shifting log-odds by `-2.0389`).

In **v2**:
- **`mobile_export/model.json`** (`heart-risk-linear-formula/2`) is the **sole production artifact**; legacy `model.pkl` has been retired from runtime (`RandomForest` remains documented in `notebooks/` as a comparison benchmark only).
- **Dual-mode inference & clinical auto-routing (`heart_risk/`):**
  - `full_13`: 13 clinical features (`5` numeric + `8` categorical, `28` encoded features, `C = 1.0`).
  - `non_invasive_11`: 11 non-invasive / standard-workup features (`5` numeric + `6` categorical, `21` encoded features, `C = 0.1`, excluding `ca` and `thal`).
  - Under `mode="auto"`, whenever `ca` or `thal` is missing (`None`), `heart_risk` automatically routes to `non_invasive_11` instead of silently imputing healthy defaults—raising held-out test positive recall under missing invasive tests from `0.5714` (naive mode-imputed `full_13`) to `0.8571` (`non_invasive_11`).
- **Zero-ML Streamlit runtime:** `app.py` uses only `streamlit` and `heart_risk/` (standard library + `model.json` v2), with exact additive per-feature `Δz` explainability and bilingual EN / فارسی support.
- **Android app note:** `android_app/` currently runs `model.json` v1 and will be upgraded to **V2.0.0** (dual-mode `model.json` v2 + explainability + presets) in Phase 2.

---

## Dataset

- **Training & Internal Validation:** UCI Heart Disease dataset, Cleveland subset (`N = 303`, `139` positives = `45.9%`, `164` negatives). `6` missing values (`ca`: 4, `thal`: 2). Stratified 80/20 split (`train = 242`, `test = 61`, `random_state = 42`) applied *before* fitting any imputer, scaler, encoder, or model.
- **Zero-Retraining External Validation:** UCI Hungarian (`N = 294`, `36.1%` positive), UCI Switzerland (`N = 123`, `93.5%` positive), and UCI VA Long Beach (`N = 200`, `74.5%` positive), cached by `scripts/evaluate_heart.py` in `data/external/`.
- Source: UCI Machine Learning Repository (Heart Disease). Please credit the original authors if you reuse the data.

---

## Results

### 1. Training Hyperparameter Selection (`X_train`, `N = 242`, 5-Fold Stratified CV)

| Model / Mode | Input Features | Output Features | Selected `C` | 5-Fold Train CV ROC-AUC |
|---|---|---|---|---|
| Logistic Regression (`full_13`) | 13 | 28 | `1.0` | `0.902` (`0.9025 ± 0.0144`) |
| Logistic Regression (`non_invasive_11`) | 11 | 21 | `0.1` | `0.860` (`0.8602 ± 0.0402`) |

In `notebooks/03_modeling.ipynb` (5-fold train CV on the full 13 features), untuned baselines ranked: Logistic Regression (`0.902`), Random Forest (`0.894`), SVM (`0.888`), KNN (`0.872`), Gradient Boosting (`0.857`), Decision Tree (`0.786`), Dummy baseline (`0.500`), with tuned Random Forest reaching `0.904`—within one standard deviation of Logistic Regression (`0.902`).

### 2. Internal Cleveland Validation (`10×5 Repeated Stratified CV`, `N = 303`, 50 Folds)

All preprocessing (`SimpleImputer`, `StandardScaler`, `OneHotEncoder`) is refit inside every fold. Intervals below show the **95% fold range (2.5–97.5% across 50 folds)**:

| Model | ROC-AUC (95% fold range) | PR-AUC (95% fold range) | Brier (95% fold range) | 10-Bin ECE (95% fold range) | Log-Loss (95% fold range) |
|---|---|---|---|---|---|
| Logistic Regression (`full_13`, `C=1.0`) | `0.914 ± 0.032` `[0.847, 0.964]` | `0.913 ± 0.034` `[0.852, 0.966]` | `0.115 ± 0.024` `[0.076, 0.160]` | `0.113 ± 0.022` `[0.071, 0.152]` | `0.373 ± 0.067` `[0.260, 0.504]` |
| Random Forest (`full_13`, notebook benchmark) | `0.912 ± 0.034` `[0.837, 0.965]` | `0.909 ± 0.037` `[0.835, 0.962]` | `0.123 ± 0.018` `[0.097, 0.162]` | `0.124 ± 0.028` `[0.074, 0.181]` | `0.395 ± 0.044` `[0.330, 0.493]` |
| Logistic Regression (`non_invasive_11`, `C=0.1`) | `0.879 ± 0.035` `[0.815, 0.940]` | `0.873 ± 0.039` `[0.800, 0.933]` | `0.143 ± 0.019` `[0.113, 0.173]` | `0.119 ± 0.023` `[0.079, 0.158]` | `0.444 ± 0.046` `[0.367, 0.515]` |

**Nested `10×5` CV Verification** (re-tuning `C` via inner 5-fold CV inside every outer fold): `full_13` ROC-AUC = `0.912 ± 0.033` (vs fixed `C=1.0`: `0.914 ± 0.032`, choosing `C=0.1` in `28/50` and `C=1.0` in `22/50` folds); `non_invasive_11` ROC-AUC = `0.875 ± 0.037` (vs fixed `C=0.1`: `0.879 ± 0.035`, choosing `C=0.1` in `32/50`, `C=1.0` in `17/50`, `C=0.01` in `1/50` folds).

On the untouched held-out test set (`N = 61`, `28` positive):
- **Logistic Regression (`full_13`):** ROC-AUC `0.9665`, PR-AUC `0.9634`, Brier `0.0797`, 10-bin ECE `0.0825`, Log-Loss `0.2595`, recall `0.9286`, precision `0.8387` (`TN 28, FP 5, FN 2, TP 26`).
- **Logistic Regression (`non_invasive_11`):** ROC-AUC `0.9589`, PR-AUC `0.9462`, Brier `0.1036`, 10-bin ECE `0.1632`, Log-Loss `0.3548`, recall `0.8571`, precision `0.8889` (`TN 30, FP 3, FN 4, TP 24`).
- **Random Forest (`full_13` notebook benchmark):** ROC-AUC `0.9545`, recall `0.8929`, precision `0.8065` (`TN 27, FP 6, FN 3, TP 25`).

### 3. Zero-Retraining External Validation (`non_invasive_11`)

Cleveland-trained `non_invasive_11` (`C=0.1`) was evaluated directly without retraining on three independent UCI hospitals. Because Switzerland (`123/123` = `100%`) and VA Long Beach (`49/200` = `24.5%` cholesterol, `1/200` = `0.5%` blood pressure) encode missing vitals as `0`, both raw (`? -> NaN` only) and cleaned (`chol/trestbps == 0 -> NaN`, imputed to Cleveland medians `244.5` and `130.0`) metrics are reported:

| Cohort | N (Prevalence) | Raw ROC-AUC | Raw ECE | Cleaned ROC-AUC | Cleaned ECE | Mean Pred vs True Prev |
|---|---|---|---|---|---|---|
| UCI Hungarian | 294 (`36.1%`) | `0.8913` | `0.0793` | `0.8913` | `0.0793` | `0.410` vs `0.361` |
| UCI Switzerland | 123 (`93.5%`) | `0.7620` | `0.4347` | `0.7620` | `0.3044` | `0.632` vs `0.935` |
| UCI VA Long Beach | 200 (`74.5%`) | `0.7284` | `0.1585` | `0.7442` | `0.1243` | `0.621` vs `0.745` |
| Pooled External | 617 (`60.0%`) | `0.8302` | `0.1145` | `0.8649` | `0.0914` | `0.522` vs `0.600` |

While ranking performance (`ROC-AUC`) generalizes well to Hungarian (`0.8913`) and improves on pooled data (`0.8649`) after fixing impossible `chol/trestbps == 0` entries, calibration degrades across high-prevalence cohorts (`93.5%` Switzerland, `74.5%` VA Long Beach) because Cleveland's `45.9%` baseline intercept under-predicts risk without local recalibration. Full breakdowns and 10-bin reliability tables live in [docs/heart_v2_evaluation_report.md](docs/heart_v2_evaluation_report.md) and [docs/evaluation_metrics.json](docs/evaluation_metrics.json).

---

## What the Model Learned (Collinearity & Referral Bias)

- **Main drivers (`full_13`):** `ca` (`ca=0`: `-1.4986`, `ca=2`: `+0.6422`), `cp` (`cp=4`: `+1.0306`), `thal` (`thal=7`: `+0.8185`, `thal=3`: `-0.5402`), `sex`, `slope`, `thalach` (`-0.3725`), `trestbps` (`+0.3406`), and `oldpeak` (`+0.2595`).
- **Why `num__age` is `-0.0609` in `full_13`:** Univariately in Cleveland, older age *raises* risk (`Pearson r = +0.2231`, `p = 8.96e-05`; univariate standardized `LogReg` coef `+0.4301`). However, age shares strong collinearity with `ca` (`r = +0.363`), reduced `thalach` (`r = -0.394`), `trestbps` (`r = +0.285`), and `oldpeak` (`r = +0.204`). Once all of those clinical markers are conditioned on simultaneously in `N=242` training rows, the residual partial slope on age flips slightly negative (`-0.0609` in `full_13`; `+0.1344` in `non_invasive_11`).
- **Why `cat__fbs_1.0` is `-0.1033`:** Only `45/303` patients had fasting blood sugar `> 120 mg/dl`, with nearly identical disease prevalence (`48.9%` vs `45.3%`, Fisher `p = 0.746`); the tiny weight is sampling noise.
- **Angiography referral bias (`cp = 4`):** Asymptomatic chest pain (`cp = 4`) carries `72.9%` disease prevalence (`105/144`) and `+1.0306` weight in Cleveland because asymptomatic catheterization patients were referred due to silent ischemia or abnormal stress tests, not because absence of pain causes disease.

---

## Run & Verify

### Runtime app only (lightweight — zero ML libraries)

```bash
pip install -r requirements.txt
streamlit run app.py
```

### Full evaluation, export, parity checks, and test suite

```bash
pip install -r requirements-dev.txt
python scripts/evaluate_heart.py
python mobile_export/export_model.py
python mobile_export/verify_formula.py
pytest -v
```

---

## Project Structure

```text
heart_risk/              Pure-Python dual-mode inference, presets, and Δz engine
app.py                   Bilingual (EN / فارسی) Streamlit app powered by heart_risk
scripts/evaluate_heart.py  10x5 CV, calibration, split-brain, collinearity & UCI validation
mobile_export/           Dual-mode model.json v2, golden_cases.json v2, export & verify
tests/                   Parity, clinical safety, import-isolation & Streamlit AppTest suite
docs/                    Evaluation report, metrics JSON, and translation docs
notebooks/               EDA, preprocessing, modeling notebooks & shared common.py
data/                    Cleveland heart.csv (external UCI cohorts cached in data/external/)
android_app/             Offline Flutter app (to be upgraded to V2.0.0 in Phase 2)
requirements.txt         Lightweight Streamlit runtime dependencies
requirements-dev.txt     Full ML research, validation, and pytest dependencies
```
