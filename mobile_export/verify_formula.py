"""Verify exported formulas and pure-Python engine against scikit-learn.

Cleanly separates two verification layers for BOTH ``full_13`` and ``non_invasive_11``:
  1. Exact formula arithmetic parity (< 1e-12):
     - An in-memory HeartRiskEngine built directly from freshly fit sklearn pipelines
       matches ``pipe.predict_proba(X_all)`` within < 1e-12 across all 303 rows and
       satisfies ``intercept + sum(delta_z) == z`` within < 1e-12.
     - Committed ``mobile_export/model.json`` matches all 27 golden vectors in
       ``mobile_export/golden_cases.json`` (probability, z, intercept, delta_z)
       within < 1e-12.
  2. Cross-OS refit reproducibility (< 1e-5 & 303/303 class match @0.5):
     - Committed ``mobile_export/model.json`` matches freshly refit L-BFGS sklearn
       pipelines across all 303 Cleveland rows within < 1e-5 (resilient to BLAS
       differences between Windows MKL and Linux OpenBLAS).

Run from the project root:
    python mobile_export/verify_formula.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import log_loss
from sklearn.pipeline import Pipeline

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "notebooks"))

from common import (  # noqa: E402
    CAT_COLS_FULL,
    CAT_COLS_NON_INVASIVE,
    NUM_COLS,
    build_preprocess,
    load_split,
)
from heart_risk.engine import HeartRiskEngine  # noqa: E402

HERE = Path(__file__).resolve().parent
MODEL_JSON = HERE / "model.json"
GOLDEN_JSON = HERE / "golden_cases.json"
DATA = ROOT / "data" / "heart.csv"
EXACT_TOL = 1e-12
REFIT_TOL = 1e-5


def extract_mode_spec(mode: str, cat_cols: list[str], pipe: Pipeline) -> dict[str, Any]:
    """Unwrap a freshly fit sklearn Pipeline into a model.json v2 mode block."""
    prep = pipe.named_steps["prep"]
    model = pipe.named_steps["model"]
    num_pipe = prep.named_transformers_["num"]
    cat_pipe = prep.named_transformers_["cat"]
    num_imputer = num_pipe.named_steps["imputer"]
    scaler = num_pipe.named_steps["scaler"]
    cat_imputer = cat_pipe.named_steps["imputer"]
    onehot = cat_pipe.named_steps["onehot"]

    return {
        "name": mode,
        "numeric_cols": list(NUM_COLS),
        "categorical_cols": list(cat_cols),
        "numeric": {
            col: {
                "median": float(num_imputer.statistics_[i]),
                "mean": float(scaler.mean_[i]),
                "scale": float(scaler.scale_[i]),
            }
            for i, col in enumerate(NUM_COLS)
        },
        "categorical": {
            col: {
                "mode": float(cat_imputer.statistics_[i]),
                "categories": [float(c) for c in onehot.categories_[i]],
            }
            for i, col in enumerate(cat_cols)
        },
        "output_features": [str(n) for n in prep.get_feature_names_out()],
        "coef": [float(w) for w in np.ravel(model.coef_)],
        "intercept": float(np.ravel(model.intercept_)[0]),
    }


def verify_mode(
    mode: str,
    cat_cols: list[str],
    file_engine: HeartRiskEngine,
    in_memory_engine: HeartRiskEngine,
    pipe: Pipeline,
    X_all: pd.DataFrame,
    y_all: pd.Series,
) -> bool:
    c_val = float(file_engine.models[mode]["metadata"]["C"])
    sklearn_probs = pipe.predict_proba(X_all)[:, 1]
    records = X_all.to_dict("records")

    in_mem_probs: list[float] = []
    in_mem_add_errs: list[float] = []
    file_probs: list[float] = []
    file_add_errs: list[float] = []

    for row in records:
        res_mem = in_memory_engine.predict(row, mode=mode, validate=False)
        in_mem_probs.append(res_mem.probability)
        in_mem_add_errs.append(
            abs((res_mem.intercept + sum(c.delta_z for c in res_mem.contributions)) - res_mem.z)
        )

        res_file = file_engine.predict(row, mode=mode, validate=False)
        file_probs.append(res_file.probability)
        file_add_errs.append(
            abs((res_file.intercept + sum(c.delta_z for c in res_file.contributions)) - res_file.z)
        )

    mem_arr = np.asarray(in_mem_probs, dtype=float)
    file_arr = np.asarray(file_probs, dtype=float)
    mem_diffs = np.abs(sklearn_probs - mem_arr)
    file_diffs = np.abs(sklearn_probs - file_arr)

    max_mem_diff = float(mem_diffs.max())
    max_file_diff = float(file_diffs.max())
    max_add_err = float(max(max(in_mem_add_errs), max(file_add_errs)))
    same_class_mem = int(((sklearn_probs >= 0.5) == (mem_arr >= 0.5)).sum())
    same_class_file = int(((sklearn_probs >= 0.5) == (file_arr >= 0.5)).sum())

    print(f"=== Mode: {mode} (C={c_val}) ===")
    print(f"rows compared             : {len(X_all)}")
    print(f"exact arithmetic max |err|: {max_mem_diff:.3e}  (tol < {EXACT_TOL:.0e})")
    print(f"max |delta_z additivity|  : {max_add_err:.3e}  (tol < {EXACT_TOL:.0e})")
    print(f"cross-OS refit max |err|  : {max_file_diff:.3e}  (tol < {REFIT_TOL:.0e})")
    print(f"sklearn log-loss          : {log_loss(y_all, sklearn_probs):.6f}")
    print(f"same class @0.5 (mem/file): {same_class_mem}/{len(X_all)} / {same_class_file}/{len(X_all)}")

    ok = (
        max_mem_diff < EXACT_TOL
        and max_add_err < EXACT_TOL
        and same_class_mem == len(X_all)
        and max_file_diff < REFIT_TOL
        and same_class_file == len(X_all)
    )
    if not ok:
        worst = int(np.argmax(file_diffs))
        print(
            f"FAIL [{mode}] worst row {worst}: sklearn={sklearn_probs[worst]!r} "
            f"in_mem={mem_arr[worst]!r} committed={file_arr[worst]!r}"
        )
    return ok


def verify_golden_cases(file_engine: HeartRiskEngine) -> bool:
    golden = json.loads(GOLDEN_JSON.read_text(encoding="utf-8"))
    if golden.get("schema_version") != 2 or golden.get("format") != "heart-risk-golden-cases/2":
        print(f"FAIL: unexpected golden_cases format/schema: {golden.get('format')!r}")
        return False

    cases = golden["cases"]
    max_prob_err = 0.0
    max_z_err = 0.0
    max_dz_err = 0.0

    for case in cases:
        mode = case["mode"]
        res = file_engine.predict(case["input"], mode=mode, validate=False)
        max_prob_err = max(max_prob_err, abs(res.probability - float(case["probability"])))
        max_z_err = max(
            max_z_err,
            abs(res.z - float(case["z"])),
            abs(res.intercept - float(case["intercept"])),
        )

        cmap = res.contribution_map()
        if set(cmap.keys()) != set(case["contributions"].keys()):
            print(f"FAIL golden case '{case['name']}': contribution keys mismatch")
            return False
        for col, expected_dz in case["contributions"].items():
            max_dz_err = max(max_dz_err, abs(cmap[col] - float(expected_dz)))

    print("=== Golden Cases v2 (committed model.json) ===")
    print(f"cases verified            : {len(cases)}")
    print(f"max |prob err|            : {max_prob_err:.3e}")
    print(f"max |z/intercept err|     : {max_z_err:.3e}")
    print(f"max |delta_z err|         : {max_dz_err:.3e}")

    return max_prob_err < EXACT_TOL and max_z_err < EXACT_TOL and max_dz_err < EXACT_TOL


def main() -> int:
    file_engine = HeartRiskEngine.from_json_file(MODEL_JSON)
    df = pd.read_csv(DATA)
    X_all = df.drop(columns="target")
    y_all = df["target"]
    X_train, _, y_train, _ = load_split(str(DATA))

    pipes: dict[str, Pipeline] = {}
    in_memory_models: dict[str, Any] = {}
    for mode, cat_cols in (("full_13", CAT_COLS_FULL), ("non_invasive_11", CAT_COLS_NON_INVASIVE)):
        c_val = float(file_engine.models[mode]["metadata"]["C"])
        pipe = Pipeline(
            [
                ("prep", build_preprocess(cat_cols)),
                ("model", LogisticRegression(max_iter=1000, C=c_val)),
            ]
        )
        pipe.fit(X_train, y_train)
        pipes[mode] = pipe
        in_memory_models[mode] = extract_mode_spec(mode, cat_cols, pipe)

    in_memory_engine = HeartRiskEngine(
        {
            "schema_version": 2,
            "format": "heart-risk-linear-formula/2",
            "default_mode": "full_13",
            "risk_bands": file_engine.raw_spec.get("risk_bands", {"low_max": 0.35, "moderate_max": 0.65}),
            "models": in_memory_models,
        }
    )

    ok_full = verify_mode(
        "full_13", CAT_COLS_FULL, file_engine, in_memory_engine, pipes["full_13"], X_all, y_all
    )
    ok_ni = verify_mode(
        "non_invasive_11",
        CAT_COLS_NON_INVASIVE,
        file_engine,
        in_memory_engine,
        pipes["non_invasive_11"],
        X_all,
        y_all,
    )
    ok_golden = verify_golden_cases(file_engine)

    if ok_full and ok_ni and ok_golden:
        print(
            f"RESULT: PASS (exact arithmetic < {EXACT_TOL:.0e}, "
            f"cross-OS refit < {REFIT_TOL:.0e}, 27/27 golden cases < {EXACT_TOL:.0e})"
        )
        return 0
    print("RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
