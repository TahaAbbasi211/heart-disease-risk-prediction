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
| `assets/model.json` | copy of `../mobile_export/model.json` — the exported model |
| `test/heart_model_test.dart` | unit tests comparing the Dart maths against scikit-learn |
| `test/golden_cases.json` | copy of `../mobile_export/golden_cases.json` — the expected probabilities |
| `android/` | the Android wrapper (manifest, package id, Gradle config) |

The app id is `com.example.heartrisk` and the Flutter project name is
`heart_risk_offline`.

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

> Note for this machine only: `dl.google.com` is unreachable here, so
> `android/settings.gradle.kts` and `android/build.gradle.kts` list
> `maven.aliyun.com` mirrors before the official repositories, and
> `android/gradle/wrapper/gradle-wrapper.properties` points at a mirror.
> On a normal machine the official repositories work unchanged.

---

## Run the tests

```bash
cd android_app
flutter test
```

Expected output ends with `All tests passed!`. The suite prints how many golden
cases it checked; all 15 must match scikit-learn within `1e-6`.

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

A copy is kept in the repository at `../releases/heart-risk-offline.apk`.

Recorded from the build performed for this project:

```
√ Built build\app\outputs\flutter-apk\app-release.apk (46.1MB)

size   : 48,388,481 bytes (46.15 MB)
sha256 : 7B1344BF303CC313756ACA8C88BE2001375789B0BD863B5EFF2DC52893775CC0
```

Verified properties of that APK (`aapt dump badging` / `aapt dump permissions`):

| Property | Value |
|---|---|
| package | `com.example.heartrisk` |
| label | `Heart Risk` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| permissions | only `com.example.heartrisk.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (an AndroidX-internal signature permission) — **no INTERNET** |
| bundled model | `assets/flutter_assets/assets/model.json` (4,210 bytes) |

The release build is signed with the **debug key**, which is fine for
sideloading onto your own phone but is **not** suitable for publishing to an app
store.

---

## Install it on a phone

1. Copy `releases/heart-risk-offline.apk` to the phone (USB, or any file
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
