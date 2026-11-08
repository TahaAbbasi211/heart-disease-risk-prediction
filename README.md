# Heart Disease Risk Prediction

End-to-end machine learning project on the UCI Cleveland heart disease dataset: exploratory analysis, leakage-free preprocessing, model comparison with cross-validation, hyperparameter tuning, explainability (SHAP), and a Streamlit app.

> **Educational project. Not a medical diagnostic tool.**


## Dataset

- UCI Heart Disease dataset, Cleveland subset: 303 patients, 13 features.
- The original target (0–4) is binarized: `1` = heart disease present, `0` = absent (164 vs 139 patients, roughly balanced).
- 6 missing values (`ca`: 4, `thal`: 2), imputed inside the pipeline. No duplicates, no physiologically impossible values.
- Source: UCI Machine Learning Repository (Heart Disease). Please credit the original authors if you reuse the data.

## Method

1. **EDA** – class balance, distributions by target, correlation, outliers, effect sizes (Cohen's d, Welch t-test).
2. **Preprocessing** – stratified 80/20 split *before* any fitting; median/most-frequent imputation, standardization, one-hot encoding, all inside a scikit-learn `Pipeline` (no data leakage).
3. **Models** – Logistic Regression, KNN, SVM, Decision Tree, Random Forest, Gradient Boosting, plus a Dummy baseline, compared with stratified 5-fold CV on the training set.
4. **Tuning** – `GridSearchCV` (ROC-AUC) for Logistic Regression, SVM and Random Forest.
5. **Final check** – one evaluation on the untouched test set.
6. **Explainability** – permutation importance and SHAP.

## Results

Cross-validated ROC-AUC (5 folds, training set):

| Model | AUC |
|---|---|
| Logistic Regression | 0.902 |
| Random Forest | 0.894 |
| SVM | 0.888 |
| KNN | 0.872 |
| Gradient Boosting | 0.857 |
| Decision Tree | 0.786 |
| Dummy baseline | 0.500 |

The top three models are within one standard deviation of each other, so the data cannot rank them reliably. Tuning improved AUC by at most ~0.01 (Random Forest 0.894 → 0.904), which is within noise: the models are not very sensitive to hyperparameters.

Final model: Random Forest. On the held-out test set (61 patients): AUC 0.955, recall 0.893, precision 0.806 (TN 27, FP 6, FN 3, TP 25). With only 28 positive cases this estimate is noisy and likely optimistic; the cross-validated AUC (~0.90) is the more trustworthy number.

## What the model learned

Most influential features: `ca`, `cp`, `thal`, `exang`, `oldpeak`. Directions are clinically plausible (higher max heart rate and no major vessels colored lower the risk; ST depression, exercise-induced angina, reversible thallium defect and age raise it). Cholesterol and fasting blood sugar have almost no effect, consistent with the EDA.

Notably, asymptomatic chest pain (`cp=4`) *raises* predicted risk. This is a known pattern in this dataset and probably reflects that patients were referred for angiography.
## Offline Android app

An installable Android app (English / Persian) runs the model fully on the phone, with no server and no internet permission. Download the APK from the [Releases](https://github.com/TahaAbbasi211/heart-disease-risk-prediction/releases) page (debug-signed, for personal sideloading only).

The app uses the **Logistic Regression** model, re-implemented as a plain formula (28 coefficients plus the preprocessing constants, stored in `model.json`). It is used instead of the Random Forest because it has a simple closed form and its cross-validated AUC (0.903) is statistically indistinguishable from the Random Forest (0.904). The Streamlit app still uses the Random Forest, so the two apps can give slightly different probabilities.

Correctness: the formula matches scikit-learn's `predict_proba` to within 3e-16 on all 303 rows, and the Dart code is tested against 15 reference cases (tolerance 1e-6). The app UI was tested manually on a phone.

Code: `mobile_export/` (formula export and verification), `android_app/` (Flutter).

## Limitations

- Small dataset (303 patients); results vary between splits.
- Several inputs (`ca`, `thal`) come from invasive or specialized tests, so this is not usable by the general public.
- SHAP and importances show associations, not causation.
- Single-center data; no external validation.

## Run it

```bash
pip install -r requirements.txt
streamlit run app.py
```

## Project structure

```
data/           dataset (raw + cleaned)
notebooks/      EDA, preprocessing, modeling
model.pkl       trained scikit-learn pipeline
app.py          Streamlit app
mobile_export/  formula export + verification
android_app/    offline Flutter app
requirements.txt
```