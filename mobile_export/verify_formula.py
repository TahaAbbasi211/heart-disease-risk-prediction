"""Verify the exported formula against sklearn on ALL rows of data/heart.csv.

This re-implements inference in pure Python/NumPy using ONLY model.json:

    numeric    : impute with median  -> (x - mean) / scale
    categorical: impute with mode    -> one-hot, unknown category -> all zeros
    probability: sigmoid(intercept + sum(coef_i * x_i))

It then compares against the real sklearn pipeline's predict_proba.
The maximum absolute difference must be below 1e-6.

Run from the project root:

    python mobile_export/verify_formula.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import log_loss
from sklearn.pipeline import Pipeline

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "notebooks"))

from common import build_preprocess, load_split  # noqa: E402

HERE = Path(__file__).resolve().parent
MODEL_JSON = HERE / "model.json"
DATA = ROOT / "data" / "heart.csv"
TOLERANCE = 1e-6


def load_model_json(path: Path = MODEL_JSON) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def build_output_vector(row: dict, spec: dict) -> np.ndarray:
    """Turn one raw input row into the 28-number vector the model expects.

    This is the exact logic the Dart code implements in the phone app.
    """
    values: list[float] = []

    # --- numeric block: median impute, then standardize ---------------------
    for col in spec["numeric_cols"]:
        v = row.get(col)
        stats = spec["numeric"][col]
        if v is None or (isinstance(v, float) and math.isnan(v)):
            v = stats["median"]
        values.append((float(v) - stats["mean"]) / stats["scale"])

    # --- categorical block: mode impute, then one-hot ----------------------
    for col in spec["categorical_cols"]:
        v = row.get(col)
        cat = spec["categorical"][col]
        if v is None or (isinstance(v, float) and math.isnan(v)):
            v = cat["mode"]
        v = float(v)
        # one-hot: 1.0 where the category matches, else 0.0.
        # An unseen category matches nothing -> the whole block stays 0.0,
        # which is exactly what OneHotEncoder(handle_unknown="ignore") does.
        for category in cat["categories"]:
            values.append(1.0 if v == float(category) else 0.0)

    return np.asarray(values, dtype=float)


def formula_predict_proba(row: dict, spec: dict) -> float:
    """sigmoid(w . x + b) -- no ML library involved."""
    x = build_output_vector(row, spec)
    z = float(spec["intercept"]) + float(np.dot(np.asarray(spec["coef"], dtype=float), x))
    return 1.0 / (1.0 + math.exp(-z))


def main() -> int:
    spec = load_model_json()
    df = pd.read_csv(DATA)
    X = df.drop(columns="target")
    y = df["target"]

    # Refit the identical sklearn pipeline so we have ground truth.
    X_train, _, y_train, _ = load_split(str(DATA))
    pipe = Pipeline(
        [
            ("prep", build_preprocess()),
            ("model", LogisticRegression(max_iter=1000, C=float(spec["metadata"]["C"]))),
        ]
    )
    pipe.fit(X_train, y_train)

    sklearn_probs = pipe.predict_proba(X)[:, 1]
    formula_probs = np.array([formula_predict_proba(row, spec) for row in X.to_dict("records")])

    diffs = np.abs(sklearn_probs - formula_probs)
    max_diff = float(diffs.max())

    print(f"rows compared      : {len(X)}")
    print(f"max |difference|   : {max_diff:.3e}")
    print(f"mean |difference|  : {float(diffs.mean()):.3e}")
    print(f"sklearn log-loss   : {log_loss(y, sklearn_probs):.6f}")

    # A sanity check that the formula is not merely "close but wrong":
    # it must reproduce the exact same class decisions.
    same_class = int(((sklearn_probs >= 0.5) == (formula_probs >= 0.5)).sum())
    print(f"same class @0.5    : {same_class}/{len(X)}")

    if max_diff < TOLERANCE:
        print(f"RESULT: PASS (max diff {max_diff:.3e} < {TOLERANCE:.0e})")
        return 0

    print(f"RESULT: FAIL (max diff {max_diff:.3e} >= {TOLERANCE:.0e})")
    worst = int(np.argmax(diffs))
    print(f"worst row index {worst}: sklearn={sklearn_probs[worst]!r} formula={formula_probs[worst]!r}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
