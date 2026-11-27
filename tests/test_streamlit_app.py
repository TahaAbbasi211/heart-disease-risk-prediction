"""Headless Streamlit AppTest smoke tests for bilingual dual-mode app.py."""

from __future__ import annotations

from pathlib import Path

from streamlit.testing.v1 import AppTest

ROOT = Path(__file__).resolve().parent.parent
APP_PATH = str(ROOT / "app.py")


def test_initial_render() -> None:
    at = AppTest.from_file(APP_PATH, default_timeout=30).run()
    assert not at.exception
    assert len(at.warning) >= 1
    assert any("Educational" in w.value for w in at.warning)
    assert len(at.metric) >= 2
    assert at.metric[0].value == "5.6%"
    assert "Full Clinical" in at.metric[1].value


def test_language_toggle_en_fa_and_persian_model_card() -> None:
    at = AppTest.from_file(APP_PATH, default_timeout=30).run()
    assert not at.exception

    at.radio(key="lang").set_value("fa").run()
    assert not at.exception
    assert any("پیش‌بینی ریسک بیماری قلبی" in t.value for t in at.title)
    assert any("آموزشی" in w.value for w in at.warning)

    all_markdown = "\n".join(m.value for m in at.markdown)
    all_captions = "\n".join(c.value for c in at.caption)
    assert "معیار" in all_markdown
    assert "بیمارستان مجارستان" in all_markdown
    assert "اعتبارسنجی ۵تایی روی داده‌ی آموزش" in all_captions
    for leaked in ("Held-Out Test", "5-fold train CV ROC-AUC", "Raw AUC", "Mean Pred vs Obs"):
        assert leaked not in all_markdown
        assert leaked not in all_captions

    at.radio(key="lang").set_value("en").run()
    assert not at.exception
    assert any("Heart Disease Risk Prediction" in t.value for t in at.title)


def test_mode_toggle_and_unknown_ca_thal_auto_routing() -> None:
    at = AppTest.from_file(APP_PATH, default_timeout=30).run()
    assert not at.exception

    at.radio(key="mode_choice").set_value("non_invasive_11").run()
    assert not at.exception
    assert "Non-Invasive Screening" in at.metric[1].value

    at.radio(key="mode_choice").set_value("full_13").run()
    assert not at.exception
    at.selectbox(key="input_ca").set_value("unknown").run()
    assert not at.exception
    assert "Non-Invasive Screening" in at.metric[1].value
    assert any("non_invasive_11" in i.value for i in at.info)

    at.selectbox(key="input_ca").set_value(0).run()
    at.selectbox(key="input_thal").set_value("unknown").run()
    assert not at.exception
    assert "Non-Invasive Screening" in at.metric[1].value
    assert any("non_invasive_11" in i.value for i in at.info)


def test_clinical_presets_update_predictions() -> None:
    at = AppTest.from_file(APP_PATH, default_timeout=30).run()
    assert not at.exception

    at.button(key="preset_low_risk").click().run()
    assert not at.exception
    assert len(at.success) >= 1
    assert "Full Clinical" in at.metric[1].value

    at.button(key="preset_moderate_risk").click().run()
    assert not at.exception
    assert any("Moderate" in w.value for w in at.warning)

    at.button(key="preset_high_risk_full").click().run()
    assert not at.exception
    assert len(at.error) >= 1
    assert "Full Clinical" in at.metric[1].value

    at.button(key="preset_high_risk_non_invasive").click().run()
    assert not at.exception
    assert len(at.error) >= 1
    assert "Non-Invasive Screening" in at.metric[1].value
