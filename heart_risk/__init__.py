"""Zero-ML-dependency dual-mode heart disease risk inference package."""

from .engine import (
    DEFAULT_MODEL_PATH,
    EXPECTED_FORMAT,
    EXPECTED_SCHEMA_VERSION,
    MODEL_KEYS,
    VALID_MODES,
    FeatureContribution,
    HeartRiskEngine,
    PredictionResult,
    ValidationError,
    classify_risk_band,
    load_default_engine,
    predict,
    sigmoid,
)
from .presets import (
    CATEGORICAL_CODES,
    CLINICAL_PRESETS,
    DEFAULT_INPUTS,
    NUMERIC_BOUNDS,
)

__all__ = [
    "CATEGORICAL_CODES",
    "CLINICAL_PRESETS",
    "DEFAULT_INPUTS",
    "DEFAULT_MODEL_PATH",
    "EXPECTED_FORMAT",
    "EXPECTED_SCHEMA_VERSION",
    "FeatureContribution",
    "HeartRiskEngine",
    "MODEL_KEYS",
    "NUMERIC_BOUNDS",
    "PredictionResult",
    "VALID_MODES",
    "ValidationError",
    "classify_risk_band",
    "load_default_engine",
    "predict",
    "sigmoid",
]
