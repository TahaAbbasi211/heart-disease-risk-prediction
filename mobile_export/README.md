# mobile_export — the model as a plain formula

This folder turns the project's Logistic Regression into a **plain mathematical
formula** that can be re-implemented on a phone without any machine-learning
library.

The phone app does not ship scikit-learn, NumPy or a `.pkl` file. It ships
`model.json` — a few hundred numbers — and ~40 lines of Dart that do the
arithmetic by hand.

---

## 1. Why a formula is possible

A `LogisticRegression` is a *linear* model. Its whole prediction is:

```
z    = intercept + coef_1*x_1 + coef_2*x_2 + ... + coef_n*x_n
prob = 1 / (1 + exp(-z))          # the sigmoid function
```

The only complication is that the raw inputs are first **preprocessed** by the
`ColumnTransformer` from `notebooks/common.py`. That preprocessing is also just
arithmetic, so it can be copied out as numbers:

| Step | What it does | What we export |
|---|---|---|
| Numeric imputer | fills missing values with the column **median** | `numeric[col].median` |
| StandardScaler | `(x - mean) / scale` | `numeric[col].mean`, `numeric[col].scale` |
| Categorical imputer | fills missing values with the column **mode** | `categorical[col].mode` |
| OneHotEncoder | one 0/1 column per known category | `categorical[col].categories` (in order) |

The final model sees **28** numbers: 5 standardized numeric values + 23 one-hot
columns (2 + 4 + 2 + 3 + 2 + 3 + 4 + 3).

---

## 2. The exact inference recipe

```
1. NUMERIC (order: age, trestbps, chol, thalach, oldpeak)
      if value is missing: value = median
      x = (value - mean) / scale

2. CATEGORICAL (order: sex, cp, fbs, restecg, exang, slope, ca, thal)
      if value is missing: value = mode
      for each known category c of that column:
          x = 1.0 if value == c else 0.0
      # a category never seen in training matches nothing  ->  all zeros
      # this is exactly OneHotEncoder(handle_unknown="ignore")

3. z    = intercept + sum(coef[i] * x[i])
4. prob = 1 / (1 + exp(-z))
```

The concatenation order (numeric block first, then categorical block) and the
category order inside each block matter — they must match `output_features`.

---

## 3. Files

| File | Purpose |
|---|---|
| `export_model.py` | trains the model, writes `model.json` and `golden_cases.json` |
| `model.json` | everything needed to reproduce `predict_proba` by hand |
| `verify_formula.py` | proves the formula matches sklearn on **all 303 rows** |
| `golden_cases.json` | 15 inputs + expected probabilities, used by the Dart tests |

---

## 4. Results (real output of this export)

Model: `LogisticRegression(max_iter=1000, C=1.0)`, trained on the 242-row
training split of `data/heart.csv`.

```
train=(242, 13)  test=(61, 13)
grid best C = 1  (CV AUC = 0.9025)
CV ROC-AUC (train, 5-fold): 0.9025 +/- 0.0144
TEST AUC=0.9665  recall=0.9286  precision=0.8387
wrote model.json  (28 output features)
wrote golden_cases.json  (15 cases)
```

`C=1` was **read from the existing GridSearchCV cell in
`notebooks/03_modeling.ipynb`** (`Logistic Regression: AUC=0.902
best_params_={'model__C': 1}`) and independently re-confirmed by re-running the
identical grid (`C in [0.01, 0.1, 1, 10]`, `StratifiedKFold(n_splits=5,
shuffle=True, random_state=42)`, scoring `roc_auc`) **on the training set only**.

> The test-set numbers were looked at **once**, after `C` was frozen. Nothing was
> tuned afterwards.

---

## 5. How correctness is proven

```
python mobile_export/verify_formula.py
```

```
rows compared      : 303
max |difference|   : 3.331e-16
mean |difference|  : 1.143e-17
sklearn log-loss   : 0.317086
same class @0.5    : 303/303
RESULT: PASS (max diff 3.331e-16 < 1e-06)
```

The maximum absolute difference between the pure-Python formula and sklearn's
`predict_proba` over all 303 rows is `3.3e-16`, i.e. floating-point noise, far
below the required `1e-6`.

---

## 6. How to re-run everything

From the **project root** (`E:\Projects\Streamlit`):

```powershell
# 1. re-export the model + golden cases
python mobile_export/export_model.py

# 2. check the formula against sklearn (must print PASS)
python mobile_export/verify_formula.py
```

Both scripts are self-contained; they import `load_split` and
`build_preprocess` from `notebooks/common.py`, so the exported formula always
uses exactly the same split and the same preprocessing as the notebook.

The scripts only **read** `data/heart.csv` and **write** inside `mobile_export/`.
`model.pkl`, `app.py` and the notebooks are never touched.

### Copying into the app

`android_app/assets/model.json` is a copy of `mobile_export/model.json`, and
`android_app/test/golden_cases.json` is a copy of `mobile_export/golden_cases.json`.
If you re-export, copy both files again:

```powershell
Copy-Item mobile_export/model.json        android_app/assets/model.json -Force
Copy-Item mobile_export/golden_cases.json android_app/test/golden_cases.json -Force
```
