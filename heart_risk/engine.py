"""Pure-Python dual-mode inference and per-feature explainability engine.

Uses only the Python standard library and ``mobile_export/model.json`` v2.
Zero dependency on scikit-learn, joblib, numpy, pandas, or shap.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import json
import math
from pathlib import Path
from typing import Any, Mapping

from .presets import NUMERIC_BOUNDS

EXPECTED_FORMAT = "heart-risk-linear-formula/2"
EXPECTED_SCHEMA_VERSION = 2
VALID_MODES = ("auto", "full_13", "non_invasive_11")
MODEL_KEYS = ("full_13", "non_invasive_11")
DEFAULT_LOW_MAX = 0.35
DEFAULT_MODERATE_MAX = 0.65
DEFAULT_MODEL_PATH = Path(__file__).resolve().parent.parent / "mobile_export" / "model.json"


class ValidationError(ValueError):
    """Raised when clinical inputs or model specifications are invalid."""


def sigmoid(z: float) -> float:
    """Numerically stable logistic sigmoid avoiding overflow for large |z|."""
    if isinstance(z, bool):
        raise ValidationError("Log-odds z cannot be a boolean.")
    try:
        val = float(z)
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"Log-odds z must be numeric, got {z!r}.") from exc
    if not math.isfinite(val):
        raise ValidationError(f"Log-odds z must be finite, got {val!r}.")

    if val >= 0.0:
        return 1.0 / (1.0 + math.exp(-val))
    ez = math.exp(val)
    return ez / (1.0 + ez)


def classify_risk_band(
    probability: float,
    *,
    low_max: float = DEFAULT_LOW_MAX,
    moderate_max: float = DEFAULT_MODERATE_MAX,
) -> str:
    """Map probability into educational display risk bands."""
    if probability < low_max:
        return "low"
    if probability < moderate_max:
        return "moderate"
    return "high"


@dataclass(frozen=True)
class FeatureContribution:
    """Exact linear contribution (delta_z) of one raw input column."""

    feature: str
    kind: str
    raw_value: float | None
    used_value: float
    delta_z: float
    imputed: bool
    unseen: bool
    output_feature: str | None


@dataclass(frozen=True)
class PredictionResult:
    """Structured inference and additive log-odds explanation output."""

    mode: str
    requested_mode: str
    probability: float
    probability_absent: float
    pred_class: int
    risk_band: str
    z: float
    intercept: float
    contributions: tuple[FeatureContribution, ...]
    imputed_cols: tuple[str, ...]
    unseen_cols: tuple[str, ...]

    def contribution_map(self) -> dict[str, float]:
        """Return {feature_name: delta_z} preserving model column order."""
        return {c.feature: c.delta_z for c in self.contributions}


def _coerce_value(col: str, raw: Any, *, validate: bool) -> float | None:
    """Coerce an optional numeric/categorical code while rejecting NaN/Inf."""
    if raw is None:
        return None
    if isinstance(raw, bool):
        raise ValidationError(f"Input '{col}' cannot be a boolean ({raw!r}).")
    try:
        val = float(raw)
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"Input '{col}' must be numeric or None, got {raw!r}.") from exc

    if math.isnan(val):
        if validate:
            raise ValidationError(f"Input '{col}' cannot be NaN.")
        return None
    if not math.isfinite(val):
        raise ValidationError(f"Input '{col}' must be finite, got {val!r}.")
    return val


def _parse_risk_bands(spec: Mapping[str, Any]) -> tuple[float, float]:
    """Read and validate single-source risk band thresholds from model.json."""
    rb = spec.get("risk_bands")
    if rb is None:
        return DEFAULT_LOW_MAX, DEFAULT_MODERATE_MAX
    if not isinstance(rb, Mapping):
        raise ValidationError("Model spec 'risk_bands' must be a mapping.")

    parsed: dict[str, float] = {}
    for key, default in (("low_max", DEFAULT_LOW_MAX), ("moderate_max", DEFAULT_MODERATE_MAX)):
        raw = rb.get(key, default)
        if isinstance(raw, bool):
            raise ValidationError(f"risk_bands['{key}'] cannot be a boolean.")
        try:
            val = float(raw)
        except (TypeError, ValueError) as exc:
            raise ValidationError(f"risk_bands['{key}'] must be numeric, got {raw!r}.") from exc
        if not math.isfinite(val):
            raise ValidationError(f"risk_bands['{key}'] must be finite, got {val!r}.")
        parsed[key] = val

    low_max = parsed["low_max"]
    moderate_max = parsed["moderate_max"]
    if not (0.0 < low_max < moderate_max < 1.0):
        raise ValidationError(
            f"Invalid risk_bands ordering: low_max={low_max}, moderate_max={moderate_max}."
        )
    return low_max, moderate_max


def _validate_model_spec(name: str, spec: Mapping[str, Any]) -> None:
    """Verify internal consistency of one exported linear model block."""
    required_keys = (
        "numeric_cols",
        "categorical_cols",
        "numeric",
        "categorical",
        "output_features",
        "coef",
        "intercept",
    )
    for key in required_keys:
        if key not in spec:
            raise ValidationError(f"Model '{name}' missing required field '{key}'.")

    numeric_cols = spec["numeric_cols"]
    categorical_cols = spec["categorical_cols"]
    output_features = spec["output_features"]
    coef = spec["coef"]

    if len(coef) != len(output_features):
        raise ValidationError(
            f"Model '{name}' coef length ({len(coef)}) != output_features ({len(output_features)})."
        )

    expected_dim = len(numeric_cols)
    for col in numeric_cols:
        stats = spec["numeric"][col]
        if float(stats["scale"]) <= 0.0:
            raise ValidationError(f"Model '{name}' numeric '{col}' scale must be > 0.")

    for col in categorical_cols:
        cats = spec["categorical"][col]["categories"]
        expected_dim += len(cats)

    if expected_dim != len(coef):
        raise ValidationError(
            f"Model '{name}' expanded feature count ({expected_dim}) != coef length ({len(coef)})."
        )


class HeartRiskEngine:
    """Dual-mode pure-Python Logistic Regression engine with exact delta_z."""

    def __init__(self, spec: dict[str, Any]) -> None:
        if spec.get("format") != EXPECTED_FORMAT or spec.get("schema_version") != EXPECTED_SCHEMA_VERSION:
            raise ValidationError(
                f"Unsupported model spec format={spec.get('format')!r}, "
                f"schema_version={spec.get('schema_version')!r}."
            )
        models = spec.get("models")
        if not isinstance(models, dict):
            raise ValidationError("Model spec missing 'models' object.")
        for key in MODEL_KEYS:
            if key not in models:
                raise ValidationError(f"Model spec missing required mode '{key}'.")
            _validate_model_spec(key, models[key])

        self.low_max, self.moderate_max = _parse_risk_bands(spec)
        self.raw_spec: dict[str, Any] = spec
        self.models: dict[str, dict[str, Any]] = models
        self.default_mode: str = str(spec.get("default_mode", "full_13"))
        self.metadata: dict[str, Any] = dict(spec.get("metadata", {}))
        self._allowed_categories: dict[str, dict[str, set[float]]] = {
            key: {
                col: {float(c) for c in models[key]["categorical"][col]["categories"]}
                for col in models[key]["categorical_cols"]
            }
            for key in MODEL_KEYS
        }

    @classmethod
    def from_json_file(cls, path: str | Path = DEFAULT_MODEL_PATH) -> "HeartRiskEngine":
        model_path = Path(path)
        payload = json.loads(model_path.read_text(encoding="utf-8"))
        return cls(payload)

    def _select_mode(self, inputs: Mapping[str, Any], mode: str, *, validate: bool) -> str:
        if mode not in VALID_MODES:
            raise ValidationError(f"Unknown mode {mode!r}; expected one of {VALID_MODES}.")
        if mode != "auto":
            return mode

        ca_val = _coerce_value("ca", inputs.get("ca"), validate=validate)
        thal_val = _coerce_value("thal", inputs.get("thal"), validate=validate)
        if validate:
            allowed_ca = self._allowed_categories["full_13"]["ca"]
            if ca_val is not None and ca_val not in allowed_ca:
                raise ValidationError(
                    f"Input 'ca'={ca_val} is invalid; allowed values: {sorted(allowed_ca)}."
                )
            allowed_thal = self._allowed_categories["full_13"]["thal"]
            if thal_val is not None and thal_val not in allowed_thal:
                raise ValidationError(
                    f"Input 'thal'={thal_val} is invalid; allowed values: {sorted(allowed_thal)}."
                )

        if ca_val is None or thal_val is None:
            return "non_invasive_11"
        return "full_13"

    def predict(
        self,
        inputs: Mapping[str, Any],
        mode: str = "auto",
        *,
        validate: bool = True,
    ) -> PredictionResult:
        """Predict heart disease probability and exact additive log-odds contributions."""
        if not isinstance(inputs, Mapping):
            raise ValidationError("inputs must be a mapping of feature names to values.")

        active_mode = self._select_mode(inputs, mode, validate=validate)
        spec = self.models[active_mode]
        coef: list[float] = [float(w) for w in spec["coef"]]
        output_features: list[str] = [str(f) for f in spec["output_features"]]
        intercept = float(spec["intercept"])

        contributions: list[FeatureContribution] = []
        imputed_cols: list[str] = []
        unseen_cols: list[str] = []
        offset = 0

        for col in spec["numeric_cols"]:
            stats = spec["numeric"][col]
            raw_val = _coerce_value(col, inputs.get(col), validate=validate)
            if raw_val is None:
                used_val = float(stats["median"])
                imputed = True
                imputed_cols.append(col)
            else:
                if validate and col in NUMERIC_BOUNDS:
                    lo, hi = NUMERIC_BOUNDS[col]
                    if raw_val < lo or raw_val > hi:
                        raise ValidationError(
                            f"Input '{col}'={raw_val} is outside physiological bounds [{lo}, {hi}]."
                        )
                used_val = raw_val
                imputed = False

            standardized = (used_val - float(stats["mean"])) / float(stats["scale"])
            delta_z = coef[offset] * standardized
            contributions.append(
                FeatureContribution(
                    feature=col,
                    kind="numeric",
                    raw_value=raw_val,
                    used_value=used_val,
                    delta_z=delta_z,
                    imputed=imputed,
                    unseen=False,
                    output_feature=output_features[offset],
                )
            )
            offset += 1

        for col in spec["categorical_cols"]:
            cat = spec["categorical"][col]
            categories = [float(c) for c in cat["categories"]]
            raw_val = _coerce_value(col, inputs.get(col), validate=validate)
            if raw_val is None:
                used_val = float(cat["mode"])
                imputed = True
                imputed_cols.append(col)
            else:
                used_val = raw_val
                imputed = False

            matched_idx: int | None = None
            for idx, category in enumerate(categories):
                if used_val == category:
                    matched_idx = idx
                    break

            if matched_idx is not None:
                delta_z = coef[offset + matched_idx]
                out_feat: str | None = output_features[offset + matched_idx]
                unseen = False
            else:
                if validate and raw_val is not None:
                    raise ValidationError(
                        f"Input '{col}'={raw_val} is invalid for mode '{active_mode}'; "
                        f"allowed values: {sorted(categories)}."
                    )
                delta_z = 0.0
                out_feat = None
                unseen = True
                unseen_cols.append(col)

            contributions.append(
                FeatureContribution(
                    feature=col,
                    kind="categorical",
                    raw_value=raw_val,
                    used_value=used_val,
                    delta_z=delta_z,
                    imputed=imputed,
                    unseen=unseen,
                    output_feature=out_feat,
                )
            )
            offset += len(categories)

        z = intercept + sum(c.delta_z for c in contributions)
        prob = sigmoid(z)
        return PredictionResult(
            mode=active_mode,
            requested_mode=mode,
            probability=prob,
            probability_absent=1.0 - prob,
            pred_class=1 if prob >= 0.5 else 0,
            risk_band=classify_risk_band(
                prob, low_max=self.low_max, moderate_max=self.moderate_max
            ),
            z=z,
            intercept=intercept,
            contributions=tuple(contributions),
            imputed_cols=tuple(imputed_cols),
            unseen_cols=tuple(unseen_cols),
        )


@lru_cache(maxsize=4)
def load_default_engine(path: str | Path = DEFAULT_MODEL_PATH) -> HeartRiskEngine:
    """Load and cache a HeartRiskEngine from ``model.json``."""
    return HeartRiskEngine.from_json_file(path)


def predict(
    inputs: Mapping[str, Any],
    mode: str = "auto",
    *,
    validate: bool = True,
    model_path: str | Path = DEFAULT_MODEL_PATH,
) -> PredictionResult:
    """Convenience entry point using the cached default HeartRiskEngine."""
    return load_default_engine(str(Path(model_path).resolve())).predict(
        inputs, mode=mode, validate=validate
    )
