from __future__ import annotations

from collections.abc import Iterable

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

NUM_COLS = ["age", "trestbps", "chol", "thalach", "oldpeak"]
CAT_COLS_FULL = ["sex", "cp", "fbs", "restecg", "exang", "slope", "ca", "thal"]
CAT_COLS = CAT_COLS_FULL
CAT_COLS_NON_INVASIVE = ["sex", "cp", "fbs", "restecg", "exang", "slope"]


def load_split(path: str = "../data/heart.csv"):
    df = pd.read_csv(path)
    X = df.drop(columns="target")
    y = df["target"]
    return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)


def build_preprocess(cat_cols: Iterable[str] = CAT_COLS_FULL) -> ColumnTransformer:
    selected_cat = list(cat_cols)
    numeric = Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
        ]
    )
    categorical = Pipeline(
        [
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]
    )
    return ColumnTransformer(
        [
            ("num", numeric, list(NUM_COLS)),
            ("cat", categorical, selected_cat),
        ]
    )
