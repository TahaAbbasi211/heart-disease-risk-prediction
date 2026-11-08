"""Export the final Logistic Regression model to a plain-formula JSON file.

This script trains a LogisticRegression pipeline (same preprocessing as the
Streamlit app) on the training split, then dumps every number needed to
reproduce ``predict_proba`` by hand -- no scikit-learn required at inference.

Run from the project root:

    python mobile_export/export_model.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import precision_score, recall_score, roc_auc_score
from sklearn.model_selection import GridSearchCV, StratifiedKFold, cross_val_score
from sklearn.pipeline import Pipeline

# ---------------------------------------------------------------------------
# Make notebooks/common.py importable regardless of the current directory.
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "notebooks"))

from common import CAT_COLS, NUM_COLS, build_preprocess, load_split  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent
DATA = ROOT / "data" / "heart.csv"

# Best value found by the GridSearchCV in notebooks/03_modeling.ipynb
# (cell with `searches[...]`): Logistic Regression best_params_ = {'model__C': 1}.
# We re-run the identical grid below to confirm it on the training set only.
NOTEBOOK_BEST_C = 1
C_GRID = [0.01, 0.1, 1, 10]


def make_pipeline(c: float) -> Pipeline:
    """Preprocessing + LogisticRegression, exactly as in the notebook."""
    return Pipeline(
        [
            ("prep", build_preprocess()),
            ("model", LogisticRegression(max_iter=1000, C=c)),
        ]
    )


def main() -> None:
    X_train, X_test, y_train, y_test = load_split(str(DATA))
    print(f"train={X_train.shape}  test={X_test.shape}")

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

    # -- 1. Confirm the notebook's best C using the training set only --------
    gs = GridSearchCV(make_pipeline(1.0), {"model__C": C_GRID}, cv=cv, scoring="roc_auc", n_jobs=-1)
    gs.fit(X_train, y_train)
    print(f"grid best C = {gs.best_params_['model__C']}  (CV AUC = {gs.best_score_:.4f})")
    best_c = float(gs.best_params_["model__C"])
    if best_c != NOTEBOOK_BEST_C:
        print(f"NOTE: notebook said C={NOTEBOOK_BEST_C}, grid re-run says C={best_c}; using the re-run.")

    # -- 2. Fit the final pipeline with that C on the training split --------
    pipe = make_pipeline(best_c)
    pipe.fit(X_train, y_train)

    # Cross-validated ROC-AUC on the *training* set (no test leakage).
    cv_auc = cross_val_score(pipe, X_train, y_train, cv=cv, scoring="roc_auc")
    print(f"CV ROC-AUC (train, 5-fold): {cv_auc.mean():.4f} +/- {cv_auc.std():.4f}")

    # -- 3. One single honest look at the held-out test set ------------------
    p_test = pipe.predict_proba(X_test)[:, 1]
    y_hat = (p_test >= 0.5).astype(int)
    test_auc = roc_auc_score(y_test, p_test)
    test_rec = recall_score(y_test, y_hat)
    test_prec = precision_score(y_test, y_hat)
    print(f"TEST AUC={test_auc:.4f}  recall={test_rec:.4f}  precision={test_prec:.4f}")
    print("(reported once; nothing was tuned after seeing the test set)")

    # -- 4. Unwrap the fitted preprocessing --------------------------------
    prep = pipe.named_steps["prep"]
    model = pipe.named_steps["model"]

    # ColumnTransformer order: ("num", ..., NUM_COLS), ("cat", ..., CAT_COLS)
    num_pipe = prep.named_transformers_["num"]
    cat_pipe = prep.named_transformers_["cat"]

    num_imputer = num_pipe.named_steps["imputer"]
    scaler = num_pipe.named_steps["scaler"]
    cat_imputer = cat_pipe.named_steps["imputer"]
    onehot = cat_pipe.named_steps["onehot"]

    numeric = {
        col: {
            "median": float(num_imputer.statistics_[i]),
            "mean": float(scaler.mean_[i]),
            "scale": float(scaler.scale_[i]),
        }
        for i, col in enumerate(NUM_COLS)
    }
    categorical = {
        col: {
            "mode": float(cat_imputer.statistics_[i]),
            "categories": [float(c) for c in onehot.categories_[i]],
        }
        for i, col in enumerate(CAT_COLS)
    }

    output_features = [str(n) for n in prep.get_feature_names_out()]
    coef = [float(w) for w in np.ravel(model.coef_)]
    intercept = float(np.ravel(model.intercept_)[0])
    assert len(coef) == len(output_features), "coef/output feature mismatch"

    model_json = {
        "format": "heart-risk-linear-formula/1",
        "description": (
            "Logistic regression exported as a plain formula. "
            "prob = sigmoid(intercept + sum(coef_i * x_i)) with x built as "
            "numeric(impute median -> standardize) then categorical(impute mode -> one-hot, "
            "unknown -> all zeros)."
        ),
        "positive_class": 1,
        "positive_class_label": "disease",
        "n_input_features": len(NUM_COLS) + len(CAT_COLS),
        "input_features": NUM_COLS + CAT_COLS,
        "numeric_cols": list(NUM_COLS),
        "categorical_cols": list(CAT_COLS),
        "numeric": numeric,
        "categorical": categorical,
        "output_features": output_features,
        "coef": coef,
        "intercept": intercept,
        "metadata": {
            "model": f"LogisticRegression(max_iter=1000, C={best_c})",
            "C": best_c,
            "cv": "StratifiedKFold(n_splits=5, shuffle=True, random_state=42)",
            "cv_roc_auc_train": float(cv_auc.mean()),
            "cv_roc_auc_train_std": float(cv_auc.std()),
            "test_roc_auc": float(test_auc),
            "test_recall": float(test_rec),
            "test_precision": float(test_prec),
            "random_state": 42,
            "sklearn_version": __import__("sklearn").__version__,
        },
    }

    out_path = OUT_DIR / "model.json"
    out_path.write_text(json.dumps(model_json, indent=2), encoding="utf-8")
    print(f"wrote {out_path}  ({len(coef)} output features)")

    # -- 5. Golden cases for the Flutter tests ------------------------------
    golden = build_golden_cases(pipe, X_train, X_test, y_train, y_test)
    golden_path = OUT_DIR / "golden_cases.json"
    golden_path.write_text(json.dumps(golden, indent=2), encoding="utf-8")
    print(f"wrote {golden_path}  ({len(golden['cases'])} cases)")


def build_golden_cases(pipe, X_train, X_test, y_train, y_test) -> dict:
    """~15 input rows with sklearn probabilities, for testing the phone app.

    Includes the rows that really contain missing ca/thal, plus one row with a
    category value the model never saw during training.
    """
    full = pd.read_csv(DATA)
    X_all = full.drop(columns="target")

    chosen: list[tuple[str, pd.Series]] = []

    # (a) the six rows that actually carry missing values in the raw CSV
    for idx, row in X_all.iterrows():
        if row[["ca", "thal"]].isna().any() and len(chosen) < 6:
            chosen.append((f"row {idx} with missing value", row))

    # (b) a spread of ordinary rows (first rows of the test split)
    for idx, row in X_test.head(8).iterrows():
        chosen.append((f"test-split row {idx}", row))

    # (c) one row with an unseen category: thal=5 exists nowhere in training
    unseen = X_all.iloc[0].copy()
    unseen["thal"] = 5.0
    unseen_label = "unseen category: thal=5 (never in training data)"
    chosen.append((unseen_label, unseen))

    cases = []
    for name, row in chosen:
        payload = {c: (None if pd.isna(row[c]) else float(row[c])) for c in X_all.columns}
        frame = pd.DataFrame([{c: (np.nan if payload[c] is None else payload[c]) for c in X_all.columns}])
        prob = float(pipe.predict_proba(frame)[0, 1])
        cases.append({"name": name, "input": payload, "probability": prob})

    return {
        "format": "heart-risk-golden-cases/1",
        "note": (
            "probabilities produced by the sklearn pipeline in export_model.py; "
            "the Dart implementation must match them within 1e-6"
        ),
        "tolerance": 1e-6,
        "cases": cases,
    }


if __name__ == "__main__":
    main()
