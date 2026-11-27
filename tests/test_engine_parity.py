"""Parity tests verifying heart_risk engine against scikit-learn and golden cases."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import pytest
from sklearn.linear_model import LogisticRegression
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

MODEL_JSON = ROOT / "mobile_export" / "model.json"
GOLDEN_JSON = ROOT / "mobile_export" / "golden_cases.json"
DATA_CSV = ROOT / "data" / "heart.csv"


def _extract_mode_spec(mode: str, cat_cols: list[str], pipe: Pipeline) -> dict[str, Any]:
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


def test_model_json_v2_schema() -> None:
    raw_text = MODEL_JSON.read_text(encoding="utf-8")
    assert "1.9.1" not in raw_text
    spec = json.loads(raw_text)
    assert spec["schema_version"] == 2
    assert spec["format"] == "heart-risk-linear-formula/2"
    assert spec["default_mode"] == "full_13"
    assert set(spec["models"].keys()) == {"full_13", "non_invasive_11"}
    assert spec["metadata"]["sklearn_version"] == "1.6.1"

    full = spec["models"]["full_13"]
    assert full["n_input_features"] == 13
    assert len(full["coef"]) == 28
    assert len(full["output_features"]) == 28
    assert full["metadata"]["sklearn_version"] == "1.6.1"

    ni = spec["models"]["non_invasive_11"]
    assert ni["n_input_features"] == 11
    assert len(ni["coef"]) == 21
    assert len(ni["output_features"]) == 21
    assert ni["metadata"]["sklearn_version"] == "1.6.1"
    assert "ca" not in ni["categorical_cols"]
    assert "thal" not in ni["categorical_cols"]

    for mode_key in ("full_13", "non_invasive_11"):
        rep = spec["models"][mode_key]["metadata"]["cv_10x5_repeated"]
        assert "fold_range_95" in rep["roc_auc"]
        assert "ci_95" not in rep["roc_auc"]

    ext = spec["metadata"]["external_validation"]
    for cohort_key in ("hungarian", "switzerland", "va", "pooled_external"):
        assert "impossible_zeros_as_nan" in ext["cohorts"][cohort_key]


@pytest.mark.parametrize(
    ("mode", "cat_cols"),
    [
        ("full_13", CAT_COLS_FULL),
        ("non_invasive_11", CAT_COLS_NON_INVASIVE),
    ],
)
def test_exact_arithmetic_parity_and_cross_os_refit(mode: str, cat_cols: list[str]) -> None:
    file_engine = HeartRiskEngine.from_json_file(MODEL_JSON)
    df = pd.read_csv(DATA_CSV)
    X_all = df.drop(columns="target")
    X_train, _, y_train, _ = load_split(str(DATA_CSV))

    c_val = float(file_engine.models[mode]["metadata"]["C"])
    pipe = Pipeline(
        [
            ("prep", build_preprocess(cat_cols)),
            ("model", LogisticRegression(max_iter=1000, C=c_val)),
        ]
    )
    pipe.fit(X_train, y_train)
    sklearn_probs = pipe.predict_proba(X_all)[:, 1]

    in_memory_models = {
        "full_13": _extract_mode_spec("full_13", CAT_COLS_FULL, pipe)
        if mode == "full_13"
        else file_engine.models["full_13"],
        "non_invasive_11": _extract_mode_spec("non_invasive_11", CAT_COLS_NON_INVASIVE, pipe)
        if mode == "non_invasive_11"
        else file_engine.models["non_invasive_11"],
    }
    in_memory_engine = HeartRiskEngine(
        {
            "schema_version": 2,
            "format": "heart-risk-linear-formula/2",
            "default_mode": "full_13",
            "risk_bands": file_engine.raw_spec["risk_bands"],
            "models": in_memory_models,
        }
    )

    in_mem_probs: list[float] = []
    file_probs: list[float] = []
    for row in X_all.to_dict("records"):
        res_mem = in_memory_engine.predict(row, mode=mode, validate=False)
        in_mem_probs.append(res_mem.probability)
        assert abs((res_mem.intercept + sum(c.delta_z for c in res_mem.contributions)) - res_mem.z) < 1e-12

        res_file = file_engine.predict(row, mode=mode, validate=False)
        file_probs.append(res_file.probability)
        assert abs((res_file.intercept + sum(c.delta_z for c in res_file.contributions)) - res_file.z) < 1e-12

    mem_arr = np.asarray(in_mem_probs, dtype=float)
    file_arr = np.asarray(file_probs, dtype=float)

    # 1. Exact formula arithmetic parity (< 1e-12) against the in-memory fit pipeline
    assert float(np.max(np.abs(sklearn_probs - mem_arr))) < 1e-12
    assert int(((sklearn_probs >= 0.5) == (mem_arr >= 0.5)).sum()) == len(X_all)

    # 2. Cross-OS refit reproducibility (< 1e-5 + 303/303 class agreement)
    assert float(np.max(np.abs(sklearn_probs - file_arr))) < 1e-5
    assert int(((sklearn_probs >= 0.5) == (file_arr >= 0.5)).sum()) == len(X_all)


def test_golden_cases_v2_exact_match() -> None:
    engine = HeartRiskEngine.from_json_file(MODEL_JSON)
    golden = json.loads(GOLDEN_JSON.read_text(encoding="utf-8"))
    assert golden["schema_version"] == 2
    assert golden["format"] == "heart-risk-golden-cases/2"
    assert len(golden["cases"]) == 27

    modes_seen = {case["mode"] for case in golden["cases"]}
    assert modes_seen == {"full_13", "non_invasive_11"}

    for case in golden["cases"]:
        res = engine.predict(case["input"], mode=case["mode"], validate=False)
        assert abs(res.probability - float(case["probability"])) < 1e-12
        assert abs(res.z - float(case["z"])) < 1e-12
        assert abs(res.intercept - float(case["intercept"])) < 1e-12
        cmap = res.contribution_map()
        assert set(cmap.keys()) == set(case["contributions"].keys())
        for col, expected_dz in case["contributions"].items():
            assert abs(cmap[col] - float(expected_dz)) < 1e-12
