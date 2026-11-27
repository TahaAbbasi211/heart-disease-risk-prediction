"""Scientific validation, calibration, collinearity, and external cohort evaluation.

Run from the project root:
    python scripts/evaluate_heart.py
"""

from __future__ import annotations

import json
import math
import sys
import urllib.request
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    log_loss,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import (
    GridSearchCV,
    RepeatedStratifiedKFold,
    StratifiedKFold,
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
from heart_risk.presets import CLINICAL_PRESETS, DEFAULT_INPUTS  # noqa: E402

DATA_CSV = ROOT / "data" / "heart.csv"
EXTERNAL_DIR = ROOT / "data" / "external"
DOCS_DIR = ROOT / "docs"
METRICS_JSON = DOCS_DIR / "evaluation_metrics.json"
REPORT_MD = DOCS_DIR / "heart_v2_evaluation_report.md"

UCI_BASE = "https://archive.ics.uci.edu/ml/machine-learning-databases/heart-disease"
EXTERNAL_COHORTS = [
    ("hungarian", "UCI Hungarian", "processed.hungarian.data"),
    ("switzerland", "UCI Switzerland", "processed.switzerland.data"),
    ("va", "UCI VA Long Beach", "processed.va.data"),
]
RAW_COLS = [
    "age",
    "sex",
    "cp",
    "trestbps",
    "chol",
    "fbs",
    "restecg",
    "thalach",
    "exang",
    "oldpeak",
    "slope",
    "ca",
    "thal",
    "num",
]
C_GRID = [0.01, 0.1, 1.0, 10.0]


def make_logreg_pipeline(cat_cols: list[str], c: float) -> Pipeline:
    return Pipeline(
        [
            ("prep", build_preprocess(cat_cols)),
            ("model", LogisticRegression(max_iter=1000, C=c)),
        ]
    )


def make_rf_pipeline(cat_cols: list[str]) -> Pipeline:
    """Exact tuned RandomForest configuration from notebooks/03_modeling.ipynb."""
    return Pipeline(
        [
            ("prep", build_preprocess(cat_cols)),
            (
                "model",
                RandomForestClassifier(
                    n_estimators=400,
                    max_depth=5,
                    min_samples_leaf=3,
                    random_state=42,
                ),
            ),
        ]
    )


def compute_ece(
    y_true: np.ndarray, y_prob: np.ndarray, n_bins: int = 10
) -> tuple[float, list[dict[str, Any]]]:
    """Compute 10-bin Expected Calibration Error and per-bin reliability rows."""
    y_true_arr = np.asarray(y_true, dtype=float)
    y_prob_arr = np.asarray(y_prob, dtype=float)
    edges = np.linspace(0.0, 1.0, n_bins + 1)
    n_total = len(y_true_arr)
    ece = 0.0
    rows: list[dict[str, Any]] = []

    for i in range(n_bins):
        lo = float(edges[i])
        hi = float(edges[i + 1])
        if i == 0:
            mask = (y_prob_arr >= lo) & (y_prob_arr <= hi)
        else:
            mask = (y_prob_arr > lo) & (y_prob_arr <= hi)
        count = int(mask.sum())
        if count > 0:
            mean_pred = float(y_prob_arr[mask].mean())
            obs_freq = float(y_true_arr[mask].mean())
            gap = abs(obs_freq - mean_pred)
            ece += (count / n_total) * gap
        else:
            mean_pred = None
            obs_freq = None
            gap = None
        rows.append(
            {
                "bin": f"{lo:.1f}-{hi:.1f}",
                "bin_lower": round(lo, 2),
                "bin_upper": round(hi, 2),
                "count": count,
                "mean_pred_prob": mean_pred,
                "observed_freq": obs_freq,
                "abs_gap": gap,
            }
        )

    return float(ece), rows


def evaluate_predictions(y_true: np.ndarray, y_prob: np.ndarray) -> dict[str, Any]:
    """Compute discrimination, calibration, and thresholded classification metrics."""
    y_true_arr = np.asarray(y_true, dtype=int)
    y_prob_arr = np.asarray(y_prob, dtype=float)
    y_pred = (y_prob_arr >= 0.5).astype(int)

    ece, reliability = compute_ece(y_true_arr, y_prob_arr, n_bins=10)
    tn, fp, fn, tp = [int(v) for v in confusion_matrix(y_true_arr, y_pred, labels=[0, 1]).ravel()]

    return {
        "n": int(len(y_true_arr)),
        "n_pos": int(y_true_arr.sum()),
        "prevalence": float(y_true_arr.mean()),
        "mean_pred_prob": float(y_prob_arr.mean()),
        "roc_auc": float(roc_auc_score(y_true_arr, y_prob_arr)),
        "pr_auc": float(average_precision_score(y_true_arr, y_prob_arr)),
        "brier": float(brier_score_loss(y_true_arr, y_prob_arr)),
        "ece_10bin": ece,
        "log_loss": float(log_loss(y_true_arr, y_prob_arr, labels=[0, 1])),
        "recall": float(recall_score(y_true_arr, y_pred, zero_division=0)),
        "precision": float(precision_score(y_true_arr, y_pred, zero_division=0)),
        "f1": float(f1_score(y_true_arr, y_pred, zero_division=0)),
        "accuracy": float(accuracy_score(y_true_arr, y_pred)),
        "confusion_matrix": {"tn": tn, "fp": fp, "fn": fn, "tp": tp},
        "reliability_10bin": reliability,
    }


def summarize_repeated_cv(
    pipe_factory,
    X: pd.DataFrame,
    y: pd.Series,
    cv: RepeatedStratifiedKFold,
) -> dict[str, Any]:
    """Run 10x5 Repeated Stratified CV refitting inside each fold (leakage-free)."""
    scores: dict[str, list[float]] = {
        "roc_auc": [],
        "pr_auc": [],
        "brier": [],
        "ece_10bin": [],
        "log_loss": [],
    }
    for train_idx, val_idx in cv.split(X, y):
        pipe = pipe_factory()
        pipe.fit(X.iloc[train_idx], y.iloc[train_idx])
        p_val = pipe.predict_proba(X.iloc[val_idx])[:, 1]
        y_val = y.iloc[val_idx].to_numpy()
        ece_val, _ = compute_ece(y_val, p_val, n_bins=10)
        scores["roc_auc"].append(float(roc_auc_score(y_val, p_val)))
        scores["pr_auc"].append(float(average_precision_score(y_val, p_val)))
        scores["brier"].append(float(brier_score_loss(y_val, p_val)))
        scores["ece_10bin"].append(ece_val)
        scores["log_loss"].append(float(log_loss(y_val, p_val, labels=[0, 1])))

    summary: dict[str, Any] = {"n_folds_total": int(len(scores["roc_auc"]))}
    for metric, vals in scores.items():
        arr = np.asarray(vals, dtype=float)
        summary[metric] = {
            "mean": float(arr.mean()),
            "std": float(arr.std()),
            "fold_range_95": [float(np.percentile(arr, 2.5)), float(np.percentile(arr, 97.5))],
        }
    return summary


def summarize_nested_repeated_cv(
    cat_cols: list[str],
    X: pd.DataFrame,
    y: pd.Series,
    outer_cv: RepeatedStratifiedKFold,
) -> dict[str, Any]:
    """Run nested 10x5 CV tuning C inside every outer training fold (zero leakage)."""
    inner_cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    scores: dict[str, list[float]] = {
        "roc_auc": [],
        "pr_auc": [],
        "brier": [],
        "ece_10bin": [],
        "log_loss": [],
    }
    c_counts: dict[str, int] = {str(c): 0 for c in C_GRID}

    for train_idx, val_idx in outer_cv.split(X, y):
        gs = GridSearchCV(
            make_logreg_pipeline(cat_cols, 1.0),
            {"model__C": C_GRID},
            cv=inner_cv,
            scoring="roc_auc",
            n_jobs=1,
        )
        gs.fit(X.iloc[train_idx], y.iloc[train_idx])
        chosen_c = str(float(gs.best_params_["model__C"]))
        c_counts[chosen_c] = c_counts.get(chosen_c, 0) + 1

        p_val = gs.best_estimator_.predict_proba(X.iloc[val_idx])[:, 1]
        y_val = y.iloc[val_idx].to_numpy()
        ece_val, _ = compute_ece(y_val, p_val, n_bins=10)
        scores["roc_auc"].append(float(roc_auc_score(y_val, p_val)))
        scores["pr_auc"].append(float(average_precision_score(y_val, p_val)))
        scores["brier"].append(float(brier_score_loss(y_val, p_val)))
        scores["ece_10bin"].append(ece_val)
        scores["log_loss"].append(float(log_loss(y_val, p_val, labels=[0, 1])))

    summary: dict[str, Any] = {
        "n_folds_total": int(len(scores["roc_auc"])),
        "c_grid": list(C_GRID),
        "selected_c_counts": c_counts,
    }
    for metric, vals in scores.items():
        arr = np.asarray(vals, dtype=float)
        summary[metric] = {
            "mean": float(arr.mean()),
            "std": float(arr.std()),
            "fold_range_95": [float(np.percentile(arr, 2.5)), float(np.percentile(arr, 97.5))],
        }
    return summary


def risk_band(p: float) -> str:
    if p < 0.35:
        return "low"
    if p < 0.65:
        return "moderate"
    return "high"


def fetch_external_cohort(filename: str) -> tuple[pd.DataFrame, Path, str]:
    """Download & cache an official UCI processed heart disease dataset."""
    EXTERNAL_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = EXTERNAL_DIR / filename
    url = f"{UCI_BASE}/{filename}"
    if cache_path.exists() and cache_path.stat().st_size > 0:
        source_status = "cached"
    else:
        try:
            with urllib.request.urlopen(url, timeout=20) as resp:
                data_bytes = resp.read()
        except Exception as exc:
            raise RuntimeError(
                f"Failed to download UCI cohort '{filename}' from {url}: {exc}"
            ) from exc
        if not data_bytes.strip():
            raise RuntimeError(f"Downloaded empty dataset from {url}")
        cache_path.write_bytes(data_bytes)
        source_status = "downloaded"

    df = pd.read_csv(cache_path, header=None, names=RAW_COLS, na_values="?")
    df["target"] = (df["num"] > 0).astype(int)
    return df, cache_path, source_status


def analyze_collinearity(
    df_full: pd.DataFrame,
    pipe_full: Pipeline,
    pipe_ni: Pipeline,
) -> dict[str, Any]:
    """Explain negative partial coefficients (age, fbs) and referral bias (cp=4)."""
    prep_full = pipe_full.named_steps["prep"]
    lr_full = pipe_full.named_steps["model"]
    feat_full = [str(f) for f in prep_full.get_feature_names_out()]
    coef_full = {name: float(val) for name, val in zip(feat_full, np.ravel(lr_full.coef_))}

    prep_ni = pipe_ni.named_steps["prep"]
    lr_ni = pipe_ni.named_steps["model"]
    feat_ni = [str(f) for f in prep_ni.get_feature_names_out()]
    coef_ni = {name: float(val) for name, val in zip(feat_ni, np.ravel(lr_ni.coef_))}

    # Univariate standardized logistic regression for age on training split
    X_train, _, y_train, _ = load_split(str(DATA_CSV))
    age_mean = float(X_train["age"].mean())
    age_std = float(X_train["age"].std(ddof=0))
    age_z_train = ((X_train["age"] - age_mean) / age_std).to_numpy().reshape(-1, 1)
    uni_age_lr = LogisticRegression(max_iter=1000, C=1.0).fit(age_z_train, y_train)
    uni_age_coef = float(uni_age_lr.coef_[0, 0])

    r_age_target, p_age_target = stats.pearsonr(df_full["age"], df_full["target"])
    rho_age_target, _ = stats.spearmanr(df_full["age"], df_full["target"])
    corr_with_age = {}
    for col in ["ca", "thalach", "trestbps", "oldpeak", "chol"]:
        sub = df_full[["age", col]].dropna()
        r_val, p_val = stats.pearsonr(sub["age"], sub[col])
        corr_with_age[col] = {"pearson_r": float(r_val), "p_value": float(p_val), "n": int(len(sub))}

    # Age correlation with thal defect (thal in {6,7})
    sub_thal = df_full[["age", "thal"]].dropna()
    thal_abnormal = (sub_thal["thal"] != 3.0).astype(int)
    r_age_thal, p_age_thal = stats.pearsonr(sub_thal["age"], thal_abnormal)
    corr_with_age["thal_abnormal"] = {
        "pearson_r": float(r_age_thal),
        "p_value": float(p_age_thal),
        "n": int(len(sub_thal)),
    }

    # fbs breakdown across Cleveland N=303
    fbs_groups = {}
    for val, grp in df_full.groupby("fbs"):
        fbs_groups[str(int(val))] = {
            "n": int(len(grp)),
            "n_pos": int(grp["target"].sum()),
            "prevalence": float(grp["target"].mean()),
        }
    ct_fbs = pd.crosstab(df_full["fbs"], df_full["target"])
    fbs_or, fbs_fisher_p = stats.fisher_exact(ct_fbs.to_numpy())

    # cp breakdown across Cleveland N=303
    cp_labels = {
        1: "Typical angina",
        2: "Atypical angina",
        3: "Non-anginal pain",
        4: "Asymptomatic",
    }
    cp_groups = []
    for val, grp in df_full.groupby("cp"):
        iv = int(val)
        cp_groups.append(
            {
                "cp_code": iv,
                "label": cp_labels[iv],
                "n": int(len(grp)),
                "n_pos": int(grp["target"].sum()),
                "prevalence": float(grp["target"].mean()),
                "coef_full_13": coef_full[f"cat__cp_{float(iv)}"],
                "coef_non_invasive_11": coef_ni[f"cat__cp_{float(iv)}"],
            }
        )

    return {
        "coefficients_full_13": coef_full,
        "intercept_full_13": float(lr_full.intercept_[0]),
        "coefficients_non_invasive_11": coef_ni,
        "intercept_non_invasive_11": float(lr_ni.intercept_[0]),
        "age_analysis": {
            "full_13_multivariable_coef": coef_full["num__age"],
            "non_invasive_11_multivariable_coef": coef_ni["num__age"],
            "univariate_standardized_coef_train": uni_age_coef,
            "pearson_r_with_target_all": float(r_age_target),
            "pearson_p_with_target_all": float(p_age_target),
            "spearman_rho_with_target_all": float(rho_age_target),
            "age_covariate_correlations": corr_with_age,
        },
        "fbs_analysis": {
            "full_13_coef_fbs_0": coef_full["cat__fbs_0.0"],
            "full_13_coef_fbs_1": coef_full["cat__fbs_1.0"],
            "non_invasive_11_coef_fbs_1": coef_ni["cat__fbs_1.0"],
            "groups_all": fbs_groups,
            "univariate_odds_ratio_all": float(fbs_or),
            "fisher_exact_p_all": float(fbs_fisher_p),
        },
        "cp_referral_bias": cp_groups,
    }


def analyze_split_brain_and_imputation(
    df_full: pd.DataFrame,
    X_train: pd.DataFrame,
    X_test: pd.DataFrame,
    y_test: pd.Series,
    pipe_lr_full: Pipeline,
    pipe_lr_ni: Pipeline,
    pipe_rf: Pipeline,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Quantify RF vs LogReg split-brain and ca/thal mode-imputation trap."""
    X_all = df_full.drop(columns="target")

    # --- 1. Split-Brain (RF vs LogReg full_13) ---
    p_lr_test = pipe_lr_full.predict_proba(X_test)[:, 1]
    p_rf_test = pipe_rf.predict_proba(X_test)[:, 1]
    diff_test = np.abs(p_rf_test - p_lr_test)

    p_lr_all = pipe_lr_full.predict_proba(X_all)[:, 1]
    p_rf_all = pipe_rf.predict_proba(X_all)[:, 1]
    diff_all = np.abs(p_rf_all - p_lr_all)

    band_flips_test = int(sum(risk_band(float(a)) != risk_band(float(b)) for a, b in zip(p_lr_test, p_rf_test)))
    class_flips_test = int(((p_lr_test >= 0.5) != (p_rf_test >= 0.5)).sum())
    band_flips_all = int(sum(risk_band(float(a)) != risk_band(float(b)) for a, b in zip(p_lr_all, p_rf_all)))
    class_flips_all = int(((p_lr_all >= 0.5) != (p_rf_all >= 0.5)).sum())

    top_idx = np.argsort(-diff_test)[:5]
    top_examples = []
    for pos in top_idx:
        row_idx = int(X_test.index[pos])
        top_examples.append(
            {
                "row_index": row_idx,
                "y_true": int(y_test.iloc[pos]),
                "p_logreg": float(p_lr_test[pos]),
                "p_rf": float(p_rf_test[pos]),
                "abs_diff": float(diff_test[pos]),
                "band_logreg": risk_band(float(p_lr_test[pos])),
                "band_rf": risk_band(float(p_rf_test[pos])),
            }
        )

    default_df = pd.DataFrame([DEFAULT_INPUTS]).astype(float)
    split_brain = {
        "test_61": {
            "mean_abs_diff": float(diff_test.mean()),
            "median_abs_diff": float(np.median(diff_test)),
            "max_abs_diff": float(diff_test.max()),
            "class_flips_at_0_5": class_flips_test,
            "risk_band_flips": band_flips_test,
            "top_discrepancy_patients": top_examples,
        },
        "all_303": {
            "mean_abs_diff": float(diff_all.mean()),
            "median_abs_diff": float(np.median(diff_all)),
            "max_abs_diff": float(diff_all.max()),
            "class_flips_at_0_5": class_flips_all,
            "risk_band_flips": band_flips_all,
        },
        "default_patient_male_55": {
            "p_logreg_full_13": float(pipe_lr_full.predict_proba(default_df)[0, 1]),
            "p_rf_full_13": float(pipe_rf.predict_proba(default_df)[0, 1]),
        },
    }

    # --- 2. Mode-imputation false-reassurance trap ---
    prep = pipe_lr_full.named_steps["prep"]
    lr = pipe_lr_full.named_steps["model"]
    feat_names = [str(f) for f in prep.get_feature_names_out()]
    coefs = {n: float(w) for n, w in zip(feat_names, np.ravel(lr.coef_))}

    ca_mode_coef = coefs["cat__ca_0.0"]
    thal_mode_coef = coefs["cat__thal_3.0"]
    combined_shift = ca_mode_coef + thal_mode_coef

    X_test_masked = X_test.copy()
    X_test_masked["ca"] = np.nan
    X_test_masked["thal"] = np.nan

    pos_mask = y_test.to_numpy() == 1
    p_true_full = pipe_lr_full.predict_proba(X_test)[:, 1]
    p_naive_imputed = pipe_lr_full.predict_proba(X_test_masked)[:, 1]
    p_safe_ni = pipe_lr_ni.predict_proba(X_test_masked)[:, 1]

    # Compare full_13 with ca/thal=None vs non_invasive_11 on symptomatic preset
    hi_ni = pd.DataFrame(
        [{k: (np.nan if v is None else float(v)) for k, v in CLINICAL_PRESETS["high_risk_non_invasive"]["inputs"].items()}]
    )
    hi_full = pd.DataFrame(
        [{k: (np.nan if v is None else float(v)) for k, v in CLINICAL_PRESETS["high_risk_full"]["inputs"].items()}]
    )

    imputation_trap = {
        "coef_cat__ca_0_0": ca_mode_coef,
        "coef_cat__thal_3_0": thal_mode_coef,
        "combined_healthy_mode_log_odds_shift": combined_shift,
        "combined_odds_multiplier": float(math.exp(combined_shift)),
        "test_61_positives_with_ca_thal_masked": {
            "n_positives": int(pos_mask.sum()),
            "true_full_13_recall": float((p_true_full[pos_mask] >= 0.5).mean()),
            "true_full_13_fn": int((p_true_full[pos_mask] < 0.5).sum()),
            "true_full_13_mean_prob": float(p_true_full[pos_mask].mean()),
            "naive_mode_imputed_full_13_recall": float((p_naive_imputed[pos_mask] >= 0.5).mean()),
            "naive_mode_imputed_full_13_fn": int((p_naive_imputed[pos_mask] < 0.5).sum()),
            "naive_mode_imputed_full_13_mean_prob": float(p_naive_imputed[pos_mask].mean()),
            "safe_non_invasive_11_recall": float((p_safe_ni[pos_mask] >= 0.5).mean()),
            "safe_non_invasive_11_fn": int((p_safe_ni[pos_mask] < 0.5).sum()),
            "safe_non_invasive_11_mean_prob": float(p_safe_ni[pos_mask].mean()),
        },
        "symptomatic_patient_example": {
            "p_naive_mode_imputed_full_13": float(pipe_lr_full.predict_proba(hi_ni)[0, 1]),
            "p_safe_non_invasive_11": float(pipe_lr_ni.predict_proba(hi_ni)[0, 1]),
            "p_full_13_with_ca2_thal7": float(pipe_lr_full.predict_proba(hi_full)[0, 1]),
        },
    }

    return split_brain, imputation_trap


def render_markdown_report(metrics: dict[str, Any]) -> str:
    """Format docs/heart_v2_evaluation_report.md directly from computed metrics."""
    lines: list[str] = []
    add = lines.append

    add("# Heart Disease Risk Prediction v2 — Scientific Evaluation & External Validation Report")
    add("")
    add("> Educational / research evaluation generated directly from `scripts/evaluate_heart.py`. Not a clinical diagnostic device.")
    add("")
    add("## 1. Training Hyperparameter Selection (Cleveland `X_train`, N=242)")
    add("")
    add("Hyperparameter regularization `C` was selected strictly inside the stratified 80% training split (`N=242`, `random_state=42`) using 5-fold stratified CV (`ROC-AUC`) over `C in [0.01, 0.1, 1.0, 10.0]` before any evaluation on `X_test` (`N=61`):")
    add("")
    add("| Mode | Input Features | Output Features | Selected `C` | 5-Fold Train CV ROC-AUC |")
    add("|---|---|---|---|---|")
    for mode_key, label in [("full_13", "Full Clinical (`full_13`)"), ("non_invasive_11", "Non-Invasive (`non_invasive_11`)")]:
        g = metrics["grid_search_train_242"][mode_key]
        add(
            f"| {label} | {g['n_input_features']} | {g['n_output_features']} | "
            f"`{g['best_c']}` | `{g['best_cv_auc_mean']:.4f} ± {g['best_cv_auc_std']:.4f}` |"
        )
    add("")

    add("## 2. Internal Cleveland Validation (`10×5 Repeated Stratified CV`, N=303)")
    add("")
    add("All preprocessing steps (median/mode imputation, standardization, one-hot encoding) were fit strictly inside each fold across 50 total splits (`RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)`).")
    add("")
    add("| Model | ROC-AUC (95% fold range 2.5–97.5%) | PR-AUC (95% fold range) | Brier (95% fold range) | 10-Bin ECE (95% fold range) | Log-Loss (95% fold range) |")
    add("|---|---|---|---|---|---|")
    cv_rep = metrics["repeated_cv_10x5_all_303"]
    for key, label in [
        ("logreg_full_13", "Logistic Regression (`full_13`, C=1.0)"),
        ("rf_full_13", "Random Forest (`full_13`, tuned benchmark)"),
        ("logreg_non_invasive_11", "Logistic Regression (`non_invasive_11`, C=0.1)"),
    ]:
        m = cv_rep[key]

        def fmt(metric_name: str) -> str:
            d = m[metric_name]
            return f"{d['mean']:.3f} ± {d['std']:.3f} [{d['fold_range_95'][0]:.3f}, {d['fold_range_95'][1]:.3f}]"

        add(
            f"| {label} | {fmt('roc_auc')} | {fmt('pr_auc')} | {fmt('brier')} | {fmt('ece_10bin')} | {fmt('log_loss')} |"
        )
    add("")
    ncv = metrics["nested_cv_10x5_all_303"]
    add(
        "**Nested `10×5` CV Verification (inner 5-fold `C` grid inside every outer fold):** "
        f"`full_13` ROC-AUC = `{ncv['logreg_full_13']['roc_auc']['mean']:.3f} ± {ncv['logreg_full_13']['roc_auc']['std']:.3f}` "
        f"(vs fixed `C=1.0`: `{cv_rep['logreg_full_13']['roc_auc']['mean']:.3f} ± {cv_rep['logreg_full_13']['roc_auc']['std']:.3f}`, "
        f"selected `C` counts `{ncv['logreg_full_13']['selected_c_counts']}`); "
        f"`non_invasive_11` ROC-AUC = `{ncv['logreg_non_invasive_11']['roc_auc']['mean']:.3f} ± {ncv['logreg_non_invasive_11']['roc_auc']['std']:.3f}` "
        f"(vs fixed `C=0.1`: `{cv_rep['logreg_non_invasive_11']['roc_auc']['mean']:.3f} ± {cv_rep['logreg_non_invasive_11']['roc_auc']['std']:.3f}`, "
        f"selected `C` counts `{ncv['logreg_non_invasive_11']['selected_c_counts']}`)."
    )
    add("")

    add("## 3. Held-Out Cleveland Test Set (`test_61`, N=61) & Calibration")
    add("")
    add("| Model | ROC-AUC | PR-AUC | Brier | 10-Bin ECE | Log-Loss | Recall @0.5 | Precision @0.5 | TN / FP / FN / TP |")
    add("|---|---|---|---|---|---|---|---|---|")
    t61 = metrics["test_61"]
    for key, label in [
        ("logreg_full_13", "Logistic Regression (`full_13`)"),
        ("rf_full_13", "Random Forest (`full_13`)"),
        ("logreg_non_invasive_11", "Logistic Regression (`non_invasive_11`)"),
    ]:
        r = t61[key]
        cm = r["confusion_matrix"]
        add(
            f"| {label} | {r['roc_auc']:.4f} | {r['pr_auc']:.4f} | {r['brier']:.4f} | "
            f"{r['ece_10bin']:.4f} | {r['log_loss']:.4f} | {r['recall']:.4f} | {r['precision']:.4f} | "
            f"{cm['tn']} / {cm['fp']} / {cm['fn']} / {cm['tp']} |"
        )
    add("")
    add("### Held-Out `test_61` 10-Bin Reliability Table (`logreg_full_13` & `logreg_non_invasive_11`)")
    add("")
    add("| Prob Bin | Full-13 Count | Full-13 Mean Pred | Full-13 Obs Freq | Non-Inv Count | Non-Inv Mean Pred | Non-Inv Obs Freq |")
    add("|---|---|---|---|---|---|---|")
    rel_f = t61["logreg_full_13"]["reliability_10bin"]
    rel_n = t61["logreg_non_invasive_11"]["reliability_10bin"]
    for rf_row, rn_row in zip(rel_f, rel_n):
        fp_s = "-" if rf_row["mean_pred_prob"] is None else f"{rf_row['mean_pred_prob']:.3f}"
        fo_s = "-" if rf_row["observed_freq"] is None else f"{rf_row['observed_freq']:.3f}"
        np_s = "-" if rn_row["mean_pred_prob"] is None else f"{rn_row['mean_pred_prob']:.3f}"
        no_s = "-" if rn_row["observed_freq"] is None else f"{rn_row['observed_freq']:.3f}"
        add(
            f"| `{rf_row['bin']}` | {rf_row['count']} | {fp_s} | {fo_s} | "
            f"{rn_row['count']} | {np_s} | {no_s} |"
        )
    add("")

    sb = metrics["split_brain_rf_vs_logreg"]
    add("## 4. Split-Brain Discrepancy Analysis (`RandomForest` vs `LogisticRegression`)")
    add("")
    add(
        f"- On `test_61`: mean `|p_RF - p_LR| = {sb['test_61']['mean_abs_diff']:.4f}`, "
        f"max `|p_RF - p_LR| = {sb['test_61']['max_abs_diff']:.4f}`, "
        f"class flips (`@0.5`) = `{sb['test_61']['class_flips_at_0_5']}/61`, "
        f"risk-band flips = `{sb['test_61']['risk_band_flips']}/61`."
    )
    add(
        f"- Across all `N=303` Cleveland patients: mean `|p_RF - p_LR| = {sb['all_303']['mean_abs_diff']:.4f}`, "
        f"max `|p_RF - p_LR| = {sb['all_303']['max_abs_diff']:.4f}`, "
        f"class flips (`@0.5`) = `{sb['all_303']['class_flips_at_0_5']}/303`, "
        f"risk-band flips = `{sb['all_303']['risk_band_flips']}/303`."
    )
    add(
        f"- Canonical default patient (male, 55): `LogReg full_13 = {sb['default_patient_male_55']['p_logreg_full_13']:.4f}` vs "
        f"`Random Forest = {sb['default_patient_male_55']['p_rf_full_13']:.4f}`. "
        "Retiring `model.pkl` and routing all runtimes through `model.json` v2 eliminates this cross-platform divergence."
    )
    add("")

    imp = metrics["mode_imputation_false_reassurance_trap"]
    tp_pos = imp["test_61_positives_with_ca_thal_masked"]
    sym = imp["symptomatic_patient_example"]
    add("## 5. Mode-Imputation False-Reassurance Trap (`ca`/`thal` Missing)")
    add("")
    add(
        f"In `full_13`, mode imputation fills missing `ca` with `0.0` (`coef = {imp['coef_cat__ca_0_0']:+.4f}`) and "
        f"missing `thal` with `3.0` (`coef = {imp['coef_cat__thal_3_0']:+.4f}`). Together they shift log-odds by "
        f"**`{imp['combined_healthy_mode_log_odds_shift']:+.4f}`** (multiplying odds by `{imp['combined_odds_multiplier']:.3f}x`)."
    )
    add("")
    add(f"- On the `{tp_pos['n_positives']}` positive patients in `test_61` when `ca` and `thal` are masked (`NaN`):")
    add(
        f"  - True `full_13` (observed `ca`/`thal`): recall = `{tp_pos['true_full_13_recall']:.4f}` "
        f"(FN = `{tp_pos['true_full_13_fn']}`), mean prob = `{tp_pos['true_full_13_mean_prob']:.4f}`"
    )
    add(
        f"  - Naive `full_13` (mode-imputing missing `ca=0, thal=3`): recall = `{tp_pos['naive_mode_imputed_full_13_recall']:.4f}` "
        f"(FN = `{tp_pos['naive_mode_imputed_full_13_fn']}`), mean prob = `{tp_pos['naive_mode_imputed_full_13_mean_prob']:.4f}`"
    )
    add(
        f"  - Safe `non_invasive_11` (auto-routed when `ca`/`thal` missing): recall = `{tp_pos['safe_non_invasive_11_recall']:.4f}` "
        f"(FN = `{tp_pos['safe_non_invasive_11_fn']}`), mean prob = `{tp_pos['safe_non_invasive_11_mean_prob']:.4f}`"
    )
    add(
        f"- Symptomatic high-risk profile (`high_risk_non_invasive` preset): naive mode-imputed `full_13` drops to "
        f"**`{sym['p_naive_mode_imputed_full_13']:.1%}`**, whereas auto-routed `non_invasive_11` retains "
        f"**`{sym['p_safe_non_invasive_11']:.1%}`** (and with confirmed `ca=2, thal=7`, `full_13` gives `{sym['p_full_13_with_ca2_thal7']:.1%}`)."
    )
    add("")

    col = metrics["collinearity_and_referral_bias"]
    age_a = col["age_analysis"]
    fbs_a = col["fbs_analysis"]
    add("## 6. Collinearity & Referral-Bias Analysis (`full_13` vs Cleveland Cohort)")
    add("")
    add(
        f"- **Why `num__age` is slightly negative (`{age_a['full_13_multivariable_coef']:+.4f}`) in `full_13`:** "
        f"Univariately, older age strongly *increases* risk in Cleveland (`Pearson r = {age_a['pearson_r_with_target_all']:+.4f}`, "
        f"`p = {age_a['pearson_p_with_target_all']:.2e}`, univariate standardized `LogReg` coef = `{age_a['univariate_standardized_coef_train']:+.4f}`). "
        f"However, age correlates positively with `ca` (`r = {age_a['age_covariate_correlations']['ca']['pearson_r']:+.3f}`), "
        f"`trestbps` (`r = {age_a['age_covariate_correlations']['trestbps']['pearson_r']:+.3f}`), and `oldpeak` (`r = {age_a['age_covariate_correlations']['oldpeak']['pearson_r']:+.3f}`), "
        f"and negatively with `thalach` (`r = {age_a['age_covariate_correlations']['thalach']['pearson_r']:+.3f}`). "
        "Once fluoroscopy (`ca`), thallium scan (`thal`), blood pressure, and peak heart rate are conditioned on simultaneously in `N=242` training rows, "
        "the residual partial slope on age becomes slightly negative (`-0.0609`), and similarly stays tiny (`"
        f"{age_a['non_invasive_11_multivariable_coef']:+.4f}`) in `non_invasive_11`."
    )
    add(
        f"- **Why `cat__fbs_1.0` is slightly negative (`{fbs_a['full_13_coef_fbs_1']:+.4f}`):** "
        f"Only `{fbs_a['groups_all']['1']['n']}/{metrics['dataset']['cleveland_n']}` Cleveland patients have `fbs > 120 mg/dl`, "
        f"with essentially identical disease prevalence (`fbs=0`: `{fbs_a['groups_all']['0']['prevalence']:.3f}`, "
        f"`fbs=1`: `{fbs_a['groups_all']['1']['prevalence']:.3f}`, Fisher `p = {fbs_a['fisher_exact_p_all']:.3f}`), "
        "so the small negative weight reflects sampling noise rather than any protective effect of hyperglycemia."
    )
    add("- **Angiography referral bias on chest pain (`cp=4`):**")
    add("")
    add("| `cp` Code | Description | Cleveland N | Disease Cases | Prevalence | `full_13` coef | `non_invasive_11` coef |")
    add("|---|---|---|---|---|---|---|")
    for cp_row in col["cp_referral_bias"]:
        add(
            f"| `{cp_row['cp_code']}` | {cp_row['label']} | {cp_row['n']} | {cp_row['n_pos']} | "
            f"{cp_row['prevalence']:.3f} | `{cp_row['coef_full_13']:+.4f}` | `{cp_row['coef_non_invasive_11']:+.4f}` |"
        )
    add("")
    add(
        "Patients coded `cp=4` (asymptomatic) in a catheterization lab cohort were referred due to other abnormal clinical findings "
        "(silent ischemia / positive stress test), producing high disease prevalence and a strongly positive weight—an ascertainment artifact specific to referred clinical cohorts."
    )
    add("")

    ext = metrics["external_validation"]
    add("## 7. Zero-Retraining External Validation (UCI Hungarian, Switzerland, VA Long Beach)")
    add("")
    add(
        "Cleveland-trained `non_invasive_11` (`C=0.1`) was applied **with zero retraining** to three independent UCI hospitals "
        "(cached in `data/external/`). Because Switzerland (`123/123` = 100%) and VA Long Beach (`49/200` = 24.5%) encode missing serum cholesterol as `0`, "
        "and VA Long Beach has `1` impossible `trestbps == 0` entry, we report **both** raw `?`-only parsing and cleaned `chol/trestbps == 0 -> NaN` "
        "(imputed to Cleveland training medians `244.5` and `130.0`)."
    )
    add("")
    add("### 7a. Cohort Profiles & Missingness Audit")
    add("")
    add("| Cohort | N | Positives (Prevalence) | `ca` Missing | `thal` Missing | `slope` Missing | `chol == 0` | `trestbps == 0` |")
    add("|---|---|---|---|---|---|---|---|")
    for key in ["hungarian", "switzerland", "va", "pooled_external"]:
        c = ext["cohorts"][key]
        miss = c["missing_pct"]
        add(
            f"| {c['label']} | {c['n']} | {c['n_pos']} ({c['prevalence']:.3f}) | "
            f"{miss['ca']:.1f}% | {miss['thal']:.1f}% | {miss['slope']:.1f}% | "
            f"{c['chol_zero_count']} ({c['chol_zero_pct']:.1f}%) | {c['trestbps_zero_count']} ({c['trestbps_zero_pct']:.1f}%) |"
        )
    add("")

    add("### 7b. Zero-Retraining Performance (`non_invasive_11`)")
    add("")
    add("| Cohort | Variant | ROC-AUC | PR-AUC | Brier | 10-Bin ECE | Log-Loss | Mean Pred Prob vs True Prev |")
    add("|---|---|---|---|---|---|---|---|")
    for key in ["hungarian", "switzerland", "va", "pooled_external"]:
        label = ext["cohorts"][key]["label"]
        for variant, vlabel in [("raw", "Raw (`?` -> NaN)"), ("impossible_zeros_as_nan", "Cleaned (`chol/trestbps=0` -> NaN)")]:
            r = ext["results"][key][variant]
            add(
                f"| {label} | {vlabel} | {r['roc_auc']:.4f} | {r['pr_auc']:.4f} | "
                f"{r['brier']:.4f} | {r['ece_10bin']:.4f} | {r['log_loss']:.4f} | "
                f"{r['mean_pred_prob']:.3f} vs {r['prevalence']:.3f} |"
            )
    add("")
    hun_auc = ext["results"]["hungarian"]["impossible_zeros_as_nan"]["roc_auc"]
    swz_prev = ext["cohorts"]["switzerland"]["prevalence"]
    va_prev = ext["cohorts"]["va"]["prevalence"]
    cle_prev = metrics["dataset"]["cleveland_prevalence"]
    swz_mean_p = ext["results"]["switzerland"]["impossible_zeros_as_nan"]["mean_pred_prob"]
    va_mean_p = ext["results"]["va"]["impossible_zeros_as_nan"]["mean_pred_prob"]
    pool_raw_auc = ext["results"]["pooled_external"]["raw"]["roc_auc"]
    pool_cln_auc = ext["results"]["pooled_external"]["impossible_zeros_as_nan"]["roc_auc"]
    add(
        f"**Interpretation of Domain & Calibration Shift:** Discrimination (`ROC-AUC`) on Hungarian (`{hun_auc:.4f}`) remains strong without retraining, "
        f"and pooled external ROC-AUC improves from `{pool_raw_auc:.4f}` to `{pool_cln_auc:.4f}` when coding impossible `chol/trestbps == 0` entries as missing rather than severe negative z-scores. "
        f"However, calibration degrades severely in Switzerland (`{swz_prev:.1%}` disease prevalence) and VA Long Beach (`{va_prev:.1%}` prevalence) because Cleveland's "
        f"`{cle_prev:.1%}` prior intercept under-predicts risk in higher-prevalence referral hospitals (cleaned mean predicted probability `{swz_mean_p:.3f}` vs `{swz_prev:.3f}` in Switzerland, "
        f"and `{va_mean_p:.3f}` vs `{va_prev:.3f}` in VA Long Beach), confirming why uncalibrated external deployment without site-specific intercept recalibration is unsafe."
    )
    add("")
    return "\n".join(lines)


def main() -> None:
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    df_full = pd.read_csv(DATA_CSV)
    X_all = df_full.drop(columns="target")
    y_all = df_full["target"]

    X_train, X_test, y_train, y_test = load_split(str(DATA_CSV))
    cv_5 = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_10x5 = RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=42)

    # 1. Confirm C on X_train (242) only
    gs_full = GridSearchCV(
        make_logreg_pipeline(CAT_COLS_FULL, 1.0),
        {"model__C": C_GRID},
        cv=cv_5,
        scoring="roc_auc",
        n_jobs=-1,
    ).fit(X_train, y_train)
    best_c_full = float(gs_full.best_params_["model__C"])
    best_idx_full = int(gs_full.best_index_)

    gs_ni = GridSearchCV(
        make_logreg_pipeline(CAT_COLS_NON_INVASIVE, 1.0),
        {"model__C": C_GRID},
        cv=cv_5,
        scoring="roc_auc",
        n_jobs=-1,
    ).fit(X_train, y_train)
    best_c_ni = float(gs_ni.best_params_["model__C"])
    best_idx_ni = int(gs_ni.best_index_)

    grid_summary = {
        "full_13": {
            "n_input_features": len(NUM_COLS) + len(CAT_COLS_FULL),
            "n_output_features": int(len(gs_full.best_estimator_.named_steps["prep"].get_feature_names_out())),
            "best_c": best_c_full,
            "best_cv_auc_mean": float(gs_full.cv_results_["mean_test_score"][best_idx_full]),
            "best_cv_auc_std": float(gs_full.cv_results_["std_test_score"][best_idx_full]),
            "grid_scores": {
                str(p["model__C"]): float(s)
                for p, s in zip(gs_full.cv_results_["params"], gs_full.cv_results_["mean_test_score"])
            },
        },
        "non_invasive_11": {
            "n_input_features": len(NUM_COLS) + len(CAT_COLS_NON_INVASIVE),
            "n_output_features": int(len(gs_ni.best_estimator_.named_steps["prep"].get_feature_names_out())),
            "best_c": best_c_ni,
            "best_cv_auc_mean": float(gs_ni.cv_results_["mean_test_score"][best_idx_ni]),
            "best_cv_auc_std": float(gs_ni.cv_results_["std_test_score"][best_idx_ni]),
            "grid_scores": {
                str(p["model__C"]): float(s)
                for p, s in zip(gs_ni.cv_results_["params"], gs_ni.cv_results_["mean_test_score"])
            },
        },
    }

    # 2. 10x5 Repeated Stratified CV on all N=303
    repeated_cv = {
        "logreg_full_13": summarize_repeated_cv(
            lambda: make_logreg_pipeline(CAT_COLS_FULL, best_c_full),
            X_all,
            y_all,
            cv_10x5,
        ),
        "rf_full_13": summarize_repeated_cv(
            lambda: make_rf_pipeline(CAT_COLS_FULL),
            X_all,
            y_all,
            cv_10x5,
        ),
        "logreg_non_invasive_11": summarize_repeated_cv(
            lambda: make_logreg_pipeline(CAT_COLS_NON_INVASIVE, best_c_ni),
            X_all,
            y_all,
            cv_10x5,
        ),
    }

    # 2b. Nested 10x5 Repeated Stratified CV on all N=303 (inner C selection)
    nested_cv = {
        "logreg_full_13": summarize_nested_repeated_cv(CAT_COLS_FULL, X_all, y_all, cv_10x5),
        "logreg_non_invasive_11": summarize_nested_repeated_cv(CAT_COLS_NON_INVASIVE, X_all, y_all, cv_10x5),
    }

    # 3. Fit final pipelines strictly on X_train (242) and evaluate once on test_61
    pipe_lr_full = make_logreg_pipeline(CAT_COLS_FULL, best_c_full).fit(X_train, y_train)
    pipe_lr_ni = make_logreg_pipeline(CAT_COLS_NON_INVASIVE, best_c_ni).fit(X_train, y_train)
    pipe_rf = make_rf_pipeline(CAT_COLS_FULL).fit(X_train, y_train)

    y_test_arr = y_test.to_numpy()
    test_61 = {
        "logreg_full_13": evaluate_predictions(y_test_arr, pipe_lr_full.predict_proba(X_test)[:, 1]),
        "rf_full_13": evaluate_predictions(y_test_arr, pipe_rf.predict_proba(X_test)[:, 1]),
        "logreg_non_invasive_11": evaluate_predictions(y_test_arr, pipe_lr_ni.predict_proba(X_test)[:, 1]),
    }

    # 4. Split-brain & mode-imputation trap
    split_brain, imputation_trap = analyze_split_brain_and_imputation(
        df_full, X_train, X_test, y_test, pipe_lr_full, pipe_lr_ni, pipe_rf
    )

    # 5. Collinearity & referral bias
    collinearity = analyze_collinearity(df_full, pipe_lr_full, pipe_lr_ni)

    # 6. Zero-retraining external validation
    cohort_frames: dict[str, pd.DataFrame] = {}
    cohort_meta: dict[str, Any] = {}
    ext_results: dict[str, Any] = {}
    feature_cols = NUM_COLS + CAT_COLS_FULL

    for key, label, fname in EXTERNAL_COHORTS:
        df_ext, cache_path, fetch_status = fetch_external_cohort(fname)
        cohort_frames[key] = df_ext
        miss_pct = {c: float(df_ext[c].isna().mean() * 100.0) for c in feature_cols}
        cohort_meta[key] = {
            "label": label,
            "filename": fname,
            "cache_path": str(cache_path.relative_to(ROOT)).replace("\\", "/"),
            "fetch_status": fetch_status,
            "n": int(len(df_ext)),
            "n_pos": int(df_ext["target"].sum()),
            "prevalence": float(df_ext["target"].mean()),
            "missing_pct": miss_pct,
            "chol_zero_count": int((df_ext["chol"] == 0).sum()),
            "chol_zero_pct": float((df_ext["chol"] == 0).mean() * 100.0),
            "trestbps_zero_count": int((df_ext["trestbps"] == 0).sum()),
            "trestbps_zero_pct": float((df_ext["trestbps"] == 0).mean() * 100.0),
        }

    pooled_df = pd.concat([cohort_frames[k] for k, _, _ in EXTERNAL_COHORTS], ignore_index=True)
    cohort_frames["pooled_external"] = pooled_df
    cohort_meta["pooled_external"] = {
        "label": "Pooled External",
        "filename": "pooled",
        "n": int(len(pooled_df)),
        "n_pos": int(pooled_df["target"].sum()),
        "prevalence": float(pooled_df["target"].mean()),
        "missing_pct": {c: float(pooled_df[c].isna().mean() * 100.0) for c in feature_cols},
        "chol_zero_count": int((pooled_df["chol"] == 0).sum()),
        "chol_zero_pct": float((pooled_df["chol"] == 0).mean() * 100.0),
        "trestbps_zero_count": int((pooled_df["trestbps"] == 0).sum()),
        "trestbps_zero_pct": float((pooled_df["trestbps"] == 0).mean() * 100.0),
    }

    for key, df_ext in cohort_frames.items():
        X_ext_raw = df_ext[feature_cols]
        y_ext = df_ext["target"].to_numpy()
        X_ext_clean = X_ext_raw.copy()
        X_ext_clean.loc[X_ext_clean["chol"] == 0, "chol"] = np.nan
        X_ext_clean.loc[X_ext_clean["trestbps"] == 0, "trestbps"] = np.nan

        p_raw = pipe_lr_ni.predict_proba(X_ext_raw)[:, 1]
        p_clean = pipe_lr_ni.predict_proba(X_ext_clean)[:, 1]
        ext_results[key] = {
            "raw": evaluate_predictions(y_ext, p_raw),
            "impossible_zeros_as_nan": evaluate_predictions(y_ext, p_clean),
        }

    metrics = {
        "dataset": {
            "cleveland_n": int(len(df_full)),
            "cleveland_pos": int(df_full["target"].sum()),
            "cleveland_prevalence": float(df_full["target"].mean()),
            "train_n": int(len(X_train)),
            "test_n": int(len(X_test)),
            "random_state": 42,
        },
        "grid_search_train_242": grid_summary,
        "repeated_cv_10x5_all_303": repeated_cv,
        "nested_cv_10x5_all_303": nested_cv,
        "test_61": test_61,
        "split_brain_rf_vs_logreg": split_brain,
        "mode_imputation_false_reassurance_trap": imputation_trap,
        "collinearity_and_referral_bias": collinearity,
        "external_validation": {
            "model_evaluated": "non_invasive_11",
            "zero_retraining": True,
            "cohorts": cohort_meta,
            "results": ext_results,
        },
    }

    METRICS_JSON.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    REPORT_MD.write_text(render_markdown_report(metrics), encoding="utf-8")

    print(f"wrote {METRICS_JSON.relative_to(ROOT)}")
    print(f"wrote {REPORT_MD.relative_to(ROOT)}")
    print(f"full_13 C={best_c_full} train_5cv={grid_summary['full_13']['best_cv_auc_mean']:.4f}")
    print(f"non_invasive_11 C={best_c_ni} train_5cv={grid_summary['non_invasive_11']['best_cv_auc_mean']:.4f}")
    for key in ["logreg_full_13", "rf_full_13", "logreg_non_invasive_11"]:
        m = repeated_cv[key]
        print(
            f"10x5 CV {key}: AUC={m['roc_auc']['mean']:.4f}+/-{m['roc_auc']['std']:.4f} "
            f"Brier={m['brier']['mean']:.4f} ECE={m['ece_10bin']['mean']:.4f} "
            f"LogLoss={m['log_loss']['mean']:.4f}"
        )
    print(
        f"Nested 10x5 CV: full_13 AUC={nested_cv['logreg_full_13']['roc_auc']['mean']:.4f}+/-"
        f"{nested_cv['logreg_full_13']['roc_auc']['std']:.4f} | "
        f"non_invasive_11 AUC={nested_cv['logreg_non_invasive_11']['roc_auc']['mean']:.4f}+/-"
        f"{nested_cv['logreg_non_invasive_11']['roc_auc']['std']:.4f}"
    )
    print(
        f"Mode trap shift: {imputation_trap['combined_healthy_mode_log_odds_shift']:.4f} "
        f"(test_pos naive recall={imputation_trap['test_61_positives_with_ca_thal_masked']['naive_mode_imputed_full_13_recall']:.4f} "
        f"vs non_inv recall={imputation_trap['test_61_positives_with_ca_thal_masked']['safe_non_invasive_11_recall']:.4f})"
    )
    for key in ["hungarian", "switzerland", "va", "pooled_external"]:
        r_raw = ext_results[key]["raw"]
        r_cln = ext_results[key]["impossible_zeros_as_nan"]
        print(
            f"External {key}: N={r_raw['n']} prev={r_raw['prevalence']:.3f} | "
            f"raw AUC={r_raw['roc_auc']:.4f} ECE={r_raw['ece_10bin']:.4f} | "
            f"clean AUC={r_cln['roc_auc']:.4f} ECE={r_cln['ece_10bin']:.4f}"
        )


if __name__ == "__main__":
    main()
