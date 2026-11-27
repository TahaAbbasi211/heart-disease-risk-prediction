"""Clinical safety, numerical stability, validation, and import-isolation tests."""

from __future__ import annotations

import ast
import copy
import math
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from heart_risk import (  # noqa: E402
    CLINICAL_PRESETS,
    DEFAULT_INPUTS,
    HeartRiskEngine,
    ValidationError,
    load_default_engine,
    predict,
    sigmoid,
)


def test_auto_routing_switches_on_missing_ca_or_thal() -> None:
    r_both = predict(DEFAULT_INPUTS, mode="auto")
    assert r_both.mode == "full_13"
    assert r_both.requested_mode == "auto"

    no_ca = {**DEFAULT_INPUTS, "ca": None}
    r_no_ca = predict(no_ca, mode="auto")
    assert r_no_ca.mode == "non_invasive_11"
    assert "ca" not in r_no_ca.imputed_cols

    no_thal = {**DEFAULT_INPUTS, "thal": None}
    r_no_thal = predict(no_thal, mode="auto")
    assert r_no_thal.mode == "non_invasive_11"
    assert "thal" not in r_no_thal.imputed_cols

    neither = {**DEFAULT_INPUTS, "ca": None, "thal": None}
    r_neither = predict(neither, mode="auto")
    assert r_neither.mode == "non_invasive_11"


def test_clinical_false_reassurance_avoided() -> None:
    symptomatic = CLINICAL_PRESETS["high_risk_non_invasive"]["inputs"]
    safe_res = predict(symptomatic, mode="auto")
    naive_res = predict(symptomatic, mode="full_13")

    assert safe_res.mode == "non_invasive_11"
    assert safe_res.risk_band == "high"
    assert safe_res.probability >= 0.65
    assert safe_res.probability > naive_res.probability

    # Explicit full_13 mode still mode-imputes when requested explicitly (for parity).
    assert naive_res.imputed_cols == ("ca", "thal")

    # Real positive Cleveland patient (row 292) where naive healthy-mode imputation
    # drops risk from high (71.4%) below 50% (44.5% -> false negative):
    row_292_masked = {
        "age": 44,
        "sex": 1,
        "cp": 4,
        "trestbps": 120,
        "chol": 169,
        "fbs": 0,
        "restecg": 0,
        "thalach": 144,
        "exang": 1,
        "oldpeak": 2.8,
        "slope": 3,
        "ca": None,
        "thal": None,
    }
    safe_border = predict(row_292_masked, mode="auto")
    naive_border = predict(row_292_masked, mode="full_13")
    assert safe_border.risk_band == "high"
    assert safe_border.pred_class == 1
    assert naive_border.pred_class == 0


@pytest.mark.parametrize(
    "bad_patch",
    [
        {"age": float("nan")},
        {"age": float("inf")},
        {"oldpeak": float("-inf")},
        {"chol": True},
        {"trestbps": "invalid"},
        {"age": 19},
        {"age": 101},
        {"trestbps": 79},
        {"trestbps": 221},
        {"chol": 99},
        {"chol": 601},
        {"thalach": 59},
        {"thalach": 221},
        {"oldpeak": -0.1},
        {"oldpeak": 7.1},
    ],
)
def test_validation_rejects_invalid_and_non_finite_inputs(bad_patch: dict) -> None:
    payload = {**DEFAULT_INPUTS, **bad_patch}
    with pytest.raises(ValidationError):
        predict(payload, mode="auto", validate=True)


@pytest.mark.parametrize(
    ("mode", "bad_patch"),
    [
        ("auto", {"ca": 99}),
        ("auto", {"thal": 5}),
        ("auto", {"ca": 99, "thal": None}),
        ("auto", {"ca": None, "thal": 5}),
        ("auto", {"cp": 9}),
        ("auto", {"sex": 2}),
        ("auto", {"slope": 9}),
        ("full_13", {"thal": 5}),
        ("full_13", {"ca": 99}),
        ("non_invasive_11", {"cp": 9}),
        ("non_invasive_11", {"sex": 2}),
    ],
)
def test_strict_categorical_validation_when_validate_true(mode: str, bad_patch: dict) -> None:
    payload = {**DEFAULT_INPUTS, **bad_patch}
    with pytest.raises(ValidationError):
        predict(payload, mode=mode, validate=True)


def test_custom_risk_bands_from_spec() -> None:
    base_engine = load_default_engine()
    default_prob = base_engine.predict(DEFAULT_INPUTS, mode="auto").probability
    assert 0.03 < default_prob < 0.10

    custom_spec = copy.deepcopy(base_engine.raw_spec)
    custom_spec["risk_bands"] = {"low_max": 0.04, "moderate_max": 0.05}
    strict_engine = HeartRiskEngine(custom_spec)
    assert strict_engine.predict(DEFAULT_INPUTS, mode="auto").risk_band == "high"

    custom_spec["risk_bands"] = {"low_max": 0.70, "moderate_max": 0.50}
    with pytest.raises(ValidationError):
        HeartRiskEngine(custom_spec)


def test_invalid_mode_raises_validation_error() -> None:
    with pytest.raises(ValidationError):
        predict(DEFAULT_INPUTS, mode="unknown_mode")


def test_sigmoid_numerical_stability() -> None:
    assert sigmoid(-1000.0) == 0.0
    assert sigmoid(1000.0) == 1.0
    assert sigmoid(0.0) == 0.5
    assert sigmoid(-12.5) == pytest.approx(1.0 - sigmoid(12.5), rel=1e-12, abs=1e-12)
    for bad in (float("nan"), float("inf"), float("-inf"), True, "abc"):
        with pytest.raises(ValidationError):
            sigmoid(bad)  # type: ignore[arg-type]


def test_unseen_category_handling_with_validate_false() -> None:
    engine = load_default_engine()
    res_full = engine.predict({**DEFAULT_INPUTS, "thal": 5}, mode="full_13", validate=False)
    assert res_full.unseen_cols == ("thal",)
    assert res_full.contribution_map()["thal"] == 0.0
    assert math.isfinite(res_full.probability)

    res_ni = engine.predict(
        {**DEFAULT_INPUTS, "cp": 9, "ca": None, "thal": None},
        mode="auto",
        validate=False,
    )
    assert res_ni.mode == "non_invasive_11"
    assert res_ni.unseen_cols == ("cp",)
    assert res_ni.contribution_map()["cp"] == 0.0


def test_canonical_defaults_and_presets() -> None:
    assert DEFAULT_INPUTS["sex"] == 1
    for preset_id, preset in CLINICAL_PRESETS.items():
        res = predict(preset["inputs"], mode="auto")
        assert res.mode == preset["expected_mode"], preset_id
        assert res.risk_band == preset["expected_band"], preset_id


def test_runtime_import_isolation_and_app_ast() -> None:
    forbidden = ("sklearn", "joblib", "shap", "matplotlib", "seaborn", "scipy", "numpy", "pandas")

    code = (
        "import sys; "
        "from heart_risk import DEFAULT_INPUTS, predict; "
        "res = predict(DEFAULT_INPUTS); "
        f"loaded = [m for m in {forbidden!r} if any(k == m or k.startswith(m + '.') for k in sys.modules)]; "
        "assert not loaded, f'Forbidden modules imported: {loaded}'; "
        "assert 0.0 < res.probability < 1.0"
    )
    proc = subprocess.run(
        [sys.executable, "-c", code],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr or proc.stdout

    app_src = (ROOT / "app.py").read_text(encoding="utf-8")
    tree = ast.parse(app_src)
    imported_roots: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imported_roots.add(alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported_roots.add(node.module.split(".")[0])

    overlap = imported_roots.intersection(forbidden)
    assert not overlap, f"app.py imports forbidden packages: {sorted(overlap)}"
    assert "joblib.load" not in app_src
