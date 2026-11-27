"""Bilingual (EN / فارسی) clinical demo powered exclusively by heart_risk & model.json v2.

Zero ML runtime dependencies: does not import scikit-learn, joblib, shap, pandas,
matplotlib, or seaborn, and never loads model.pkl.
"""

from __future__ import annotations

import html
import inspect
from typing import Any

import streamlit as st

from heart_risk import (
    CLINICAL_PRESETS,
    DEFAULT_INPUTS,
    NUMERIC_BOUNDS,
    PredictionResult,
    load_default_engine,
)

st.set_page_config(
    page_title="Heart Disease Risk Prediction",
    page_icon="🫀",
    layout="wide",
)

# ---------------------------------------------------------------------------
# Bilingual strings (Persian medical terms match docs/translations_to_review.md)
# ---------------------------------------------------------------------------
TEXT: dict[str, dict[str, str]] = {
    "en": {
        "title": "Heart Disease Risk Prediction",
        "subtitle": "Single-source-of-truth dual-mode Logistic Regression (`model.json` v2) with additive log-odds explainability.",
        "disclaimer": "Educational and research prototype. NOT a medical diagnostic tool and NOT a substitute for clinical evaluation.",
        "tab_assess": "Risk Assessment & Live Explanation",
        "tab_card": "Model Card & Validation",
        "lang_label": "Language / زبان",
        "mode_label": "Inference Mode",
        "mode_full": "Full Clinical (13 features)",
        "mode_ni": "Non-Invasive Screening (11 features)",
        "presets_heading": "One-Click Clinical Presets",
        "inputs_heading": "Patient Clinical Inputs",
        "non_invasive_omitted": "Non-Invasive Screening mode excludes fluoroscopy (`ca`) and thallium scan (`thal`) inputs.",
        "auto_route_banner": (
            "**Clinical safety auto-routing active:** Because `ca` or `thal` is marked *Not tested / Unknown*, "
            "prediction automatically switched to **`non_invasive_11`**. Missing invasive tests are **never** silently "
            "imputed to healthy defaults (`ca=0, thal=3`), which would artificially shift log-odds by `-2.0389`."
        ),
        "unknown_option": "Not tested / Unknown",
        "result_heading": "Live Prediction & Log-Odds Breakdown",
        "prob_label": "Estimated probability of heart disease",
        "active_mode_label": "Active model",
        "mode_badge_full": "Full Clinical (13 features)",
        "mode_badge_ni": "Non-Invasive Screening (11 features)",
        "band_low": "Lower risk band (< 35%)",
        "band_moderate": "Moderate risk band (35% – 65%)",
        "band_high": "Higher risk band (≥ 65%)",
        "band_note": "Risk bands (<35% lower, 35–65% moderate, ≥65% higher) are illustrative cut-offs, not validated clinical thresholds.",
        "eq_heading": "Exact Logistic Equation",
        "chart_heading": "Per-Feature Log-Odds Contributions (Δz)",
        "chart_x_title": "Log-odds contribution (Δz)",
        "chart_caption": "Positive Δz (crimson) pushes predicted log-odds upward; negative Δz (teal) lowers predicted log-odds.",
        "col_feature": "Feature",
        "col_value": "Value",
        "col_dz": "Δz Contribution",
        "col_dir": "Effect",
        "dir_risk": "Increases risk (+Δz)",
        "dir_prot": "Lowers risk (-Δz)",
        "dir_neutral": "Neutral (0)",
        "caveat_title": "Understanding counter-intuitive weights (age, fbs, asymptomatic cp=4)",
        "caveat_body": (
            "- **Why `age` is slightly negative (`-0.0609`) in `full_13`:** Univariately in Cleveland, older age strongly "
            "*raises* disease risk (`r = +0.223`, univariate standardized slope `+0.430`). Once fluoroscopy (`ca`, `r = +0.363` with age), "
            "max heart rate (`thalach`, `r = -0.394`), blood pressure, and ST depression are all conditioned on simultaneously, "
            "the residual partial slope on age turns slightly negative (`-0.0609`).\n"
            "- **Why `fbs > 120` (`-0.1033`) is near zero:** Only `45/303` Cleveland patients had `fbs = 1`, with nearly identical "
            "disease prevalence (`48.9%` vs `45.3%`, Fisher `p = 0.746`); this tiny weight reflects sampling noise.\n"
            "- **Why asymptomatic chest pain (`cp = 4`) raises risk (`+1.0306`):** In a cardiac angiography referral cohort, "
            "asymptomatic patients reached catheterization because of silent ischemia or abnormal stress testing (`72.9%` disease prevalence)."
        ),
        "age": "Age",
        "sex": "Sex",
        "cp": "Chest pain type",
        "trestbps": "Resting blood pressure (mm Hg)",
        "chol": "Cholesterol (mg/dl)",
        "fbs": "Fasting blood sugar",
        "restecg": "Resting ECG",
        "thalach": "Max heart rate achieved",
        "exang": "Exercise-induced angina",
        "oldpeak": "ST depression (oldpeak)",
        "slope": "ST segment slope",
        "ca": "Major vessels colored by fluoroscopy (ca)",
        "thal": "Thallium test result (thal)",
        "card_arch_title": "Single-Source-of-Truth Architecture (`model.json` v2)",
        "card_arch_body": (
            "Both web and upcoming Phase 2 mobile clients evaluate identical linear formulas from `mobile_export/model.json` "
            "(schema `heart-risk-linear-formula/2`). Legacy `model.pkl` (Random Forest) has been retired from production runtime "
            "to eliminate cross-platform Split-Brain divergence while remaining documented as a notebook comparison benchmark."
        ),
        "card_internal_heading": "Internal Cleveland Validation (10×5 Repeated Stratified CV & Held-Out Test)",
        "card_out_features": "output features",
        "card_col_metric": "Metric",
        "card_col_rep_cv": "10×5 Repeated CV (N=303)",
        "card_col_test61": "Held-Out Test (N=61)",
        "card_metric_auc": "ROC-AUC",
        "card_metric_prauc": "PR-AUC",
        "card_metric_brier": "Brier Score",
        "card_metric_ece": "10-Bin ECE",
        "card_metric_logloss": "Log-Loss",
        "card_fold_range_note": "Intervals show 95% fold range (2.5–97.5%) across 50 folds.",
        "card_train_cv_fmt": "5-fold train CV ROC-AUC (N=242): `{mean:.4f} ± {std:.4f}`",
        "card_external_heading": "Zero-Retraining External Validation (`non_invasive_11` across UCI Hospitals)",
        "card_ext_col_cohort": "Cohort",
        "card_ext_col_n_prev": "N (Prevalence)",
        "card_ext_col_raw_auc": "Raw AUC",
        "card_ext_col_raw_ece": "Raw ECE",
        "card_ext_col_cln_auc": "Cleaned AUC (`chol/trestbps=0 → NaN`)",
        "card_ext_col_cln_ece": "Cleaned ECE",
        "card_ext_col_pred_obs": "Mean Pred vs Obs",
        "cohort_hungarian": "UCI Hungarian",
        "cohort_switzerland": "UCI Switzerland",
        "cohort_va": "UCI VA Long Beach",
        "cohort_pooled_external": "Pooled External",
        "card_external_note": (
            "Switzerland (`100%`) and VA Long Beach (`24.5%` chol, `0.5%` trestbps) encode missing vitals as `0` in the raw UCI files. "
            "Cleaning impossible `chol/trestbps == 0` to `NaN` (imputed to Cleveland medians) improves pooled external ROC-AUC, while "
            "severe prevalence shifts (`36.1%` Hungarian vs `93.5%` Switzerland vs `74.5%` VA) degrade uncalibrated probabilities."
        ),
        "card_attr": "Source: UCI Machine Learning Repository — Heart Disease (Cleveland, Hungarian, Switzerland, VA Long Beach). Educational use only.",
    },
    "fa": {
        "title": "پیش‌بینی ریسک بیماری قلبی",
        "subtitle": "رگرسیون لجستیک دوحالته با منبع واحد (`model.json` v2) و توضیح‌پذیری دقیق سهم هر ویژگی.",
        "disclaimer": "این برنامه یک پروژه‌ی آموزشی و پژوهشی است و ابزار تشخیص پزشکی نیست؛ جایگزین مراجعه به پزشک نمی‌باشد.",
        "tab_assess": "ارزیابی ریسک و توضیح زنده",
        "tab_card": "کارت مدل و اعتبارسنجی",
        "lang_label": "Language / زبان",
        "mode_label": "حالت محاسبه",
        "mode_full": "بالینی کامل (13 ویژگی)",
        "mode_ni": "غربالگری غیرتهاجمی (11 ویژگی)",
        "presets_heading": "نمونه‌های بالینی آماده (یک کلیک)",
        "inputs_heading": "اطلاعات بالینی بیمار",
        "non_invasive_omitted": "در حالت غربالگری غیرتهاجمی، آزمایش‌های فلوروسکوپی (`ca`) و اسکن تالیوم (`thal`) لحاظ نمی‌شوند.",
        "auto_route_banner": (
            "**مسیریابی ایمن خودکار فعال شد:** به دلیل نامشخص بودن `ca` یا `thal`، محاسبه به‌طور خودکار با مدل ۱۱ ویژگی "
            "**`non_invasive_11`** انجام شد. مقادیر نامشخص هرگز به‌صورت پنهان با مقادیر سالم (`ca=0, thal=3`) پر نمی‌شوند."
        ),
        "unknown_option": "آزمایش نشده / نامشخص",
        "result_heading": "نتیجه‌ی تخمینی و تفکیک سهم ویژگی‌ها",
        "prob_label": "احتمال تخمینی بیماری قلبی",
        "active_mode_label": "مدل فعال",
        "mode_badge_full": "بالینی کامل (13 ویژگی)",
        "mode_badge_ni": "غربالگری غیرتهاجمی (11 ویژگی)",
        "band_low": "ریسک کمتر (< 35%)",
        "band_moderate": "ریسک متوسط (35% – 65%)",
        "band_high": "ریسک بالاتر (≥ 65%)",
        "band_note": "این بازه‌های ریسک فقط برای نمایش آموزشی هستند و آستانه‌ی بالینی تاییدشده محسوب نمی‌شوند.",
        "eq_heading": "معادله‌ی دقیق لگاریتم شانس (Log-Odds)",
        "chart_heading": "سهم هر ویژگی در لگاریتم شانس (Δz)",
        "chart_x_title": "سهم در لگاریتم شانس (Δz)",
        "chart_caption": "مقادیر مثبت Δz (قرمز) احتمال تخمینی را افزایش و مقادیر منفی Δz (سبز آبی) احتمال را کاهش می‌دهند.",
        "col_feature": "ویژگی",
        "col_value": "مقدار",
        "col_dz": "سهم Δz",
        "col_dir": "جهت اثر",
        "dir_risk": "افزایش‌دهنده (+Δz)",
        "dir_prot": "کاهش‌دهنده (-Δz)",
        "dir_neutral": "خنثی (0)",
        "caveat_title": "توضیح ضرایب هم‌خطی و سوگیری ارجاع در داده‌ی کلیولند (age، fbs، cp=4)",
        "caveat_body": (
            "- **چرا ضریب `age` در `full_13` کمی منفی (`-0.0609`) است؟** به‌صورت تک‌متغیره در کلیولند، افزایش سن ریسک را بالا می‌برد "
            "(`r = +0.223`). اما سن با `ca` (`r = +0.363`) و کاهش `thalach` (`r = -0.394`) همبستگی دارد و پس از کنترل هم‌زمان "
            "این شاخص‌ها، شیب باقیمانده‌ی سن اندکی منفی می‌شود.\n"
            "- **چرا `fbs > 120` (`-0.1033`) نزدیک صفر است؟** تنها `45/303` بیمار قند ناشتای بالا داشته‌اند و شیوع بیماری در دو گروه "
            "تقریباً برابر است (`48.9%` در برابر `45.3%`, `p = 0.746`).\n"
            "- **چرا درد بدون علامت (`cp = 4`) ریسک را افزایش می‌دهد (`+1.0306`)؟** بیماران ارجاع‌شده به آنژیوگرافی بدون درد تیپیک معمولاً "
            "به علت ایسکمی خاموش یا تست ورزش غیرطبیعی ارجاع شده‌اند (سوگیری انتخاب مرکز ارجاع)."
        ),
        "age": "سن",
        "sex": "جنسیت",
        "cp": "نوع درد قفسه سینه",
        "trestbps": "فشار خون در حالت استراحت (mm Hg)",
        "chol": "کلسترول (mg/dl)",
        "fbs": "قند خون ناشتا",
        "restecg": "نوار قلب در حالت استراحت",
        "thalach": "حداکثر ضربان قلب",
        "exang": "آنژین ناشی از ورزش",
        "oldpeak": "افت قطعه ST (oldpeak)",
        "slope": "شیب قطعه ST",
        "ca": "تعداد رگ‌های اصلی رنگ‌شده در فلوروسکوپی (ca)",
        "thal": "نتیجه‌ی اسکن تالیوم (thal)",
        "card_arch_title": "معماری منبع واحد (`model.json` v2)",
        "card_arch_body": (
            "هر دو نسخه‌ی وب و موبایل (فاز ۲) دقیقاً فرمول خطی یکسانی را از `mobile_export/model.json` اجرا می‌کنند و فایل قدیمی `model.pkl` "
            "برای حذف ناهماهنگی بین پلتفرم‌ها از اجرای اصلی کنار گذاشته شده است."
        ),
        "card_internal_heading": "اعتبارسنجی داخلی کلیولند (10×5 CV تکراری طبقه‌بندی‌شده و آزمون مستقل)",
        "card_out_features": "ویژگی رمزگذاری‌شده",
        "card_col_metric": "معیار",
        "card_col_rep_cv": "اعتبارسنجی تکراری 10×5 (N=303)",
        "card_col_test61": "آزمون مستقل (N=61)",
        "card_metric_auc": "ROC-AUC",
        "card_metric_prauc": "PR-AUC",
        "card_metric_brier": "امتیاز Brier",
        "card_metric_ece": "خطای کالیبراسیون ECE",
        "card_metric_logloss": "Log-Loss",
        "card_fold_range_note": "بازه‌ها نشان‌دهنده‌ی بازه ۹۵٪ فولدها (صدک 2.5–97.5) در ۵۰ فولد هستند.",
        "card_train_cv_fmt": "اعتبارسنجی ۵تایی روی داده‌ی آموزش (N=242): `{mean:.4f} ± {std:.4f}`",
        "card_external_heading": "اعتبارسنجی خارجی بدون بازآموزی (`non_invasive_11` در بیمارستان‌های UCI)",
        "card_ext_col_cohort": "گروه بیمارستانی",
        "card_ext_col_n_prev": "تعداد (شیوع)",
        "card_ext_col_raw_auc": "AUC خام",
        "card_ext_col_raw_ece": "ECE خام",
        "card_ext_col_cln_auc": "AUC پاک‌سازی‌شده (`chol/trestbps=0 → NaN`)",
        "card_ext_col_cln_ece": "ECE پاک‌سازی‌شده",
        "card_ext_col_pred_obs": "میانگین پیش‌بینی در برابر مشاهده",
        "cohort_hungarian": "بیمارستان مجارستان (UCI Hungarian)",
        "cohort_switzerland": "بیمارستان سوئیس (UCI Switzerland)",
        "cohort_va": "بیمارستان لانگ‌بیچ (UCI VA)",
        "cohort_pooled_external": "تجمیع خارجی (Pooled)",
        "card_external_note": (
            "در داده‌های سوئیس (`100%`) و لانگ‌بیچ (`24.5%` کلسترول و `0.5%` فشار خون) مقادیر نامشخص به‌صورت `0` ثبت شده است. "
            "تبدیل مقادیر غیرممکن `chol/trestbps == 0` به `NaN` (جایگزینی با میانه‌ی کلیولند) تفکیک کلی را بهبود می‌دهد، اما تفاوت شدید شیوع بیماری بین بیمارستان‌ها دقت کالیبراسیون را کاهش می‌دهد."
        ),
        "card_attr": "منبع داده: UCI Machine Learning Repository — Heart Disease. فقط برای کاربرد آموزشی و پژوهشی.",
    },
}

UNKNOWN_SENTINEL = "unknown"

OPTION_LABELS: dict[str, dict[str, dict[int | str, str]]] = {
    "en": {
        "sex": {0: "Female", 1: "Male"},
        "cp": {1: "Typical angina", 2: "Atypical angina", 3: "Non-anginal pain", 4: "Asymptomatic"},
        "fbs": {0: "No (≤ 120 mg/dl)", 1: "Yes (> 120 mg/dl)"},
        "restecg": {0: "Normal", 1: "ST-T abnormality", 2: "LV hypertrophy"},
        "exang": {0: "No", 1: "Yes"},
        "slope": {1: "Upsloping", 2: "Flat", 3: "Downsloping"},
        "ca": {UNKNOWN_SENTINEL: "Not tested / Unknown", 0: "0", 1: "1", 2: "2", 3: "3"},
        "thal": {UNKNOWN_SENTINEL: "Not tested / Unknown", 3: "Normal", 6: "Fixed defect", 7: "Reversible defect"},
    },
    "fa": {
        "sex": {0: "زن", 1: "مرد"},
        "cp": {1: "آنژین تیپیک", 2: "آنژین آتیپیک", 3: "درد غیرآنژینی", 4: "بدون علامت"},
        "fbs": {0: "خیر (≤ 120 mg/dl)", 1: "بله (> 120 mg/dl)"},
        "restecg": {0: "طبیعی", 1: "ناهنجاری ST-T", 2: "هیپرتروفی بطن چپ"},
        "exang": {0: "خیر", 1: "بله"},
        "slope": {1: "صعودی", 2: "تخت", 3: "نزولی"},
        "ca": {UNKNOWN_SENTINEL: "آزمایش نشده / نامشخص", 0: "0", 1: "1", 2: "2", 3: "3"},
        "thal": {UNKNOWN_SENTINEL: "آزمایش نشده / نامشخص", 3: "طبیعی", 6: "نقص ثابت", 7: "نقص برگشت‌پذیر"},
    },
}


def _to_widget_val(col: str, val: Any) -> Any:
    if col == "oldpeak":
        return float(val)
    if val is None:
        return UNKNOWN_SENTINEL
    return int(val)


def init_state() -> None:
    """Initialize Streamlit session state with canonical Male-default inputs."""
    if "app_initialized" not in st.session_state:
        st.session_state["app_initialized"] = True
        st.session_state["lang"] = "en"
        st.session_state["mode_choice"] = "full_13"
    for col, val in DEFAULT_INPUTS.items():
        st.session_state.setdefault(f"input_{col}", _to_widget_val(col, val))


def apply_preset(preset_id: str) -> None:
    """Callback updating clinical inputs and mode before widgets render."""
    preset = CLINICAL_PRESETS[preset_id]
    for col, val in preset["inputs"].items():
        st.session_state[f"input_{col}"] = _to_widget_val(col, val)
    st.session_state["mode_choice"] = preset["expected_mode"]


def inject_rtl_css(lang: str) -> None:
    """Apply clean RTL layout when Persian is active while keeping charts/equations LTR."""
    if lang != "fa":
        return
    st.markdown(
        """
        <style>
        .stMarkdown, [data-testid="stAlert"], [data-testid="stExpander"],
        [data-testid="stMetric"], .stSelectbox label, .stNumberInput label,
        .stRadio label, h1, h2, h3, h4 {
            direction: rtl;
            text-align: right;
        }
        [data-testid="stVegaLiteChart"], .ltr-iso {
            direction: ltr;
            unicode-bidi: isolate;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def format_used_value(col: str, val: float, imputed: bool, lang: str) -> str:
    """Format feature value for human-readable charts and tables."""
    if imputed:
        return f"{val:g} ({TEXT[lang]['unknown_option']})"
    if col in OPTION_LABELS[lang]:
        int_val = int(round(val))
        label = OPTION_LABELS[lang][col].get(int_val, str(val))
        return f"{label} ({int_val})"
    if col == "oldpeak":
        return f"{val:.1f}"
    return f"{int(round(val))}"


def _stretch_kwargs(fn: Any) -> dict[str, Any]:
    """Pass width='stretch' on Streamlit >=1.50 and use_container_width=True on older releases."""
    if "width" in inspect.signature(fn).parameters:
        return {"width": "stretch"}
    return {"use_container_width": True}


def render_contributions_chart(result: PredictionResult, lang: str) -> None:
    """Render horizontal diverging bar chart of per-feature delta_z via Vega-Lite."""
    t = TEXT[lang]
    rows: list[dict[str, Any]] = []
    for c in result.contributions:
        label = t.get(c.feature, c.feature)
        if c.delta_z > 1e-12:
            direction = t["dir_risk"]
        elif c.delta_z < -1e-12:
            direction = t["dir_prot"]
        else:
            direction = t["dir_neutral"]
        rows.append(
            {
                "feature": label,
                "code": c.feature,
                "delta_z": round(c.delta_z, 4),
                "abs_delta_z": abs(c.delta_z),
                "value": format_used_value(c.feature, c.used_value, c.imputed, lang),
                "direction": direction,
            }
        )
    rows.sort(key=lambda r: r["abs_delta_z"], reverse=True)

    spec = {
        "data": {"values": rows},
        "width": "container",
        "height": max(280, 26 * len(rows)),
        "layer": [
            {
                "mark": {"type": "bar", "cornerRadiusEnd": 3},
                "encoding": {
                    "y": {
                        "field": "feature",
                        "type": "nominal",
                        "sort": {"field": "abs_delta_z", "order": "descending"},
                        "title": None,
                        "axis": {"labelLimit": 240},
                    },
                    "x": {
                        "field": "delta_z",
                        "type": "quantitative",
                        "title": t["chart_x_title"],
                    },
                    "color": {
                        "field": "direction",
                        "type": "nominal",
                        "scale": {
                            "domain": [t["dir_risk"], t["dir_prot"], t["dir_neutral"]],
                            "range": ["#d62728", "#1b9e77", "#7f7f7f"],
                        },
                        "legend": {"orient": "bottom", "title": None},
                    },
                    "tooltip": [
                        {"field": "feature", "type": "nominal", "title": t["col_feature"]},
                        {"field": "value", "type": "nominal", "title": t["col_value"]},
                        {"field": "delta_z", "type": "quantitative", "format": "+.4f", "title": t["col_dz"]},
                        {"field": "direction", "type": "nominal", "title": t["col_dir"]},
                    ],
                },
            },
            {
                "mark": {"type": "rule", "color": "#555555", "strokeWidth": 1.2},
                "encoding": {"x": {"datum": 0}},
            },
        ],
    }
    st.vega_lite_chart(spec, **_stretch_kwargs(st.vega_lite_chart))


def render_model_card(engine_spec: dict[str, Any], lang: str) -> None:
    """Render Model Card & External Validation tab directly from model.json metadata."""
    t = TEXT[lang]
    st.subheader(t["card_arch_title"])
    st.info(t["card_arch_body"])

    st.subheader(t["card_internal_heading"])
    st.caption(t["card_fold_range_note"])
    cols = st.columns(2)
    for col_widget, (mode_key, title) in zip(
        cols,
        [("full_13", t["mode_badge_full"]), ("non_invasive_11", t["mode_badge_ni"])],
    ):
        m = engine_spec["models"][mode_key]
        meta = m["metadata"]
        rep = meta["cv_10x5_repeated"]
        t61 = meta["test_61"]
        with col_widget:
            st.markdown(f"**{title}** — `C = {meta['C']}` (`{len(m['coef'])}` {t['card_out_features']})")
            st.markdown(
                f"""
| {t['card_col_metric']} | {t['card_col_rep_cv']} | {t['card_col_test61']} |
|---|---|---|
| {t['card_metric_auc']} | `{rep['roc_auc']['mean']:.3f} ± {rep['roc_auc']['std']:.3f}` (`[{rep['roc_auc']['fold_range_95'][0]:.3f}, {rep['roc_auc']['fold_range_95'][1]:.3f}]`) | `{t61['roc_auc']:.4f}` |
| {t['card_metric_prauc']} | `{rep['pr_auc']['mean']:.3f} ± {rep['pr_auc']['std']:.3f}` | `{t61['pr_auc']:.4f}` |
| {t['card_metric_brier']} | `{rep['brier']['mean']:.3f} ± {rep['brier']['std']:.3f}` | `{t61['brier']:.4f}` |
| {t['card_metric_ece']} | `{rep['ece_10bin']['mean']:.3f} ± {rep['ece_10bin']['std']:.3f}` | `{t61['ece_10bin']:.4f}` |
| {t['card_metric_logloss']} | `{rep['log_loss']['mean']:.3f} ± {rep['log_loss']['std']:.3f}` | `{t61['log_loss']:.4f}` |
"""
            )
            st.caption(
                t["card_train_cv_fmt"].format(
                    mean=meta["cv_5fold_train_auc"],
                    std=meta["cv_5fold_train_std"],
                )
            )

    ext = engine_spec.get("metadata", {}).get("external_validation")
    if ext:
        st.subheader(t["card_external_heading"])
        lines = [
            (
                f"| {t['card_ext_col_cohort']} | {t['card_ext_col_n_prev']} | "
                f"{t['card_ext_col_raw_auc']} | {t['card_ext_col_raw_ece']} | "
                f"{t['card_ext_col_cln_auc']} | {t['card_ext_col_cln_ece']} | "
                f"{t['card_ext_col_pred_obs']} |"
            ),
            "|---|---|---|---|---|---|---|",
        ]
        for key in ["hungarian", "switzerland", "va", "pooled_external"]:
            c = ext["cohorts"][key]
            raw = c["raw"]
            cln = c["impossible_zeros_as_nan"]
            cohort_name = t.get(f"cohort_{key}", c["label"])
            lines.append(
                f"| {cohort_name} | {c['n']} (`{c['prevalence']:.1%}`) | "
                f"`{raw['roc_auc']:.4f}` | `{raw['ece_10bin']:.4f}` | "
                f"`{cln['roc_auc']:.4f}` | `{cln['ece_10bin']:.4f}` | "
                f"`{cln['mean_pred_prob']:.3f}` / `{c['prevalence']:.3f}` |"
            )
        st.markdown("\n".join(lines))
        st.caption(t["card_external_note"])

    st.caption(t["card_attr"])


def main() -> None:
    init_state()
    engine = load_default_engine()

    top_left, top_right = st.columns([3, 1])
    with top_right:
        lang = st.radio(
            TEXT[st.session_state["lang"]]["lang_label"],
            options=["en", "fa"],
            format_func=lambda code: "English" if code == "en" else "فارسی",
            horizontal=True,
            key="lang",
        )

    inject_rtl_css(lang)
    t = TEXT[lang]
    opt_labels = OPTION_LABELS[lang]

    with top_left:
        st.title(f"🫀 {t['title']}")
        st.caption(t["subtitle"])

    st.warning(t["disclaimer"])

    tab_assess, tab_card = st.tabs([t["tab_assess"], t["tab_card"]])

    with tab_assess:
        st.subheader(t["presets_heading"])
        preset_cols = st.columns(4)
        for col_widget, (preset_id, preset) in zip(preset_cols, CLINICAL_PRESETS.items()):
            label = preset["label_en"] if lang == "en" else preset["label_fa"]
            help_text = preset["description_en"] if lang == "en" else preset["description_fa"]
            col_widget.button(
                label,
                key=f"preset_{preset_id}",
                help=help_text,
                on_click=apply_preset,
                args=(preset_id,),
                **_stretch_kwargs(col_widget.button),
            )

        mode_choice = st.radio(
            t["mode_label"],
            options=["full_13", "non_invasive_11"],
            format_func=lambda m: t["mode_full"] if m == "full_13" else t["mode_ni"],
            horizontal=True,
            key="mode_choice",
        )

        st.subheader(t["inputs_heading"])
        c1, c2 = st.columns(2)
        with c1:
            age = st.number_input(
                t["age"],
                min_value=int(NUMERIC_BOUNDS["age"][0]),
                max_value=int(NUMERIC_BOUNDS["age"][1]),
                step=1,
                key="input_age",
            )
            sex = st.selectbox(
                t["sex"],
                options=[0, 1],
                format_func=lambda v: opt_labels["sex"][v],
                key="input_sex",
            )
            cp = st.selectbox(
                t["cp"],
                options=[1, 2, 3, 4],
                format_func=lambda v: opt_labels["cp"][v],
                key="input_cp",
            )
            trestbps = st.number_input(
                t["trestbps"],
                min_value=int(NUMERIC_BOUNDS["trestbps"][0]),
                max_value=int(NUMERIC_BOUNDS["trestbps"][1]),
                step=1,
                key="input_trestbps",
            )
            chol = st.number_input(
                t["chol"],
                min_value=int(NUMERIC_BOUNDS["chol"][0]),
                max_value=int(NUMERIC_BOUNDS["chol"][1]),
                step=1,
                key="input_chol",
            )
            fbs = st.selectbox(
                t["fbs"],
                options=[0, 1],
                format_func=lambda v: opt_labels["fbs"][v],
                key="input_fbs",
            )
            restecg = st.selectbox(
                t["restecg"],
                options=[0, 1, 2],
                format_func=lambda v: opt_labels["restecg"][v],
                key="input_restecg",
            )

        with c2:
            thalach = st.number_input(
                t["thalach"],
                min_value=int(NUMERIC_BOUNDS["thalach"][0]),
                max_value=int(NUMERIC_BOUNDS["thalach"][1]),
                step=1,
                key="input_thalach",
            )
            exang = st.selectbox(
                t["exang"],
                options=[0, 1],
                format_func=lambda v: opt_labels["exang"][v],
                key="input_exang",
            )
            oldpeak = st.number_input(
                t["oldpeak"],
                min_value=float(NUMERIC_BOUNDS["oldpeak"][0]),
                max_value=float(NUMERIC_BOUNDS["oldpeak"][1]),
                step=0.1,
                key="input_oldpeak",
            )
            slope = st.selectbox(
                t["slope"],
                options=[1, 2, 3],
                format_func=lambda v: opt_labels["slope"][v],
                key="input_slope",
            )
            if mode_choice == "full_13":
                ca_raw = st.selectbox(
                    t["ca"],
                    options=[0, 1, 2, 3, UNKNOWN_SENTINEL],
                    format_func=lambda v: opt_labels["ca"][v],
                    key="input_ca",
                )
                thal_raw = st.selectbox(
                    t["thal"],
                    options=[3, 6, 7, UNKNOWN_SENTINEL],
                    format_func=lambda v: opt_labels["thal"][v],
                    key="input_thal",
                )
                ca = None if ca_raw == UNKNOWN_SENTINEL else ca_raw
                thal = None if thal_raw == UNKNOWN_SENTINEL else thal_raw
            else:
                ca = None
                thal = None
                st.info(t["non_invasive_omitted"])

        inputs: dict[str, Any] = {
            "age": age,
            "sex": sex,
            "cp": cp,
            "trestbps": trestbps,
            "chol": chol,
            "fbs": fbs,
            "restecg": restecg,
            "thalach": thalach,
            "exang": exang,
            "oldpeak": oldpeak,
            "slope": slope,
            "ca": ca,
            "thal": thal,
        }

        requested_mode = "auto" if mode_choice == "full_13" else "non_invasive_11"
        result = engine.predict(inputs, mode=requested_mode, validate=True)

        if mode_choice == "full_13" and result.mode == "non_invasive_11":
            st.info(t["auto_route_banner"])

        st.divider()
        st.subheader(t["result_heading"])

        m_col1, m_col2 = st.columns([2, 1])
        with m_col1:
            st.metric(t["prob_label"], f"{result.probability:.1%}")
            st.progress(float(result.probability))
        with m_col2:
            mode_badge = (
                t["mode_badge_full"] if result.mode == "full_13" else t["mode_badge_ni"]
            )
            st.metric(t["active_mode_label"], mode_badge)

        if result.risk_band == "low":
            st.success(t["band_low"])
        elif result.risk_band == "moderate":
            st.warning(t["band_moderate"])
        else:
            st.error(t["band_high"])
        st.caption(t["band_note"])

        dz_sum = sum(c.delta_z for c in result.contributions)
        eq_text = (
            f"intercept ({result.intercept:+.4f}) + Σ Δz ({dz_sum:+.4f}) = "
            f"z ({result.z:+.4f}) → sigmoid(z) = {result.probability:.4f} ({result.probability:.1%})"
        )
        st.markdown(f"**{t['eq_heading']}**")
        st.markdown(
            f'<div class="ltr-iso"><code>{html.escape(eq_text)}</code></div>',
            unsafe_allow_html=True,
        )

        st.markdown(f"**{t['chart_heading']}**")
        render_contributions_chart(result, lang)
        st.caption(t["chart_caption"])

        with st.expander(t["caveat_title"]):
            st.markdown(t["caveat_body"])

    with tab_card:
        render_model_card(engine.raw_spec, lang)


if __name__ == "__main__":
    main()
