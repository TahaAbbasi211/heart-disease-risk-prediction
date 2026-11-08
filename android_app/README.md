# heart_risk_offline — offline Android app

A small Flutter app that predicts heart-disease risk **entirely on the phone**.
There is no server, no API and no network access: the exported model is a JSON
file bundled inside the APK and all the maths happens locally.

> **Educational project. NOT a medical diagnostic tool.**
> The risk bands are illustrative cut-offs, not clinical thresholds.

---

## What is in here

| Path | What it is |
|---|---|
| `lib/main.dart` | the whole UI: one form screen with the 13 inputs, validation and the result card |
| `lib/heart_model.dart` | the entire "machine learning": reads `model.json` and runs the formula |
| `lib/strings.dart` | every piece of app text, in English and Persian (`AppStrings`) |
| `lib/input_parsing.dart` | accepts Persian/Arabic digits and both decimal separators |
| `assets/model.json` | copy of `../mobile_export/model.json` — the exported model |
| `assets/fonts/` | Vazirmatn Regular + Bold (SIL OFL), used only in Persian |
| `test/heart_model_test.dart` | unit tests comparing the Dart maths against scikit-learn |
| `test/input_parsing_test.dart` | unit tests for the Persian/Arabic number parsing |
| `test/localization_test.dart` | string-map and widget tests for both languages |
| `test/golden_cases.json` | copy of `../mobile_export/golden_cases.json` — the expected probabilities |
| `android/` | the Android wrapper (manifest, package id, Gradle config) |

The app id is `com.example.heartrisk` and the Flutter project name is
`heart_risk_offline`.

---

## Languages

The app ships **English (`en`) and Persian (`fa`)**.

* **English is the default.** A device whose language the app does not ship
  gets English.
* A device set to Persian starts in Persian (right-to-left).
* The button in the AppBar switches language at runtime. It is labelled with the
  language you would switch **to**: it reads **فارسی** in the English UI and
  **English** in the Persian UI.
* **The choice is not saved.** There is no `shared_preferences`, no database and
  no file writing anywhere in the app — reopen it and you are back to the device
  language. That is deliberate: the app stores nothing.

### What changes with the language, and what does not

Only **labels** are translated. This distinction is the safety property of the
whole design:

| Changes with the language | Never changes |
|---|---|
| field labels, dropdown option text, button text | the numeric **codes** sent to the model (`cp` 1–4, `thal` 3/6/7, `sex` 0/1, ...) |
| validation messages, risk-band wording, disclaimer | the imputation statistics, scaling, coefficients — i.e. `assets/model.json` |
| text direction (LTR ⇄ RTL) | the digits used to **display** numbers (always Latin: `55`, `12.5%`) |

So `Typical angina` becomes `آنژین تیپیک` on screen, but the model still
receives `cp = 1`. A test asserts the code lists directly
(`localization_test.dart`, "the dropdown values keep the same numeric codes"),
and the golden-case tests assert that entering the same patient in either
language produces the same percentage.

### Entering numbers in Persian

A Persian keyboard can produce digits that look familiar but are different
characters:

```
Latin         0 1 2 3 4 5 6 7 8 9   U+0030..U+0039
Persian       ۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹   U+06F0..U+06F9
Arabic-Indic  ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩   U+0660..U+0669
```

`double.tryParse("۱۲")` returns `null`, so without help a Persian user typing
`۵۵` would see "must be a number". `lib/input_parsing.dart` therefore:

* converts Persian and Arabic-Indic digits to Latin ones,
* converts the Arabic decimal separator `٫` (U+066B) to `.`,
* treats a single `,` as the decimal point when there is no `.` (`1,5` → `1.5`),
* returns `null` for empty or genuinely invalid input.

The `TextField` formatter is set up not to **delete** those digits as you type
(a Latin-only filter would silently swallow them).

### Adding a third language

1. Add the language code to `kSupportedLocales` in `lib/strings.dart`.
2. Copy `kEnglishStrings`, translate the values, and keep **every key
   identical**. Add the new map to `AppStrings.mapFor` (and its font choice in
   `strings.dart` / the `MaterialApp` builder if the script needs one).
3. Add the language to the toggle in `HeartRiskApp` in `lib/main.dart`.
4. Run `flutter test`. The suite fails if any key is missing or has an empty
   value, which is exactly the mistake that is easy to make.

Because only labels are translated, no change to `lib/heart_model.dart` or
`assets/model.json` is ever needed to add a language.

### The Persian font

Persian text is rendered with **Vazirmatn** (`assets/fonts/`), an open-source
font under the SIL Open Font License. Only Regular (400) and Bold (700) are
bundled; the licence text is next to them in `assets/fonts/OFL.txt`.

It is applied **only when Persian is active** (see the `MaterialApp` `builder`
in `lib/main.dart`), so the English UI keeps the platform font and looks exactly
as it did before Persian was added.

---

## The formula the app runs

```
1. numeric (age, trestbps, chol, thalach, oldpeak)
       missing -> median, then (value - mean) / scale
2. categorical (sex, cp, fbs, restecg, exang, slope, ca, thal)
       missing -> mode, then one-hot; an unseen category -> all zeros
3. z    = intercept + sum(coef[i] * x[i])
4. prob = 1 / (1 + exp(-z))
```

That is 5 numeric values + 23 one-hot columns = **28 numbers** into the model.
`lib/heart_model.dart` implements exactly this, and `verify_formula.py` in
`../mobile_export/` proves the same recipe matches scikit-learn on all 303 rows
of the dataset.

---

## Requirements

| Tool | Version used here |
|---|---|
| Flutter | 3.47.9 (stable), Dart 3.13.7 |
| JDK | 17 (Microsoft OpenJDK 17.0.13) |
| Android SDK | platform-36, build-tools 36.0.0, platform-tools |
| Gradle | 9.3.1 (downloaded automatically by the wrapper) |

Check your setup with:

```bash
flutter doctor -v
java -version
```

The Android toolchain needs `ANDROID_HOME` (or `sdk.dir` in
`android/local.properties`) pointing at your SDK, and `JAVA_HOME` pointing at a
JDK 17. On this machine they live in `F:\dev\android-sdk` and `F:\dev\jdk17`,
which is what `android/local.properties` records.

> Note for this machine only: `dl.google.com` and `repo.maven.apache.org` are
> intercepted on this network, so the tracked Gradle files deliberately contain
> **no** mirror URLs — they list the official `google()` / `mavenCentral()`
> repositories, exactly as a normal checkout does. The mirrors needed to build
> here are injected from **outside the repository**, by a Gradle init script at
> `%USERPROFILE%\.gradle\init.d\aliyun-mirrors.gradle`. Nothing in this repo
> references a mirror, so a normal machine builds unchanged. You can confirm
> that with:
>
> ```bash
> findstr /s /i /n "tencent aliyun" android\*.properties android\*.kts
> ```
>
> which prints nothing.
>
> **If you rebuild on this machine** you will need the mirrors to be visible to
> the `:app` project, not just to settings: this root project declares its own
> `repositories { }` block, and Gradle then ignores settings-level repositories
> for `:app`'s dependencies. The init script alone was therefore not enough when
> the release APK for this project was built; the two `maven.aliyun.com` lines
> were temporarily added to `android/build.gradle.kts` and
> `android/settings.gradle.kts`, the build was run, and both files were restored
> to the official URLs afterwards. If you need to repeat that, re-add the lines,
> build, then revert them — the goal is that the committed files stay
> mirror-free.

---

## Run the tests

```bash
cd android_app
flutter test
```

Expected output ends with `All tests passed!`. The suite prints how many golden
cases it checked; all 15 must match scikit-learn within `1e-6`.

Recorded run for this project (`flutter test`, version 1.1.0):

```
00:07 +46: All tests passed!
```

That is 5 formula tests, 27 number-parsing tests and 19 localization/widget
tests. `flutter analyze` reports `No issues found!`.

Static analysis:

```bash
flutter analyze
```

---

## Build the release APK

```bash
cd android_app
flutter build apk --release
```

The result is written to:

```
android_app/build/app/outputs/flutter-apk/app-release.apk
```

A copy is kept in the repository at `../releases/heart-risk-offline-v1.1.0.apk`.

Recorded from the build performed for this project (version `1.1.0+2`, the
bilingual release):

```
√ Built build\app\outputs\flutter-apk\app-release.apk (47.1MB)

size   : 49,361,294 bytes (47.08 MB)
sha256 : 374e9f55ddd11ed84e2233fac680c94bf46be1ed73cb1b9a39e446937f2387eb
```

Verified properties of that APK (`aapt dump badging` / `aapt dump permissions`):

| Property | Value |
|---|---|
| package | `com.example.heartrisk` |
| versionName / versionCode | `1.1.0` / `2` |
| label (default) | `Heart Risk` |
| label (Persian, `values-fa`) | `ریسک قلبی` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| permissions | only `com.example.heartrisk.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (an AndroidX-internal signature permission) — **no INTERNET** |
| bundled model | `assets/flutter_assets/assets/model.json` (4,210 bytes) |
| bundled fonts | `assets/flutter_assets/assets/fonts/Vazirmatn-Regular.ttf` (122,752 bytes) and `Vazirmatn-Bold.ttf` (123,036 bytes) |

The release build is signed with the **debug key**, which is fine for
sideloading onto your own phone but is **not** suitable for publishing to an app
store.

---

## Install it on a phone

1. Copy `releases/heart-risk-offline-v1.1.0.apk` to the phone (USB, or any file
   transfer you like).
2. On the phone, allow installing apps from unknown sources for the app you use
   to open the file.
3. Tap the APK and install it.
4. Open **Heart Risk** and tap **Predict** after filling in the 13 values.

The APK is built for the `release` variant, whose manifest contains **no
INTERNET permission** — so the app cannot use the network even in principle. You
can verify this on the built APK:

```bash
# from android_app/, using the build-tools aapt
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

The output should list no `android.permission.INTERNET` entry.

---

## Run it in development

```bash
cd android_app
flutter run            # with a device or emulator connected
```

Flutter's *debug* and *profile* manifests do declare the INTERNET permission —
that is how the Flutter tool talks to the running app during development. Those
manifests are not used by a release build.

---

## Privacy

No analytics, no tracking, no data storage, no network calls. The values you
type are used to compute a number on the device and are never sent anywhere or
written to disk.
