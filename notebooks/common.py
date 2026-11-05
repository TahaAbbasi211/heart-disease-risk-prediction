import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder

NUM_COLS = ["age", "trestbps", "chol", "thalach", "oldpeak"]
CAT_COLS = ["sex", "cp", "fbs", "restecg", "exang", "slope", "ca", "thal"]


def load_split(path="../data/heart.csv"):
    df = pd.read_csv(path)
    X = df.drop(columns="target")
    y = df["target"]
    return train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)


def build_preprocess():
    numeric = Pipeline([("imputer", SimpleImputer(strategy="median")),
                        ("scaler", StandardScaler())])
    categorical = Pipeline([("imputer", SimpleImputer(strategy="most_frequent")),
                            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False))])
    return ColumnTransformer([("num", numeric, NUM_COLS),
                              ("cat", categorical, CAT_COLS)])