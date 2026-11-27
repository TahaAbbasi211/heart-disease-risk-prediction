# mobile_export — Dual-Mode Plain-Formula Export (`v2`)

This folder exports the project's **two Logistic Regression models** into a single self-contained arithmetic specification (`model.json`, schema `heart-risk-linear-formula/2`) so web and mobile clients execute identical predictions without scikit-learn, NumPy, or `.pkl` files.

---

## 1. Dual-Mode Specification (`schema_version: 2`)

1. **`models.full_13`** (`C = 1.0`, `13` input features -> `28` encoded features):
   Uses all `5` numeric features (`age`, `trestbps`, `chol`, `thalach`, `oldpeak`) and `8` categorical features (`sex`, `cp`, `fbs`, `restecg`, `exang`, `slope`, `ca`, `thal`).
2. **`models.non_invasive_11`** (`C = 0.1`, `11` input features -> `21` encoded features):
   Uses the `5` numeric features and `6` non-invasive / standard-workup categorical features (`sex`, `cp`, `fbs`, `restecg`, `exang`, `slope`), excluding `ca` and `thal`.

### Clinical Auto-Routing Safety
When `ca` or `thal` is missing (`null`), clients must route to **`non_invasive_11`** instead of mode-imputing `full_13` (`ca=0.0, thal=3.0`), which artificially shifts log-odds by `-2.0389`.

---

## 2. Exact Inference & Additive Explainability (`Δz`)

For the selected model block (`models[mode]`):

```text
1. NUMERIC (in numeric_cols order):
      if missing: val = numeric[col].median
      x = (val - numeric[col].mean) / numeric[col].scale
      delta_z[col] = coef[offset] * x

2. CATEGORICAL (in categorical_cols order):
      if missing: val = categorical[col].mode
      match val == categorical[col].categories[j] -> delta_z[col] = coef[offset + j]
      (unseen category matches nothing -> delta_z[col] = 0.0)

3. z    = intercept + sum(delta_z.values())
4. prob = sigmoid(z)   # use stable exp(-z) for z >= 0 and exp(z)/(1+exp(z)) for z < 0
```

---

## 3. Files & Verification

| File | Purpose |
|---|---|
| `export_model.py` | Confirms `C` on `X_train` (`N=242`), computes 5-fold & 10×5 repeated CV + `test_61`, embeds external summary (requires `docs/evaluation_metrics.json` unless `--allow-missing-external` is passed), writes `model.json` v2 & `golden_cases.json` v2 |
| `model.json` | Schema `heart-risk-linear-formula/2` containing `full_13` and `non_invasive_11` (`scikit-learn==1.6.1`) |
| `golden_cases.json` | Schema `heart-risk-golden-cases/2` (`27` cases across both modes with `probability`, `z`, `intercept`, and per-input `contributions`) |
| `verify_formula.py` | Verifies exact in-memory formula arithmetic parity (`< 1e-12`), golden cases (`< 1e-12`), and cross-OS refit reproducibility (`< 1e-5`, `303/303` class match) |

Run from the project root (`scikit-learn==1.6.1`):

```bash
python scripts/evaluate_heart.py
python mobile_export/export_model.py
python mobile_export/verify_formula.py
```

Verified output (`verify_formula.py`, `scikit-learn==1.6.1`):
- `full_13`: exact arithmetic `2.220e-16` (`< 1e-12`), `delta_z` additivity `0.000e+00`, cross-OS refit `2.220e-16` (`< 1e-5`), `303/303` class agreement `@0.5`.
- `non_invasive_11`: exact arithmetic `2.220e-16` (`< 1e-12`), `delta_z` additivity `0.000e+00`, cross-OS refit `2.220e-16` (`< 1e-5`), `303/303` class agreement `@0.5`.
- `Golden Cases v2`: `27/27` cases verified (`max |prob err| = 0.000e+00`, `max |z/intercept err| = 0.000e+00`, `max |delta_z err| = 0.000e+00`).

*(Phase 2 will sync `model.json` v2 and `golden_cases.json` v2 into `android_app/` for the V2.0.0 release.)*
