from pathlib import Path

import joblib
import pandas as pd
import streamlit as st

st.set_page_config(page_title="Heart Disease Risk", page_icon="🫀")


@st.cache_resource
def load_model():
    return joblib.load(Path(__file__).parent / "model.pkl")


model = load_model()

st.title("🫀 Heart Disease Risk Prediction")
st.warning("Educational project. NOT a medical diagnostic tool.")

# هر گزینه: متن نمایشی -> کدی که مدل با آن آموزش دیده
SEX = {"Female": 0, "Male": 1}
CP = {"Typical angina": 1, "Atypical angina": 2,
      "Non-anginal pain": 3, "Asymptomatic": 4}
FBS = {"No (≤ 120 mg/dl)": 0, "Yes (> 120 mg/dl)": 1}
RESTECG = {"Normal": 0, "ST-T abnormality": 1, "LV hypertrophy": 2}
EXANG = {"No": 0, "Yes": 1}
SLOPE = {"Upsloping": 1, "Flat": 2, "Downsloping": 3}
THAL = {"Normal": 3, "Fixed defect": 6, "Reversible defect": 7}

col1, col2 = st.columns(2)
with col1:
    age = st.number_input("Age", 20, 100, 55)
    sex = st.selectbox("Sex", list(SEX))
    cp = st.selectbox("Chest pain type", list(CP))
    trestbps = st.number_input("Resting blood pressure (mm Hg)", 80, 220, 130)
    chol = st.number_input("Cholesterol (mg/dl)", 100, 600, 240)
    fbs = st.selectbox("Fasting blood sugar", list(FBS))
    restecg = st.selectbox("Resting ECG", list(RESTECG))
with col2:
    thalach = st.number_input("Max heart rate achieved", 60, 220, 150)
    exang = st.selectbox("Exercise-induced angina", list(EXANG))
    oldpeak = st.number_input("ST depression (oldpeak)", 0.0, 7.0, 1.0, step=0.1)
    slope = st.selectbox("ST segment slope", list(SLOPE))
    ca = st.selectbox("Major vessels colored by fluoroscopy", [0, 1, 2, 3])
    thal = st.selectbox("Thallium test result", list(THAL))

if st.button("Predict", type="primary"):
    row = pd.DataFrame([{
        "age": age, "sex": SEX[sex], "cp": CP[cp], "trestbps": trestbps,
        "chol": chol, "fbs": FBS[fbs], "restecg": RESTECG[restecg],
        "thalach": thalach, "exang": EXANG[exang], "oldpeak": oldpeak,
        "slope": SLOPE[slope], "ca": ca, "thal": THAL[thal],
    }]).astype(float)

    prob = model.predict_proba(row)[0, 1]

    st.metric("Estimated probability of heart disease", f"{prob:.1%}")
    st.progress(float(prob))
    if prob < 0.35:
        st.success("Lower risk band")
    elif prob < 0.65:
        st.warning("Moderate risk band")
    else:
        st.error("Higher risk band")
    st.caption("Risk bands are illustrative cut-offs, not clinical thresholds.")