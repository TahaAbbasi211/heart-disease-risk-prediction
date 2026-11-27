# BIOVANTA · HEART (`ir.biovanta.heartrisk`) — Offline Android App `V2.0.0`

A native Flutter clinical probability instrument that evaluates Cleveland heart-disease risk **100% offline on the phone**. There is no server, no API, no analytics, no persistent storage, and no `INTERNET` permission: the app bundles `assets/model.json` (`heart-risk-linear-formula/2`, copied byte-for-byte from `../mobile_export/model.json`) and runs the exact additive log-odds equations locally in RAM.

> **Disclaimer:** Educational project. Risk bands (`<35%` lower, `35–65%` moderate, `≥65%` higher — read from `risk_bands` in `model.json`) are illustrative cut-offs, not clinical thresholds. Not for medical decisions.

---

## Architecture & File Map

| Path | What it is |
|---|---|
| `lib/main.dart` | `HeartRiskApp` root wiring `appThemeModeNotifier`, `appLocaleNotifier`, RTL directionality, and `Vazirmatn` font (`fa` only) |
| `lib/heart_model.dart` | Dependency-free schema v2 inference engine (`full_13` with 28 features, `non_invasive_11` with 21 features, JSON-loaded `risk_bands`, two-branch `stableSigmoid`, clinical auto-routing, `HeartValidationException`, internal & external validation metadata) |
| `lib/presets.dart` | Canonical defaults (`sex=1.0` Male) and 4 one-tap clinical presets matching `heart_risk/presets.py` |
| `lib/l10n/strings.dart` | Complete English & Persian (`en` / `fa`) UI string tables (`AppStrings` & `AppStringsDelegate`) — labels only, numeric codes invariant |
| `lib/input_parsing.dart` | Localized number parser (Latin `0-9`, Persian `۰-۹`, Arabic-Indic `٠-٩`, `.` / `٫` / single `,`) |
| `lib/ui/theme.dart` | BioVanta **Obsidian Dark** & **Clinical Paper Light** dual theme + tabular figure helpers |
| `lib/ui/heart_controller.dart` | Reactive `ChangeNotifier` managing inputs, mode routing, live validation, and What-If sensitivity state |
| `lib/ui/instrument_shell.dart` | 3-destination Floating Glass Dock shell (`Assess`, `Explain`, `Lab & Info`) |
| `lib/ui/assess_tab.dart` | Live gauge hero card, clinical safety auto-routing banner, preset deck, mode switcher, grouped clinical inputs |
| `lib/ui/explain_tab.dart` | Exact logistic equation card, diverging `Δz` chart (`widgets/delta_z_chart.dart`), interactive What-If sliders, Cleveland collinearity caveat |
| `lib/ui/lab_info_tab.dart` | Theme/language controls, dynamic `10×5` repeated CV & held-out `test_61` tables, zero-retraining UCI external validation table, offline privacy summary |
| `assets/model.json` | Byte-for-byte copy of `../mobile_export/model.json` (`16,961` bytes) |
| `assets/fonts/` | `Vazirmatn-Regular.ttf` (`122,752` bytes) and `Vazirmatn-Bold.ttf` (`123,036` bytes), SIL OFL |
| `test/golden_cases.json` | Byte-for-byte copy of `../mobile_export/golden_cases.json` (`27` golden vectors across `full_13` & `non_invasive_11`) |
| `test/heart_model_test.dart` | Schema v2 parity (`< 1e-12` on all 27 golden cases), byte-for-byte asset SHA-256 check, auto-routing safety trap (`row 292`), validation/bounds, `stableSigmoid`, preset verification |
| `test/input_parsing_test.dart` | Multi-script number & separator parsing tests |
| `test/localization_test.dart` | EN/FA key parity, preserved clinical terminology, zero storage/network dependency guard, RTL/LTR toggle widget test |
| `test/widget_test.dart` | Theme toggle, presets, mode switching, unknown `ca`/`thal` auto-routing banner, Explain & Lab tabs, and `360×640` `1.3×` text-scale overflow checks |
| `android/` | Kotlin wrapper (`ir.biovanta.heartrisk`), adaptive BioVanta launcher icon, R8 rules (`proguard-rules.pro`), fail-closed signing config (`SIGNING.md`, `signing_setup.ps1`) |

---

## Dual-Mode Clinical Inference & Safety Auto-Routing

`HeartModel.predict(inputs, mode: ...)` implements schema **`heart-risk-linear-formula/2`**:

1. **Numeric (`age`, `trestbps`, `chol`, `thalach`, `oldpeak`):** `null` → training median, then `(value - mean) / scale`.
2. **Categorical (`full_13`: `sex`, `cp`, `fbs`, `restecg`, `exang`, `slope`, `ca`, `thal`; `non_invasive_11`: omits `ca`, `thal`):** `null` → training mode, then one-hot encoding (`handle_unknown="ignore"` parity when `validate: false`).
3. **Log-odds & Probability:** `z = intercept + sum(coef[i] * x[i])`, `probability = stableSigmoid(z)`.
4. **Clinical Safety Auto-Routing (`mode: "auto"`):** If either fluoroscopy (`ca`) or thallium (`thal`) is marked **Not tested / Unknown** (`null`), inference automatically routes to **`non_invasive_11`** (`21` features) instead of silently imputing `ca=0, thal=3` (which would falsely lower log-odds by `-2.0389`, misclassifying symptomatic patients such as Cleveland row `292`). A cyan safety banner explains the active route in real time.

---

## Bilingual Localization (`en` / `fa`) & Multi-Script Digits

- **English (`en`)** and **Persian (`fa`, RTL with Vazirmatn)** toggle live from the top header bar or Lab & Info tab (`appLocaleNotifier` in RAM only — zero disk persistence).
- Only **display labels** change; internal numeric clinical codes (`cp` `1..4`, `thal` `3/6/7`, `sex` `0/1`, etc.) and Latin telemetry numbers (`5.6%`, `-2.0389`, range hints) remain invariant.
- `lib/input_parsing.dart` normalizes Persian (`۰-۹`), Arabic-Indic (`٠-٩`), and Latin (`0-9`) digits as well as `.` / `٫` / single `,` decimal separators.

---

## Requirements & Running Tests

| Tool | Verified Version |
|---|---|
| Flutter | `3.47.9` (`stable`), Dart `3.13.7` |
| JDK | Eclipse Temurin OpenJDK `21.0.13` (`JAVA_HOME` for Gradle / AGP) |
| Android SDK | `compileSdk` `36`, `minSdk` `24`, `targetSdk` `36`, `build-tools` `35.0.0` / `36.0.0` |
| Gradle | `9.3.1` |

Run static analysis and the full automated test suite:

```bash
cd android_app
flutter pub get
flutter analyze
flutter test
```

Latest verified run:

```
Analyzing android_app...
No issues found! (ran in 7.7s)

00:06 +42: All tests passed!
```

Tracked Gradle files (`android/build.gradle.kts`, `android/settings.gradle.kts`) contain **only** official `google()` / `mavenCentral()` repositories — no mirror URLs.

---

## Release Builds, Split-ABI, R8 & Signing

Release APKs enable R8 code shrinking (`isMinifyEnabled = true`), resource shrinking (`isShrinkResources = true`), Material Icon tree-shaking (`1,645,184 → 4,116 bytes`), and **fail-closed release signing**:

* **Without `android/key.properties`:** `flutter build apk --release` fails intentionally with:
  `Release build requires android_app/android/key.properties (see android_app/android/SIGNING.md).`
* **Production signed release:** Generate a local keystore via `android/signing_setup.ps1` (see [`android/SIGNING.md`](android/SIGNING.md)), keeping `key.properties` and `*.jks` out of git, then run:
  ```bash
  cd android_app
  flutter build apk --release --split-per-abi
  ```
* **Local debug-signed preview build (sideloading onto your own phone):**
  ```bash
  cd android_app
  flutter build apk --release --split-per-abi --android-project-arg allowDebugRelease=true
  ```

### Staged `V2.0.0` Split-ABI Preview APKs (Verified Locally)

| ABI | Staged Path | Exact Size | `versionCode` | SHA-256 |
|---|---|---|---|---|
| `arm64-v8a` | `../releases/heart-risk-v2.0.0-arm64-v8a.apk` | `17,834,918` bytes (`17.01 MB`) | `2003` | `F36033074EF1364E3CB529FD3696FC3CBD4DB61DE0291094D18FEFE0761B5294` |
| `armeabi-v7a` | `../releases/heart-risk-v2.0.0-armeabi-v7a.apk` | `15,254,270` bytes (`14.55 MB`) | `1003` | `E496220173E37921D47CDAD2D00EB45DA23AD053EB4BC1B30E9F13E58F9BA4EA` |

Verified `aapt` inspection on both `releases/heart-risk-v2.0.0-*.apk`:

* **Package & Version:** `ir.biovanta.heartrisk`, `versionName='2.0.0'`, `sdkVersion:'24'`, `targetSdkVersion:'36'`
* **Launcher Labels:** default `Heart Risk`, Persian (`application-label-fa`) `ریسک قلبی`
* **Merged Permissions (`aapt dump permissions`):** ONLY `ir.biovanta.heartrisk.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — **zero `android.permission.INTERNET`**

Verify yourself on any built APK:

```bash
aapt dump permissions releases/heart-risk-v2.0.0-arm64-v8a.apk
```

Note: Debug and profile builds still include Flutter's tooling `INTERNET` permission during development (`flutter run`); release builds strip it completely.
