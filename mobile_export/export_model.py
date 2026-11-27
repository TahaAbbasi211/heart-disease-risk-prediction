"""Export dual-mode Logistic Regression models to schema heart-risk-linear-formula/2.

Exports two self-contained linear models trained strictly on the stratified 80/20
Cleveland training split (random_state=42):
  1. full_13: all 13 clinical features (5 numeric + 8 categorical)
  2. non_invasive_11: 11 non-invasive / standard-workup features (no ca, thal)

Also writes mobile_export/golden_cases.json in schema heart-risk-golden-cases/2
with exact probability, z, intercept, and per-feature delta_z contributions.

Run from the project root:
    python mobile_export/export_model.py
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import sklearn
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    log_loss,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import (
    GridSearchCV,
    RepeatedStratifiedKFold,
    StratifiedKFold,
    cross_val_score,
)
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
from heart_risk.presets import CLINICAL_PRESETS  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent
DATA = ROOT / "data" / "heart.csv"
EVAL_METRICS_JSON = ROOT / "docs" / "evaluation_metrics.json"
C_GRID = [0.01, 0.1, 1.0, 10.0]


def make_pipeline(cat_cols: list[str], c: float) -> Pipeline:
    return Pipeline(
        [
            ("prep", build_preprocess(cat_cols)),
            ("model", LogisticRegression(max_iter=1000, C=c)),
        ]
    )


def compute_ece(y_true: np.ndarray, y_prob: np.ndarray, n_bins: int = 10) -> float:
    y_true_arr = np.asarray(y_true, dtype=float)
    y_prob_arr = np.asarray(y_prob, dtype=float)
    edges = np.linspace(0.0, 1.0, n_bins + 1)
    n_total = len(y_true_arr)
    ece = 0.0
    for i in range(n_bins):
        lo, hi = float(edges[i]), float(edges[i + 1])
        mask = (y_prob_arr >= lo) & (y_prob_arr <= hi) if i == 0 else (y_prob_arr > lo) & (y_prob_arr <= hi)
        count = int(mask.sum())
        if count > 0:
            ece += (count / n_total) * abs(float(y_true_arr[mask].mean()) - float(y_prob_arr[mask].mean()))
    return float(ece)


def repeated_10x5_summary(cat_cols: list[str], c: float, X_all: pd.DataFrame, y_all: pd.Series) -> dict[str, Any]:
    rskf = RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)
    buckets: dict[str, list[float]] = {
        "roc_auc": [],
        "pr_auc": [],
        "brier": [],
        "ece_10bin": [],
        "log_loss": [],
    }
    for tr_idx, va_idx in rskf.split(X_all, y_all):
        pipe = make_pipeline(cat_cols, c)
        pipe.fit(X_all.iloc[tr_idx], y_all.iloc[tr_idx])
        p_va = pipe.predict_proba(X_all.iloc[va_idx])[:, 1]
        y_va = y_all.iloc[va_idx].to_numpy()
        buckets["roc_auc"].append(float(roc_auc_score(y_va, p_va)))
        buckets["pr_auc"].append(float(average_precision_score(y_va, p_va)))
        buckets["brier"].append(float(brier_score_loss(y_va, p_va)))
        buckets["ece_10bin"].append(compute_ece(y_va, p_va, n_bins=10))
        buckets["log_loss"].append(float(log_loss(y_va, p_va, labels=[0, 1])))

    out: dict[str, Any] = {"cv": "RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)"}
    for metric, vals in buckets.items():
        arr = np.asarray(vals, dtype=float)
        out[metric] = {
            "mean": float(arr.mean()),
            "std": float(arr.std()),
            "fold_range_95": [float(np.percentile(arr, 2.5)), float(np.percentile(arr, 97.5))],
        }
    return out


def export_single_mode(
    mode_name: str,
    description: str,
    cat_cols: list[str],
    X_train: pd.DataFrame,
    X_test: pd.DataFrame,
    y_train: pd.Series,
    y_test: pd.Series,
    X_all: pd.DataFrame,
    y_all: pd.Series,
) -> tuple[dict[str, Any], Pipeline]:
    cv_5 = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    gs = GridSearchCV(
        make_pipeline(cat_cols, 1.0),
        {"model__C": C_GRID},
        cv=cv_5,
        scoring="roc_auc",
        n_jobs=-1,
    )
    gs.fit(X_train, y_train)
    best_c = float(gs.best_params_["model__C"])

    pipe = make_pipeline(cat_cols, best_c)
    pipe.fit(X_train, y_train)

    cv_auc = cross_val_score(pipe, X_train, y_train, cv=cv_5, scoring="roc_auc")
    rep_cv = repeated_10x5_summary(cat_cols, best_c, X_all, y_all)

    p_test = pipe.predict_proba(X_test)[:, 1]
    y_hat = (p_test >= 0.5).astype(int)
    y_test_arr = y_test.to_numpy()
    tn, fp, fn, tp = [int(v) for v in confusion_matrix(y_test_arr, y_hat, labels=[0, 1]).ravel()]
    test_metrics = {
        "n": int(len(y_test_arr)),
        "roc_auc": float(roc_auc_score(y_test_arr, p_test)),
        "pr_auc": float(average_precision_score(y_test_arr, p_test)),
        "brier": float(brier_score_loss(y_test_arr, p_test)),
        "ece_10bin": compute_ece(y_test_arr, p_test, n_bins=10),
        "log_loss": float(log_loss(y_test_arr, p_test, labels=[0, 1])),
        "recall": float(recall_score(y_test_arr, y_hat)),
        "precision": float(precision_score(y_test_arr, y_hat)),
        "confusion_matrix": {"tn": tn, "fp": fp, "fn": fn, "tp": tp},
    }

    prep = pipe.named_steps["prep"]
    model = pipe.named_steps["model"]
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
        for i, col in enumerate(cat_cols)
    }

    output_features = [str(n) for n in prep.get_feature_names_out()]
    coef = [float(w) for w in np.ravel(model.coef_)]
    intercept = float(np.ravel(model.intercept_)[0])
    assert len(coef) == len(output_features), f"{mode_name}: coef/output_features length mismatch"

    block = {
        "name": mode_name,
        "description": description,
        "n_input_features": len(NUM_COLS) + len(cat_cols),
        "input_features": list(NUM_COLS) + list(cat_cols),
        "numeric_cols": list(NUM_COLS),
        "categorical_cols": list(cat_cols),
        "numeric": numeric,
        "categorical": categorical,
        "output_features": output_features,
        "coef": coef,
        "intercept": intercept,
        "metadata": {
            "model": f"LogisticRegression(max_iter=1000, C={best_c})",
            "C": best_c,
            "cv_5fold_train": "StratifiedKFold(n_splits=5, shuffle=True, random_state=42)",
            "cv_5fold_train_auc": float(cv_auc.mean()),
            "cv_5fold_train_std": float(cv_auc.std()),
            "cv_10x5_repeated": rep_cv,
            "test_61": test_metrics,
            "random_state": 42,
            "sklearn_version": sklearn.__version__,
        },
    }
    print(
        f"[{mode_name}] C={best_c} | train_5cv={cv_auc.mean():.4f}+/-{cv_auc.std():.4f} | "
        f"10x5_auc={rep_cv['roc_auc']['mean']:.4f} | test_auc={test_metrics['roc_auc']:.4f} | "
        f"out_features={len(coef)}"
    )
    return block, pipe


def linear_explain_and_check(
    spec: dict[str, Any],
    pipe: Pipeline,
    payload: dict[str, float | None],
) -> tuple[float, float, float, dict[str, float]]:
    """Compute exact z, intercept, contributions and assert parity with sklearn."""
    coef = [float(w) for w in spec["coef"]]
    intercept = float(spec["intercept"])
    contributions: dict[str, float] = {}
    offset = 0

    for col in spec["numeric_cols"]:
        stats = spec["numeric"][col]
        raw = payload.get(col)
        val = float(stats["median"]) if raw is None else float(raw)
        x = (val - float(stats["mean"])) / float(stats["scale"])
        contributions[col] = coef[offset] * x
        offset += 1

    for col in spec["categorical_cols"]:
        cat = spec["categorical"][col]
        raw = payload.get(col)
        val = float(cat["mode"]) if raw is None else float(raw)
        dz = 0.0
        for j, category in enumerate(cat["categories"]):
            if val == float(category):
                dz = coef[offset + j]
                break
        contributions[col] = dz
        offset += len(cat["categories"])

    z = intercept + sum(contributions.values())
    prob = (1.0 / (1.0 + math.exp(-z))) if z >= 0 else (math.exp(z) / (1.0 + math.exp(z)))

    frame = pd.DataFrame(
        [{c: (np.nan if payload.get(c) is None else float(payload[c])) for c in (NUM_COLS + CAT_COLS_FULL)}]
    )
    sk_prob = float(pipe.predict_proba(frame)[0, 1])
    if abs(prob - sk_prob) >= 1e-12:
        raise AssertionError(f"Parity error during golden export: {abs(prob - sk_prob)}")
    return prob, z, intercept, contributions


def build_golden_cases(
    models_spec: dict[str, dict[str, Any]],
    pipes: dict[str, Pipeline],
    X_test: pd.DataFrame,
    X_all: pd.DataFrame,
) -> dict[str, Any]:
    """Generate heart-risk-golden-cases/2 covering both full_13 and non_invasive_11."""
    cases: list[dict[str, Any]] = []
    all_cols = NUM_COLS + CAT_COLS_FULL

    def row_to_payload(row: pd.Series, *, drop_invasive: bool = False) -> dict[str, float | None]:
        out = {c: (None if pd.isna(row[c]) else float(row[c])) for c in all_cols}
        if drop_invasive:
            out["ca"] = None
            out["thal"] = None
        return out

    # --- full_13 cases ---
    full_rows: list[tuple[str, dict[str, float | None]]] = []
    for idx, row in X_all.iterrows():
        if row[["ca", "thal"]].isna().any():
            full_rows.append((f"full_13: raw row {idx} with missing invasive value", row_to_payload(row)))
    for idx, row in X_test.head(8).iterrows():
        full_rows.append((f"full_13: test-split row {idx}", row_to_payload(row)))
    unseen_thal = row_to_payload(X_all.iloc[0])
    unseen_thal["thal"] = 5.0
    full_rows.append(("full_13: unseen category thal=5", unseen_thal))

    for name, payload in full_rows:
        prob, z, intercept, contrib = linear_explain_and_check(
            models_spec["full_13"], pipes["full_13"], payload
        )
        cases.append(
            {
                "name": name,
                "mode": "full_13",
                "input": payload,
                "probability": prob,
                "z": z,
                "intercept": intercept,
                "contributions": contrib,
            }
        )

    # --- non_invasive_11 cases ---
    ni_rows: list[tuple[str, dict[str, float | None]]] = []
    for idx, row in X_test.head(8).iterrows():
        ni_rows.append(
            (f"non_invasive_11: test-split row {idx}", row_to_payload(row, drop_invasive=True))
        )

    hi_payload = {
        k: (None if v is None else float(v))
        for k, v in CLINICAL_PRESETS["high_risk_non_invasive"]["inputs"].items()
    }
    ni_rows.append(("non_invasive_11: high-risk symptomatic profile", hi_payload))

    lo_payload = {
        k: (None if v is None else float(v))
        for k, v in CLINICAL_PRESETS["low_risk"]["inputs"].items()
    }
    lo_payload["ca"] = None
    lo_payload["thal"] = None
    ni_rows.append(("non_invasive_11: low-risk profile", lo_payload))

    unseen_cp = row_to_payload(X_all.iloc[0], drop_invasive=True)
    unseen_cp["cp"] = 9.0
    ni_rows.append(("non_invasive_11: unseen category cp=9", unseen_cp))

    missing_chol = row_to_payload(X_test.iloc[0], drop_invasive=True)
    missing_chol["chol"] = None
    ni_rows.append(("non_invasive_11: missing chol (median-imputed)", missing_chol))

    for name, payload in ni_rows:
        prob, z, intercept, contrib = linear_explain_and_check(
            models_spec["non_invasive_11"], pipes["non_invasive_11"], payload
        )
        cases.append(
            {
                "name": name,
                "mode": "non_invasive_11",
                "input": payload,
                "probability": prob,
                "z": z,
                "intercept": intercept,
                "contributions": contrib,
            }
        )

    return {
        "schema_version": 2,
        "format": "heart-risk-golden-cases/2",
        "note": (
            "Exact probabilities, log-odds z, intercept, and per-input delta_z contributions "
            "verified against scikit-learn (< 1e-12) for both full_13 and non_invasive_11."
        ),
        "tolerance": 1e-6,
        "cases": cases,
    }


def load_external_validation_summary(*, allow_missing_external: bool = False) -> dict[str, Any] | None:
    """Read verified external validation metrics produced by scripts/evaluate_heart.py."""
    if not EVAL_METRICS_JSON.exists():
        if allow_missing_external:
            return None
        raise FileNotFoundError(
            f"Missing {EVAL_METRICS_JSON}. Run 'python scripts/evaluate_heart.py' first "
            "or pass --allow-missing-external to export without external validation."
        )

    eval_data = json.loads(EVAL_METRICS_JSON.read_text(encoding="utf-8"))
    ext = eval_data.get("external_validation")
    if not ext:
        if allow_missing_external:
            return None
        raise RuntimeError(
            f"{EVAL_METRICS_JSON} does not contain 'external_validation'. "
            "Re-run 'python scripts/evaluate_heart.py' or pass --allow-missing-external."
        )

    summary: dict[str, Any] = {
        "model_evaluated": ext["model_evaluated"],
        "zero_retraining": ext["zero_retraining"],
        "cohorts": {},
    }
    for key in ["hungarian", "switzerland", "va", "pooled_external"]:
        meta = ext["cohorts"][key]
        res_raw = ext["results"][key]["raw"]
        res_clean = ext["results"][key]["impossible_zeros_as_nan"]
        summary["cohorts"][key] = {
            "label": meta["label"],
            "n": meta["n"],
            "n_pos": meta["n_pos"],
            "prevalence": meta["prevalence"],
            "chol_zero_count": meta["chol_zero_count"],
            "trestbps_zero_count": meta["trestbps_zero_count"],
            "raw": {
                "roc_auc": res_raw["roc_auc"],
                "pr_auc": res_raw["pr_auc"],
                "brier": res_raw["brier"],
                "ece_10bin": res_raw["ece_10bin"],
                "log_loss": res_raw["log_loss"],
                "mean_pred_prob": res_raw["mean_pred_prob"],
            },
            "impossible_zeros_as_nan": {
                "roc_auc": res_clean["roc_auc"],
                "pr_auc": res_clean["pr_auc"],
                "brier": res_clean["brier"],
                "ece_10bin": res_clean["ece_10bin"],
                "log_loss": res_clean["log_loss"],
                "mean_pred_prob": res_clean["mean_pred_prob"],
            },
        }
    return summary


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Export dual-mode model.json v2 and golden_cases.json v2.")
    parser.add_argument(
        "--allow-missing-external",
        action="store_true",
        help="Allow exporting model.json without docs/evaluation_metrics.json external validation.",
    )
    args = parser.parse_args(argv)

    ext_summary = load_external_validation_summary(allow_missing_external=args.allow_missing_external)

    df_full = pd.read_csv(DATA)
    X_all = df_full.drop(columns="target")
    y_all = df_full["target"]
    X_train, X_test, y_train, y_test = load_split(str(DATA))
    print(f"train={X_train.shape}  test={X_test.shape}  sklearn={sklearn.__version__}")

    full_block, pipe_full = export_single_mode(
        "full_13",
        "13-feature Cleveland Logistic Regression (5 numeric + 8 categorical including ca and thal).",
        CAT_COLS_FULL,
        X_train,
        X_test,
        y_train,
        y_test,
        X_all,
        y_all,
    )
    ni_block, pipe_ni = export_single_mode(
        "non_invasive_11",
        "11-feature non-invasive Cleveland Logistic Regression (5 numeric + 6 categorical; excludes ca and thal).",
        CAT_COLS_NON_INVASIVE,
        X_train,
        X_test,
        y_train,
        y_test,
        X_all,
        y_all,
    )

    top_metadata: dict[str, Any] = {
        "dataset": "UCI Cleveland Heart Disease (N=303; train=242, test=61)",
        "random_state": 42,
        "sklearn_version": sklearn.__version__,
        "c_grid": C_GRID,
        "cv_5fold_train": "StratifiedKFold(n_splits=5, shuffle=True, random_state=42)",
        "cv_10x5_repeated": "RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)",
    }
    if ext_summary is not None:
        top_metadata["external_validation"] = ext_summary
    else:
        print("WARNING: exporting without external_validation (--allow-missing-external enabled).")

    model_json = {
        "schema_version": 2,
        "format": "heart-risk-linear-formula/2",
        "description": (
            "Dual-mode Logistic Regression exported as plain arithmetic formulas. "
            "prob = sigmoid(intercept + sum(coef_i * x_i)). Use non_invasive_11 whenever "
            "ca or thal is missing rather than mode-imputing healthy defaults."
        ),
        "positive_class": 1,
        "positive_class_label": "disease",
        "default_mode": "full_13",
        "routing": {
            "auto": "Use non_invasive_11 when ca is null or thal is null; otherwise use full_13.",
        },
        "risk_bands": {
            "low_max": 0.35,
            "moderate_max": 0.65,
            "note": "Illustrative cut-offs, not validated clinical thresholds.",
        },
        "models": {
            "full_13": full_block,
            "non_invasive_11": ni_block,
        },
        "metadata": top_metadata,
    }

    out_path = OUT_DIR / "model.json"
    out_path.write_text(json.dumps(model_json, indent=2), encoding="utf-8")
    print(f"wrote {out_path}")

    golden = build_golden_cases(
        {"full_13": full_block, "non_invasive_11": ni_block},
        {"full_13": pipe_full, "non_invasive_11": pipe_ni},
        X_test,
        X_all,
    )
    golden_path = OUT_DIR / "golden_cases.json"
    golden_path.write_text(json.dumps(golden, indent=2), encoding="utf-8")
    print(f"wrote {golden_path}  ({len(golden['cases'])} cases)")


if __name__ == "__main__":
    main()
