// strings.dart
//
// All of the app's own text lives here, in one place, in two languages.
//
// Why a plain map instead of ARB files + code generation?
//   * The app has ~40 short strings and exactly two languages.
//   * A hand-written map is easier for a beginner to read and change, and it
//     keeps the build simple (no `flutter gen-l10n` step).
//
// IMPORTANT
//   Only *labels* are translated. The numeric codes the model was trained with
//   (cp = 1..4, thal = 3/6/7, ...) are NOT text and never change; see the
//   `kSex`, `kCp`, ... maps in main.dart. Keeping the codes fixed while
//   swapping only the visible words is what makes translation safe: the model
//   always receives exactly the same numbers it saw during training.

import 'package:flutter/widgets.dart';

/// The languages the app ships with.
const List<Locale> kSupportedLocales = [Locale('en'), Locale('fa')];

/// The English strings. This map is the "source of truth": every other
/// language must define exactly the same keys (a test enforces this).
const Map<String, String> kEnglishStrings = {
  // --- general ------------------------------------------------------------
  'appTitle': 'Heart Disease Risk Prediction',
  'launcherLabel': 'Heart Risk',
  'languageToggle': 'فارسی', // shown while English is active: switch to Persian

  // --- disclaimer (always visible) ---------------------------------------
  'disclaimer':
      'Educational project. NOT a medical diagnostic tool.\n'
          'This app runs entirely on your phone, with no internet connection.',

  // --- the 13 inputs -----------------------------------------------------
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

  // --- ranges helper text -------------------------------------------------
  'range': 'Range',
  'rangeHelper': 'Range: {min} - {max}',

  // --- actions and results ------------------------------------------------
  'predict': 'Predict',
  'estimatedProbability': 'Estimated probability of heart disease',
  'bandLower': 'Lower risk band',
  'bandModerate': 'Moderate risk band',
  'bandHigher': 'Higher risk band',
  'bandNote':
      'Risk bands (<35% lower, 35-65% moderate, >65% higher) are illustrative '
          'cut-offs, not clinical thresholds. This is an educational project and '
          'must not be used for medical decisions.',

  // --- validation ---------------------------------------------------------
  'errorNotANumber': '{field} must be a number.',
  'errorOutOfRange': '{field} must be between {min} and {max}.',
  'errorPleaseEnter': 'Please enter a value for {field}.',
  'errorModelLoading': 'The model is still loading, please wait.',
  'errorModelLoad': 'Could not load the model: {error}',
};

/// The Persian strings. The keys are identical to [kEnglishStrings].
///
/// Numbers stay in Latin digits everywhere, including in the `{min}`/`{max}`
/// placeholders, so values and units look the same in both languages.
const Map<String, String> kPersianStrings = {
  // --- general ------------------------------------------------------------
  'appTitle': 'ریسک بیماری قلبی',
  'launcherLabel': 'ریسک قلبی',
  'languageToggle': 'English', // shown while Persian is active

  // --- disclaimer (always visible) ---------------------------------------
  'disclaimer':
      'این برنامه یک پروژه‌ی آموزشی است و ابزار تشخیص پزشکی نیست. جایگزین '
          'مراجعه به پزشک نیست.\n'
          'این برنامه کاملاً روی گوشی شما و بدون اتصال به اینترنت اجرا می‌شود.',

  // --- the 13 inputs -----------------------------------------------------
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

  // --- ranges helper text -------------------------------------------------
  'range': 'بازه',
  'rangeHelper': 'بازه: {min} - {max}',

  // --- actions and results ------------------------------------------------
  'predict': 'پیش‌بینی',
  'estimatedProbability': 'احتمال تخمینی بیماری قلبی',
  'bandLower': 'ریسک کمتر',
  'bandModerate': 'ریسک متوسط',
  'bandHigher': 'ریسک بالاتر',
  'bandNote':
      'این بازه‌های ریسک فقط برای نمایش هستند و آستانه‌ی بالینی نیستند. '
          'این یک پروژه‌ی آموزشی است و نباید مبنای تصمیم پزشکی قرار گیرد.',

  // --- validation ---------------------------------------------------------
  'errorNotANumber': 'مقدار {field} باید یک عدد باشد.',
  'errorOutOfRange': 'مقدار {field} باید بین {min} و {max} باشد.',
  'errorPleaseEnter': 'لطفاً مقدار {field} را وارد کنید.',
  'errorModelLoading': 'مدل هنوز در حال بارگذاری است، لطفاً کمی صبر کنید.',
  'errorModelLoad': 'بارگذاری مدل ممکن نشد: {error}',
};

/// Looks up the app's own strings for the active [locale].
///
/// Usage:  `final s = AppStrings.of(context);  Text(s['age']!)`
///
/// Any locale that is not Persian falls back to English, which is what makes
/// English the default on a device whose language we do not ship.
class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  /// The strings for one language code ("en" or "fa").
  static Map<String, String> mapFor(Locale locale) =>
      locale.languageCode == 'fa' ? kPersianStrings : kEnglishStrings;

  /// The strings for the current [BuildContext], read from [Localizations].
  static Map<String, String> of(BuildContext context) =>
      mapFor(Localizations.localeOf(context));

  /// Fills `{placeholders}` such as `{min}`, `{max}`, `{field}` and `{error}`.
  ///
  /// Keeping this tiny hand-rolled formatter avoids pulling in a formatting
  /// package and keeps the text readable for beginners.
  static String fill(String template, Map<String, Object> values) {
    var out = template;
    values.forEach((key, value) {
      out = out.replaceAll('{$key}', '$value');
    });
    return out;
  }
}

/// Convenience extension so call sites read nicely:
/// `context.s('age')` instead of `AppStrings.of(context)['age']!`.
extension AppStringsX on BuildContext {
  String s(String key) => AppStrings.of(this)[key] ?? key;

  /// Like [s], but substitutes `{placeholders}` in one step.
  String sf(String key, Map<String, Object> values) =>
      AppStrings.fill(s(key), values);
}

/// Handy for building a localized [LocalizationsDelegate] without codegen.
///
/// Flutter needs *some* delegate to publish our strings; this one simply
/// exposes the two maps above.
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
