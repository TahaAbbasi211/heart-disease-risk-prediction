# Persian translations to review

This file lists the Persian text added to the Android app
(`android_app/lib/strings.dart`).

It has two parts:

1. **Strings you supplied** — used verbatim, nothing decided by me. Listed so you
   can confirm they were applied exactly as written.
2. **Strings I had to write myself** — these are the ones worth your review.
   They are mostly short helper and error texts that were not in your list.

The app also relies on Flutter's own Persian translations
(`flutter_localizations`) for Material internals such as the text-selection
menu and the dropdown scrollbar. Those are not shown here because they do not
come from this project.

A note on the `{...}` braces below: they are placeholders the code fills in at
runtime, e.g. `{min}` becomes `20`. They are not shown to the user.

---

## 1. Strings you supplied (used verbatim)

| # | English | Persian | Where it appears |
|---|---|---|---|
| 1 | Heart Disease Risk Prediction *(app title)* | ریسک بیماری قلبی | AppBar title |
| 2 | Heart Risk *(launcher name)* | ریسک قلبی | Android home screen (`values-fa/strings.xml`) |
| 3 | Age | سن | numeric field label |
| 4 | Sex | جنسیت | dropdown label |
| 5 | Female | زن | Sex option |
| 6 | Male | مرد | Sex option |
| 7 | Chest pain type | نوع درد قفسه سینه | dropdown label |
| 8 | Typical angina | آنژین تیپیک | cp option (code 1) |
| 9 | Atypical angina | آنژین آتیپیک | cp option (code 2) |
| 10 | Non-anginal pain | درد غیرآنژینی | cp option (code 3) |
| 11 | Asymptomatic | بدون علامت | cp option (code 4) |
| 12 | Resting blood pressure (mm Hg) | فشار خون در حالت استراحت (mm Hg) | numeric field label |
| 13 | Cholesterol (mg/dl) | کلسترول (mg/dl) | numeric field label |
| 14 | Fasting blood sugar | قند خون ناشتا | dropdown label |
| 15 | No (≤ 120 mg/dl) | خیر (≤ 120 mg/dl) | fbs option (code 0) |
| 16 | Yes (> 120 mg/dl) | بله (> 120 mg/dl) | fbs option (code 1) |
| 17 | Resting ECG | نوار قلب در حالت استراحت | dropdown label |
| 18 | Normal | طبیعی | restecg option (code 0) and thal option (code 3) |
| 19 | ST-T abnormality | ناهنجاری ST-T | restecg option (code 1) |
| 20 | LV hypertrophy | هیپرتروفی بطن چپ | restecg option (code 2) |
| 21 | Max heart rate achieved | حداکثر ضربان قلب | numeric field label |
| 22 | Exercise-induced angina | آنژین ناشی از ورزش | dropdown label |
| 23 | No | خیر | exang option (code 0) |
| 24 | Yes | بله | exang option (code 1) |
| 25 | ST depression (oldpeak) | افت قطعه ST (oldpeak) | numeric field label |
| 26 | ST segment slope | شیب قطعه ST | dropdown label |
| 27 | Upsloping | صعودی | slope option (code 1) |
| 28 | Flat | تخت | slope option (code 2) |
| 29 | Downsloping | نزولی | slope option (code 3) |
| 30 | Major vessels colored by fluoroscopy | تعداد رگ‌های اصلی رنگ‌شده در فلوروسکوپی | dropdown label |
| 31 | Thallium test result | نتیجه‌ی اسکن تالیوم | dropdown label |
| 32 | Fixed defect | نقص ثابت | thal option (code 6) |
| 33 | Reversible defect | نقص برگشت‌پذیر | thal option (code 7) |
| 34 | Predict | پیش‌بینی | button |
| 35 | Estimated probability of heart disease | احتمال تخمینی بیماری قلبی | result card heading |
| 36 | Lower risk band | ریسک کمتر | result card, below 35% |
| 37 | Moderate risk band | ریسک متوسط | result card, 35–65% |
| 38 | Higher risk band | ریسک بالاتر | result card, above 65% |
| 39 | *risk-band note* | این بازه‌های ریسک فقط برای نمایش هستند و آستانه‌ی بالینی نیستند. | result card footnote |
| 40 | *disclaimer* | این برنامه یک پروژه‌ی آموزشی است و ابزار تشخیص پزشکی نیست. جایگزین مراجعه به پزشک نیست. | amber card at the top, always visible |

---

## 2. Strings I wrote (please review these)

Your list did not cover the app's helper text and error messages, so I wrote
them. I kept your tone — plain, second-person, no bureaucratic wording.

### 2a. Continuation of the strings you supplied

Three strings you gave me end mid-sentence and the app completes them, so I
supplied the second half.

| # | English | Persian | Where it appears | Note |
|---|---|---|---|---|
| 41 | (continuation of the disclaimer) *"This app runs entirely on your phone, with no internet connection."* | این برنامه کاملاً روی گوشی شما و بدون اتصال به اینترنت اجرا می‌شود. | amber card, second line | Your disclaimer text was the first sentence; I added this second line to match the English app, which also states it runs offline. **Say the word if you would rather drop this line.** |
| 42 | (continuation of the band note) *"This is an educational project and must not be used for medical decisions."* | این یک پروژه‌ی آموزشی است و نباید مبنای تصمیم پزشکی قرار گیرد. | result card footnote | Your band note was the first sentence. The English version adds this warning, so I added its Persian equivalent. |

### 2b. The language toggle

| # | English | Persian | Where it appears | Note |
|---|---|---|---|---|
| 43 | فارسی *(shown while English is active)* | فارسی | AppBar button | Per your instruction, the button names the language it switches **to**. In the English UI it reads «فارسی»; in the Persian UI it reads «English». |
| 44 | English *(shown while Persian is active)* | English | AppBar button | Left in Latin script on purpose — a Persian reader looking to switch away is looking for the word "English". |

### 2c. Range helper text under each number field

| # | English | Persian | Where it appears |
|---|---|---|---|
| 45 | Range: {min} - {max} | بازه: {min} - {max} | helper line under the five numeric fields |
| 46 | Range *(short form, currently unused)* | بازه | kept for completeness |

Note: the digits in these lines stay Latin in both languages (`بازه: 20 - 100`),
matching your rule that numbers are always displayed with Latin digits.

### 2d. Validation messages

These appear in red under the Predict button. `{field}` is filled with the
field's own label, so the message reads e.g. «مقدار سن باید بین 20 و 100 باشد.»

| # | English | Persian | Where it appears | Note |
|---|---|---|---|---|
| 47 | {field} must be a number. | مقدار {field} باید یک عدد باشد. | red text, unparsable input | |
| 48 | {field} must be between {min} and {max}. | مقدار {field} باید بین {min} و {max} باشد. | red text, out of range | Written to match the phrasing you specified. |
| 49 | Please enter a value for {field}. | لطفاً مقدار {field} را وارد کنید. | red text, empty field | Uses the same «لطفاً … را وارد کنید» pattern you gave. |

### 2e. Model-loading messages

Only reachable if the bundled model file is missing or corrupt — in a normal
install the user never sees these.

| # | English | Persian | Where it appears |
|---|---|---|---|
| 50 | The model is still loading, please wait. | مدل هنوز در حال بارگذاری است، لطفاً کمی صبر کنید. | shown instead of the form if Predict is tapped before the asset loads |
| 51 | Could not load the model: {error} | بارگذاری مدل ممکن نشد: {error} | shown instead of the form if `assets/model.json` cannot be parsed |

`{error}` is the raw Dart exception text. It stays in English because it is a
technical diagnostic, not user-facing prose.

---

## 3. Choices worth a second look

A few decisions that are judgment calls rather than translations. None of them
affects the model — only wording and appearance.

| Topic | What I did | Why |
|---|---|---|
| Digits | The percentage, the range hints and the `ca` dropdown (`0`–`3`) all use Latin digits in **both** languages. | Your instruction. It also means a Persian reader sees the same numbers a doctor would write on a chart. |
| Half-space (ZWNJ) | Used in Persian compounds: «رنگ‌شده», «پیش‌بینی», «نتیجه‌ی», «بازه‌های». | Standard Persian typography; without it the words look run together. |
| Latin medical abbreviations | Kept `ST`, `ST-T`, `mm Hg`, `mg/dl`, `oldpeak`, `ECG` in Latin script inside the Persian text. | These are the terms printed on lab reports and ECGs in Iran, so translating them would make the form harder to match against a real report. |
| «آنژین» | Transliterated rather than translated to «درد قفسه سینه». | «آنژین» is the term Persian-speaking patients and clinicians actually use. |
| «تالیوم» | Transliterated (thallium), with «اسکن» added: «نتیجه‌ی اسکن تالیوم». | The English label is "Thallium test result"; «اسکن» makes it clear a scan is meant. |
| Dropdown width | The dropdowns use the full available width. | Several Persian labels are much longer than their English counterparts (e.g. «تعداد رگ‌های اصلی رنگ‌شده در فلوروسکوپی»); this stops them from being clipped. |
| Font | Vazirmatn is applied **only** in Persian; English keeps the platform font. | So the English UI is pixel-identical to the previous release. |
| Probability in the progress bar | The bar still fills according to the probability value; in Persian it simply grows from the right. | RTL does not change the number, only the direction it is drawn. |

---

## 4. How to change any of this

Every string lives in one file: `android_app/lib/strings.dart`, in the
`kEnglishStrings` and `kPersianStrings` maps. Edit the Persian value, keep the
key unchanged, and run:

```bash
cd android_app
flutter test
```

The test suite checks that both maps have exactly the same keys and that no
Persian value is empty, so a mistyped key is caught immediately.
