// strings.dart
//
// Bilingual English / Persian localization for BIOVANTA · HEART V2.0.0.
// Only display labels change with language; numeric model codes never change.

import 'package:flutter/widgets.dart';

/// Active runtime locale notifier (not persisted to disk: zero storage).
final ValueNotifier<Locale> appLocaleNotifier =
    ValueNotifier<Locale>(const Locale('en'));

const List<Locale> kSupportedLocales = <Locale>[
  Locale('en'),
  Locale('fa'),
];

const Map<String, String> kEnglishStrings = <String, String>{
  // --- Brand & shell ------------------------------------------------------
  'brandName': 'BIOVANTA · HEART',
  'appTitle': 'Heart Disease Risk Prediction',
  'launcherLabel': 'Heart Risk',
  'appVersion': 'V2.0.0',
  'languageToggle': 'فارسی',
  'themeTooltip': 'Switch Obsidian Dark / Clinical Paper',
  'languageTooltip': 'Switch English / فارسی',
  'navAssess': 'Assess',
  'navExplain': 'Explain',
  'navLabInfo': 'Lab & Info',

  // --- Permanent disclaimer ----------------------------------------------
  'disclaimer':
      'Educational project. NOT a medical diagnostic tool.\n'
          '100% offline on-device inference — zero internet permission or storage.',

  // --- Telemetry & mode ---------------------------------------------------
  'telemetryFmt': 'Offline · 2 Modes · {kb} KB · LogReg v2',
  'modeLabel': 'Inference Mode',
  'modeFull13': 'Full Clinical · 13',
  'modeNonInvasive11': 'Non-Invasive · 11',
  'modeBadgeFull': 'Full 13',
  'modeBadgeNi': 'Non-Invasive 11',
  'nonInvasiveOmitted':
      'Non-Invasive Screening mode excludes fluoroscopy (ca) and thallium scan (thal).',
  'autoRouteBanner':
      'Clinical safety auto-routing active: ca or thal is marked "Not tested / Unknown", '
          'so inference automatically switched to non_invasive_11 instead of assuming '
          'healthy defaults (ca=0, thal=3), which would shift log-odds by -2.0389.',
  'unknownOption': 'Not tested / Unknown',

  // --- Presets ------------------------------------------------------------
  'presetsHeading': 'Clinical Presets',
  'presetsHint': 'Tap any patient profile to populate inputs live',
  'presetLowTitle': 'Low-Risk Profile',
  'presetLowDesc': '42F · normal stress & ca=0, thal=3',
  'presetModerateTitle': 'Moderate-Risk Profile',
  'presetModerateDesc': '58M · mild HTN, LVH & slope=2',
  'presetHighFullTitle': 'High-Risk (Full 13)',
  'presetHighFullDesc': '63M · ischemia + ca=2, thal=7',
  'presetHighNiTitle': 'High-Risk (Non-Inv 11)',
  'presetHighNiDesc': '63M · symptomatic, ca/thal unknown',

  // --- Input groups & 13 features ----------------------------------------
  'groupDemographics': 'Demographics & Chest Pain',
  'groupVitalsLabs': 'Vitals & Laboratory',
  'groupStressTest': 'Exercise Stress Test',
  'groupSpecializedTests': 'Specialized / Invasive Tests',
  'age': 'Age',
  'sex': 'Sex',
  'sexFemale': 'Female',
  'sexMale': 'Male',
  'cp': 'Chest pain type',
  'cpTypical': 'Typical angina',
  'cpAtypical': 'Atypical angina',
  'cpNonAnginal': 'Non-anginal pain',
  'cpAsymptomatic': 'Asymptomatic',
  'trestbps': 'Resting blood pressure (mm Hg)',
  'chol': 'Cholesterol (mg/dl)',
  'fbs': 'Fasting blood sugar',
  'fbsNo': 'No (≤ 120 mg/dl)',
  'fbsYes': 'Yes (> 120 mg/dl)',
  'restecg': 'Resting ECG',
  'restecgNormal': 'Normal',
  'restecgStt': 'ST-T abnormality',
  'restecgLvh': 'LV hypertrophy',
  'thalach': 'Max heart rate achieved',
  'exang': 'Exercise-induced angina',
  'exangNo': 'No',
  'exangYes': 'Yes',
  'oldpeak': 'ST depression (oldpeak)',
  'slope': 'ST segment slope',
  'slopeUpsloping': 'Upsloping',
  'slopeFlat': 'Flat',
  'slopeDownsloping': 'Downsloping',
  'ca': 'Major vessels colored by fluoroscopy',
  'thal': 'Thallium test result',
  'thalNormal': 'Normal',
  'thalFixed': 'Fixed defect',
  'thalReversible': 'Reversible defect',
  'range': 'Range',
  'rangeHelper': 'Range: {min} - {max}',

  // --- Results & risk bands ----------------------------------------------
  'predict': 'Predict',
  'estimatedProbability': 'Estimated probability of heart disease',
  'activeModelLabel': 'Active Model',
  'bandLower': 'Lower risk band',
  'bandModerate': 'Moderate risk band',
  'bandHigher': 'Higher risk band',
  'bandNote':
      'Risk bands (<35% lower, 35-65% moderate, ≥65% higher) are illustrative '
          'cut-offs, not clinical thresholds. Not for medical decisions.',

  // --- Validation & loading ----------------------------------------------
  'errorNotANumber': '{field} must be a number.',
  'errorOutOfRange': '{field} must be between {min} and {max}.',
  'errorPleaseEnter': 'Please enter a value for {field}.',
  'errorModelLoading': 'Loading on-device model...',
  'errorModelLoad': 'Could not load the model: {error}',
  'fixValidationPrompt': 'Fix the highlighted input values to update live risk.',

  // --- Explain tab --------------------------------------------------------
  'explainTitle': 'Additive Log-Odds Explainability',
  'equationTitle': 'Exact Logistic Equation',
  'equationFormulaNote': 'intercept + Σ Δz = z → sigmoid(z) = probability',
  'contributionsTitle': 'Per-Feature Contributions (Δz)',
  'contributionsSubtitle': 'Sorted by |Δz| magnitude across active features',
  'dirRisk': 'Increases risk (+Δz)',
  'dirProtective': 'Lowers risk (-Δz)',
  'dirNeutral': 'Neutral (0)',
  'whatIfTitle': 'What-If Sensitivity Explorer',
  'whatIfSubtitle': 'Adjust key vitals or test availability vs current baseline',
  'whatIfBaseline': 'Baseline',
  'whatIfSimulated': 'What-If',
  'whatIfDelta': 'Delta',
  'whatIfInvasiveToggle': 'Mask ca & thal as Unknown (route to non_invasive_11)',
  'whatIfReset': 'Reset sliders',
  'caveatTitle': 'Understanding counter-intuitive weights (age, fbs, cp=4)',
  'caveatBody':
      '• Why age is -0.0609 in full_13: univariately in Cleveland, older age raises risk '
          '(r = +0.223), but age correlates with ca (r = +0.363) and lower thalach (r = -0.394). '
          'Conditioning on all 13 markers flips the residual partial slope slightly negative.\n'
          '• Why fbs > 120 (-0.1033) is near zero: only 45/303 patients had fbs=1 with similar '
          'prevalence (48.9% vs 45.3%, p = 0.746), reflecting sampling noise.\n'
          '• Why asymptomatic cp=4 raises risk (+1.0306): patients referred for angiography '
          'without typical angina had silent ischemia or abnormal stress tests (72.9% prevalence).',

  // --- Lab & Info tab -----------------------------------------------------
  'labTitle': 'BIOVANTA · HEART',
  'labTagline': 'Single-source-of-truth dual-mode clinical probability instrument',
  'themeLabel': 'Appearance',
  'themeDark': 'Obsidian Dark',
  'themeLight': 'Clinical Paper',
  'themeSystem': 'System',
  'languageSectionLabel': 'Language',
  'labArchTitle': 'Single Source of Truth (model.json v2)',
  'labArchBody':
      'This Android app evaluates identical arithmetic formulas and risk thresholds from '
          'mobile_export/model.json as the web runtime — zero ML runtime libraries, zero network calls.',
  'labInternalTitle': 'Internal Cleveland Validation (N=303)',
  'labFoldRangeNote': '10×5 Repeated Stratified CV (50 folds) — brackets show 95% fold range (2.5–97.5%).',
  'labMetricCol': 'Metric',
  'labRepCvCol': '10×5 CV',
  'labTest61Col': 'Test (61)',
  'labTrainCvFmt': '5-fold train CV ROC-AUC (N=242): {mean} ± {std} · C={c} · {dims} features',
  'labExternalTitle': 'Zero-Retraining UCI External Validation',
  'labExternalNote':
      'Switzerland (100%) and VA Long Beach (24.5% chol, 0.5% trestbps) encode missing vitals as 0. '
          'Cleaning chol/trestbps=0 → NaN improves pooled AUC, while steep hospital prevalence shifts '
          '(36.1% Hungarian vs 93.5% Switzerland vs 74.5% VA) degrade uncalibrated probabilities.',
  'labCohortCol': 'Cohort',
  'labNPrevCol': 'N (Prev)',
  'labRawAucEceCol': 'Raw AUC / ECE',
  'labCleanAucEceCol': 'Clean AUC / ECE',
  'labPredObsCol': 'Pred / Obs',
  'cohortHungarian': 'Hungarian',
  'cohortSwitzerland': 'Switzerland',
  'cohortVa': 'VA Long Beach',
  'cohortPooled': 'Pooled External',
  'labOfflineTitle': 'Verified Offline Privacy',
  'labOfflineBody':
      'Release APK declares zero INTERNET permission and zero persistent storage plugins. '
          'All numbers are computed ephemerally in RAM.',
  'labAttribution':
      'Dataset: UCI Machine Learning Repository — Heart Disease (Cleveland, Hungarian, Switzerland, VA Long Beach).',
};

const Map<String, String> kPersianStrings = <String, String>{
  // --- Brand & shell ------------------------------------------------------
  'brandName': 'BIOVANTA · HEART',
  'appTitle': 'ریسک بیماری قلبی',
  'launcherLabel': 'ریسک قلبی',
  'appVersion': 'V2.0.0',
  'languageToggle': 'English',
  'themeTooltip': 'تغییر تم تاریک / کاغذ بالینی',
  'languageTooltip': 'تغییر زبان فارسی / English',
  'navAssess': 'ارزیابی',
  'navExplain': 'تحلیل Δz',
  'navLabInfo': 'کارت مدل',

  // --- Permanent disclaimer ----------------------------------------------
  'disclaimer':
      'این برنامه یک پروژه‌ی آموزشی است و ابزار تشخیص پزشکی نیست؛ جایگزین مراجعه به پزشک نیست.\n'
          'اجرای ۱۰۰٪ آفلاین روی گوشی بدون دسترسی اینترنت و بدون ذخیره‌سازی.',

  // --- Telemetry & mode ---------------------------------------------------
  'telemetryFmt': 'آفلاین · 2 حالت · {kb} KB · LogReg v2',
  'modeLabel': 'حالت محاسبه',
  'modeFull13': 'بالینی کامل · 13',
  'modeNonInvasive11': 'غیرتهاجمی · 11',
  'modeBadgeFull': 'کامل 13',
  'modeBadgeNi': 'غیرتهاجمی 11',
  'nonInvasiveOmitted':
      'در حالت غربالگری غیرتهاجمی، آزمایش‌های فلوروسکوپی (ca) و اسکن تالیوم (thal) لحاظ نمی‌شوند.',
  'autoRouteBanner':
      'مسیریابی ایمن خودکار فعال شد: به دلیل نامشخص بودن ca یا thal، محاسبه با مدل ۱۱ ویژگی '
          'non_invasive_11 انجام شد و مقادیر نامشخص هرگز با مقادیر سالم (ca=0, thal=3) پر نمی‌شوند (-2.0389 log-odds).',
  'unknownOption': 'آزمایش نشده / نامشخص',

  // --- Presets ------------------------------------------------------------
  'presetsHeading': 'نمونه‌های بالینی آماده',
  'presetsHint': 'برای پر کردن سریع مقادیر، یکی از پروفایل‌ها را لمس کنید',
  'presetLowTitle': 'پروفایل کم‌ریسک',
  'presetLowDesc': 'زن 42 ساله · آزمایش‌های طبیعی',
  'presetModerateTitle': 'پروفایل ریسک متوسط',
  'presetModerateDesc': 'مرد 58 ساله · فشار خفیف و LVH',
  'presetHighFullTitle': 'پرریسک (کامل 13)',
  'presetHighFullDesc': 'مرد 63 ساله · ایسکمی + ca=2, thal=7',
  'presetHighNiTitle': 'پرریسک (غیرتهاجمی 11)',
  'presetHighNiDesc': 'مرد 63 ساله · علامت‌دار، ca/thal نامشخص',

  // --- Input groups & 13 features ----------------------------------------
  'groupDemographics': 'اطلاعات پایه و درد قفسه سینه',
  'groupVitalsLabs': 'علائم حیاتی و آزمایش خون',
  'groupStressTest': 'آزمون ورزش و نوار قلب',
  'groupSpecializedTests': 'آزمایش‌های تخصصی / تهاجمی',
  'age': 'سن',
  'sex': 'جنسیت',
  'sexFemale': 'زن',
  'sexMale': 'مرد',
  'cp': 'نوع درد قفسه سینه',
  'cpTypical': 'آنژین تیپیک',
  'cpAtypical': 'آنژین آتیپیک',
  'cpNonAnginal': 'درد غیرآنژینی',
  'cpAsymptomatic': 'بدون علامت',
  'trestbps': 'فشار خون در حالت استراحت (mm Hg)',
  'chol': 'کلسترول (mg/dl)',
  'fbs': 'قند خون ناشتا',
  'fbsNo': 'خیر (≤ 120 mg/dl)',
  'fbsYes': 'بله (> 120 mg/dl)',
  'restecg': 'نوار قلب در حالت استراحت',
  'restecgNormal': 'طبیعی',
  'restecgStt': 'ناهنجاری ST-T',
  'restecgLvh': 'هیپرتروفی بطن چپ',
  'thalach': 'حداکثر ضربان قلب',
  'exang': 'آنژین ناشی از ورزش',
  'exangNo': 'خیر',
  'exangYes': 'بله',
  'oldpeak': 'افت قطعه ST (oldpeak)',
  'slope': 'شیب قطعه ST',
  'slopeUpsloping': 'صعودی',
  'slopeFlat': 'تخت',
  'slopeDownsloping': 'نزولی',
  'ca': 'تعداد رگ‌های اصلی رنگ‌شده در فلوروسکوپی',
  'thal': 'نتیجه‌ی اسکن تالیوم',
  'thalNormal': 'طبیعی',
  'thalFixed': 'نقص ثابت',
  'thalReversible': 'نقص برگشت‌پذیر',
  'range': 'بازه',
  'rangeHelper': 'بازه: {min} - {max}',

  // --- Results & risk bands ----------------------------------------------
  'predict': 'پیش‌بینی',
  'estimatedProbability': 'احتمال تخمینی بیماری قلبی',
  'activeModelLabel': 'مدل فعال',
  'bandLower': 'ریسک کمتر',
  'bandModerate': 'ریسک متوسط',
  'bandHigher': 'ریسک بالاتر',
  'bandNote':
      'این بازه‌های ریسک فقط برای نمایش هستند و آستانه‌ی بالینی نیستند. '
          'این یک پروژه‌ی آموزشی است و نباید مبنای تصمیم پزشکی قرار گیرد.',

  // --- Validation & loading ----------------------------------------------
  'errorNotANumber': 'مقدار {field} باید یک عدد باشد.',
  'errorOutOfRange': 'مقدار {field} باید بین {min} و {max} باشد.',
  'errorPleaseEnter': 'لطفاً مقدار {field} را وارد کنید.',
  'errorModelLoading': 'مدل در حال بارگذاری است، لطفاً کمی صبر کنید...',
  'errorModelLoad': 'بارگذاری مدل ممکن نشد: {error}',
  'fixValidationPrompt': 'برای به‌روزرسانی ریسک، مقادیر خطادار را اصلاح کنید.',

  // --- Explain tab --------------------------------------------------------
  'explainTitle': 'توضیح‌پذیری دقیق لگاریتم شانس',
  'equationTitle': 'معادله‌ی دقیق لجستیک',
  'equationFormulaNote': 'intercept + Σ Δz = z → sigmoid(z) = احتمال',
  'contributionsTitle': 'سهم هر ویژگی (Δz)',
  'contributionsSubtitle': 'مرتب‌شده بر اساس بزرگی |Δz| در مدل فعال',
  'dirRisk': 'افزایش‌دهنده (+Δz)',
  'dirProtective': 'کاهش‌دهنده (-Δz)',
  'dirNeutral': 'خنثی (0)',
  'whatIfTitle': 'کاوشگر حساسیت «چه می‌شود اگر»',
  'whatIfSubtitle': 'تغییر شاخص‌های حیاتی یا وضعیت آزمایش‌ها نسبت به مقدار فعلی',
  'whatIfBaseline': 'پایه فعلی',
  'whatIfSimulated': 'شبیه‌سازی',
  'whatIfDelta': 'تغییر',
  'whatIfInvasiveToggle': 'نامشخص کردن ca و thal (مسیر non_invasive_11)',
  'whatIfReset': 'بازنشانی اسلایدرها',
  'caveatTitle': 'توضیح ضرایب هم‌خطی و سوگیری ارجاع (age، fbs، cp=4)',
  'caveatBody':
      '• چرا ضریب age در full_13 کمی منفی (-0.0609) است؟ به‌صورت تک‌متغیره سن ریسک را بالا می‌برد '
          '(r = +0.223)، اما سن با ca (r = +0.363) و کاهش thalach (r = -0.394) همبستگی دارد و با کنترل هم‌زمان همه، '
          'شیب باقیمانده اندکی منفی می‌شود.\n'
          '• چرا fbs > 120 (-0.1033) نزدیک صفر است؟ تنها 45/303 بیمار قند ناشتای بالا داشته‌اند و شیوع دو گروه مشابه است '
          '(48.9% در برابر 45.3%, p = 0.746).\n'
          '• چرا درد بدون علامت (cp=4) ریسک را بالا می‌برد (+1.0306)؟ بیماران بدون درد تیپیک در بخش آنژیوگرافی '
          'به دلیل ایسکمی خاموش یا تست ورزش غیرطبیعی ارجاع شده‌اند (شیوع 72.9%).',

  // --- Lab & Info tab -----------------------------------------------------
  'labTitle': 'BIOVANTA · HEART',
  'labTagline': 'ابزار ارزیابی احتمال بیماری قلبی دوحالته با منبع واحد',
  'themeLabel': 'ظاهر برنامه',
  'themeDark': 'تاریک ابسیدین',
  'themeLight': 'کاغذ بالینی',
  'themeSystem': 'همگام با سیستم',
  'languageSectionLabel': 'زبان',
  'labArchTitle': 'معماری منبع واحد (model.json v2)',
  'labArchBody':
      'نسخه‌ی اندروید دقیقاً فرمول‌های خطی و آستانه‌های فایل mobile_export/model.json را مشابه وب اجرا می‌کند؛ '
          'بدون کتابخانه‌ی ML و بدون هیچ دسترسی به اینترنت.',
  'labInternalTitle': 'اعتبارسنجی داخلی کلیولند (N=303)',
  'labFoldRangeNote': 'اعتبارسنجی تکراری 10×5 (50 فولد) — بازه‌ها نشان‌دهنده‌ی صدک 2.5–97.5 فولدها هستند.',
  'labMetricCol': 'معیار',
  'labRepCvCol': 'CV 10×5',
  'labTest61Col': 'آزمون (61)',
  'labTrainCvFmt': 'CV 5تایی آموزش (N=242): {mean} ± {std} · C={c} · {dims} ویژگی',
  'labExternalTitle': 'اعتبارسنجی خارجی UCI بدون بازآموزی',
  'labExternalNote':
      'در داده‌های سوئیس (100%) و لانگ‌بیچ (24.5% کلسترول و 0.5% فشار خون) مقادیر نامشخص با 0 ثبت شده‌اند. '
          'تبدیل 0 به NaN تفکیک کل را بهتر می‌کند، اما تفاوت شدید شیوع بیمارستان‌ها کالیبراسیون را کاهش می‌دهد.',
  'labCohortCol': 'گروه',
  'labNPrevCol': 'تعداد (شیوع)',
  'labRawAucEceCol': 'AUC/ECE خام',
  'labCleanAucEceCol': 'AUC/ECE تمیز',
  'labPredObsCol': 'پیش‌بینی / واقعی',
  'cohortHungarian': 'مجارستان',
  'cohortSwitzerland': 'سوئیس',
  'cohortVa': 'لانگ‌بیچ VA',
  'cohortPooled': 'تجمیع خارجی',
  'labOfflineTitle': 'حریم خصوصی و آفلاین بودن',
  'labOfflineBody':
      'فایل نصبی فاقد مجوز INTERNET و فاقد افزونه‌ی ذخیره‌سازی است؛ همه‌ی اعداد فقط در حافظه‌ی موقت محاسبه می‌شوند.',
  'labAttribution':
      'منبع داده: UCI Machine Learning Repository — Heart Disease (Cleveland, Hungarian, Switzerland, VA Long Beach).',
};

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isFa => locale.languageCode == 'fa';

  Map<String, String> get _map => mapFor(locale);

  static Map<String, String> mapFor(Locale locale) =>
      locale.languageCode == 'fa' ? kPersianStrings : kEnglishStrings;

  static AppStrings of(BuildContext context) {
    final loc = Localizations.maybeLocaleOf(context) ?? appLocaleNotifier.value;
    return AppStrings(loc);
  }

  static String fill(String template, Map<String, Object> values) {
    var out = template;
    values.forEach((key, value) {
      out = out.replaceAll('{$key}', '$value');
    });
    return out;
  }

  String s(String key) => _map[key] ?? kEnglishStrings[key] ?? key;

  String sf(String key, Map<String, Object> values) => fill(s(key), values);

  String featureLabel(String code) => s(code);
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kSupportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
