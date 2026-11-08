// main.dart
//
// The whole user interface of the offline heart-risk app.
//
// Structure:
//   * `main()`          -> starts the app
//   * `HeartRiskApp`    -> MaterialApp: theme, locales, custom font, strings
//   * `HomePage`        -> holds the form state and does the prediction
//   * `_numberField()`  -> a numeric input with a range check
//   * `_dropdown()`     -> a labelled dropdown carrying a numeric code
//
// Languages
//   English (en) is the default. On a device whose language is Persian the app
//   starts in Persian. The AppBar button switches language at runtime; the
//   choice is intentionally NOT saved anywhere (this app stores no data).
//
// There is NO network access anywhere in this app: the model is a JSON file
// bundled in the APK and the maths happens on the phone.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'heart_model.dart';
import 'input_parsing.dart';
import 'strings.dart';

void main() {
  runApp(const HeartRiskApp());
}

class HeartRiskApp extends StatefulWidget {
  const HeartRiskApp({super.key});

  @override
  State<HeartRiskApp> createState() => _HeartRiskAppState();
}

class _HeartRiskAppState extends State<HeartRiskApp> {
  /// The language the user picked with the toggle.
  ///
  /// `null` means "follow the device": MaterialApp then resolves the locale
  /// from the system settings, and because `localeResolutionCallback` maps
  /// every non-Persian language to English, that gives us
  /// "Persian device -> Persian, anything else -> English".
  Locale? _override;

  bool get _isPersian {
    final locale = _override ??
        WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode == 'fa';
  }

  void _toggleLanguage() {
    setState(() {
      _override = _isPersian ? const Locale('en') : const Locale('fa');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The title shown by the OS in the task switcher.
      onGenerateTitle: (context) => context.s('launcherLabel'),
      debugShowCheckedModeBanner: false,

      // --- localization ---------------------------------------------------
      locale: _override,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        // Our own strings.
        AppStringsDelegate(),
        // Flutter's built-in Material/Cupertino/Widgets strings (so e.g. the
        // dropdown and text-selection menus appear in Persian too).
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Any language we do not ship falls back to English, which keeps English
      // the default. This also decides the text direction: `fa` is RTL, so
      // Flutter flips the whole layout automatically.
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        return supported.any((l) => l.languageCode == locale.languageCode)
            ? Locale(locale.languageCode)
            : const Locale('en');
      },

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),

      // Apply the bundled Vazirmatn font ONLY in Persian. English keeps the
      // platform default (Roboto), so the English build looks exactly as it
      // did before this change.
      builder: (context, child) {
        final persian = Localizations.localeOf(context).languageCode == 'fa';
        if (!persian) return child!;
        return DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Vazirmatn'),
          child: child!,
        );
      },

      home: HomePage(onToggleLanguage: _toggleLanguage),
    );
  }
}

// ---------------------------------------------------------------------------
// The option lists below are copied EXACTLY from app.py.
//
// Each entry pairs a *string key* (translated at runtime) with the numeric code
// the model was trained with. The CODES are the contract with the model and
// must never change; only the `key` is looked up in the active language.
// ---------------------------------------------------------------------------
const List<({String key, double code})> kSex = [
  (key: 'sexFemale', code: 0),
  (key: 'sexMale', code: 1),
];

const List<({String key, double code})> kCp = [
  (key: 'cpTypical', code: 1),
  (key: 'cpAtypical', code: 2),
  (key: 'cpNonAnginal', code: 3),
  (key: 'cpAsymptomatic', code: 4),
];

const List<({String key, double code})> kFbs = [
  (key: 'fbsNo', code: 0),
  (key: 'fbsYes', code: 1),
];

const List<({String key, double code})> kRestecg = [
  (key: 'restecgNormal', code: 0),
  (key: 'restecgStt', code: 1),
  (key: 'restecgLvh', code: 2),
];

const List<({String key, double code})> kExang = [
  (key: 'exangNo', code: 0),
  (key: 'exangYes', code: 1),
];

const List<({String key, double code})> kSlope = [
  (key: 'slopeUpsloping', code: 1),
  (key: 'slopeFlat', code: 2),
  (key: 'slopeDownsloping', code: 3),
];

const List<({String key, double code})> kThal = [
  (key: 'thalNormal', code: 3),
  (key: 'thalFixed', code: 6),
  (key: 'thalReversible', code: 7),
];

/// Number of coloured vessels (ca). app.py offers 0..3.
/// These are plain numbers, so no translation is involved.
const List<double> kCa = [0, 1, 2, 3];

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onToggleLanguage, this.model});

  /// Switches the app language. Null in tests that build HomePage directly.
  final VoidCallback? onToggleLanguage;

  /// The model to predict with.
  ///
  /// In the real app this is null and the page loads `assets/model.json`
  /// itself. Tests pass a model built from the same file so they do not depend
  /// on asynchronous asset I/O finishing inside `pumpAndSettle`.
  final HeartModel? model;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The loaded model. Null until the asset has been read.
  HeartModel? _model;

  // Controllers for the five numeric inputs (defaults match app.py).
  // Defaults are plain Latin digits so both languages start from the same
  // state; typing Persian digits is handled by parseLocalizedNumber.
  final _age = TextEditingController(text: '55');
  final _trestbps = TextEditingController(text: '130');
  final _chol = TextEditingController(text: '240');
  final _thalach = TextEditingController(text: '150');
  final _oldpeak = TextEditingController(text: '1.0');

  // Currently selected codes for the categorical inputs. These are the model's
  // codes, not translated text.
  double _sex = 0;
  double _cp = 1;
  double _fbs = 0;
  double _restecg = 0;
  double _exang = 0;
  double _slope = 1;
  double _ca = 0;
  double _thal = 3;

  double? _probability; // the last prediction, or null
  // The validation message is stored as a KEY plus its placeholder values, so
  // it re-renders in the right language if the user switches language.
  String? _errorKey;
  Map<String, Object> _errorValues = const {};

  /// True once assets/model.json has been parsed successfully.
  bool get _modelReady => _model != null;

  @override
  void initState() {
    super.initState();
    // A model handed in by a test is used directly; otherwise load the asset.
    if (widget.model != null) {
      _model = widget.model;
    } else {
      _loadModel();
    }
  }

  /// Read assets/model.json from the APK (no network involved).
  Future<void> _loadModel() async {
    try {
      final source = await rootBundle.loadString('assets/model.json');
      setState(() => _model = HeartModel.fromJsonString(source));
    } catch (e) {
      setState(() {
        _errorKey = 'errorModelLoad';
        _errorValues = {'error': '$e'};
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_age, _trestbps, _chol, _thalach, _oldpeak]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Read a numeric field and check it is inside [min, max].
  ///
  /// Uses [parseLocalizedNumber] so Latin, Persian and Arabic digits are all
  /// accepted (and '٫' / ',' as decimal separators).
  double? _readNumber(
      TextEditingController c, double min, double max, String fieldKey) {
    final raw = c.text;
    if (raw.trim().isEmpty) {
      _errorKey = 'errorPleaseEnter';
      _errorValues = {'field': fieldKey};
      return null;
    }
    final value = parseLocalizedNumber(raw);
    if (value == null) {
      _errorKey = 'errorNotANumber';
      _errorValues = {'field': fieldKey};
      return null;
    }
    if (value < min || value > max) {
      _errorKey = 'errorOutOfRange';
      _errorValues = {
        'field': fieldKey,
        // Latin digits in both languages, so values and units stay consistent.
        'min': min.toStringAsFixed(0),
        'max': max.toStringAsFixed(0),
      };
      return null;
    }
    return value;
  }

  /// Validate every field, then run the formula locally.
  void _predict() {
    _errorKey = null;
    _errorValues = const {};

    if (_model == null) {
      setState(() {
        _errorKey = 'errorModelLoading';
        _errorValues = const {};
      });
      return;
    }

    // Ranges are exactly the ones used in app.py.
    final age = _readNumber(_age, 20, 100, 'age');
    final trestbps = _readNumber(_trestbps, 80, 220, 'trestbps');
    final chol = _readNumber(_chol, 100, 600, 'chol');
    final thalach = _readNumber(_thalach, 60, 220, 'thalach');
    final oldpeak = _readNumber(_oldpeak, 0, 7, 'oldpeak');

    if (_errorKey != null) {
      setState(() => _probability = null);
      return;
    }

    // Build the raw input row, using the same codes as app.py.
    final input = <String, double?>{
      'age': age,
      'sex': _sex,
      'cp': _cp,
      'trestbps': trestbps,
      'chol': chol,
      'fbs': _fbs,
      'restecg': _restecg,
      'thalach': thalach,
      'exang': _exang,
      'oldpeak': oldpeak,
      'slope': _slope,
      'ca': _ca,
      'thal': _thal,
    };

    setState(() {
      _probability = _model!.predictProbability(input);
    });
  }

  /// Risk band, identical to the thresholds used in app.py.
  /// Returns the string KEY plus the colour.
  (String, Color) _band(double p) {
    if (p < 0.35) return ('bandLower', Colors.green);
    if (p < 0.65) return ('bandModerate', Colors.orange);
    return ('bandHigher', Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('appTitle')),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // The toggle label names the language you would switch TO.
          TextButton(
            onPressed: widget.onToggleLanguage,
            child: Text(
              context.s('languageToggle'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      // If the model asset failed to load there is nothing to fill in, so show
      // just the error message (translated, like everything else).
      body: !_modelReady
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorKey != null
                    ? context.sf(_errorKey!, _errorValues)
                    : context.s('errorModelLoading')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- the permanent, always-visible disclaimer -------------
                _disclaimerCard(),
                const SizedBox(height: 12),

                // --- the 13 inputs ---------------------------------------
                _numberField(_age, 'age', 20, 100, isInteger: true),
                _dropdown('sex', kSex, _sex, (v) => setState(() => _sex = v)),
                _dropdown('cp', kCp, _cp, (v) => setState(() => _cp = v)),
                _numberField(_trestbps, 'trestbps', 80, 220, isInteger: true),
                _numberField(_chol, 'chol', 100, 600, isInteger: true),
                _dropdown('fbs', kFbs, _fbs, (v) => setState(() => _fbs = v)),
                _dropdown('restecg', kRestecg, _restecg,
                    (v) => setState(() => _restecg = v)),
                _numberField(_thalach, 'thalach', 60, 220, isInteger: true),
                _dropdown('exang', kExang, _exang,
                    (v) => setState(() => _exang = v)),
                _numberField(_oldpeak, 'oldpeak', 0, 7),
                _dropdown('slope', kSlope, _slope,
                    (v) => setState(() => _slope = v)),
                _caDropdown(),
                _dropdown('thal', kThal, _thal,
                    (v) => setState(() => _thal = v)),

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _predict,
                  icon: const Icon(Icons.favorite),
                  label: Text(context.s('predict')),
                ),

                // --- validation message ----------------------------------
                if (_errorKey != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.sf(_errorKey!, _errorValues),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                // --- the result ------------------------------------------
                if (_probability != null) ...[
                  const SizedBox(height: 20),
                  _resultCard(_probability!),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  /// The always-visible educational notice.
  ///
  /// Uses a Row of [Icon] + [Expanded] text so the long Persian wording wraps
  /// instead of overflowing, and the icon simply follows the text direction.
  Widget _disclaimerCard() {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        // EdgeInsetsDirectional keeps the padding on the "start" side in both
        // LTR and RTL, with no hard-coded left/right.
        padding: const EdgeInsetsDirectional.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.s('disclaimer'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the result card: percentage, progress bar and risk band.
  Widget _resultCard(double p) {
    final (labelKey, color) = _band(p);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          // start = right in Persian, left in English.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.s('estimatedProbability'),
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              // Numbers always use Latin digits in both languages.
              '${(p * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            // LinearProgressIndicator takes its direction from the ambient
            // Directionality, which GlobalWidgetsLocalizations sets to RTL in
            // Persian -- so the bar fills from the right automatically, with
            // nothing hard-coded here. Its value is always 0.0..1.0.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.circle, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(context.s(labelKey),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Kept visible on purpose: bands are arbitrary cut-offs.
            Text(
              context.s('bandNote'),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// A labelled numeric input with a built-in range check.
  Widget _numberField(
    TextEditingController controller,
    String labelKey,
    double min,
    double max, {
    bool isInteger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        // A stable key so widget tests can address the field by name instead of
        // by its (translated) label.
        key: ValueKey('field_$labelKey'),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
        // NOTE: a formatter that allowed only `[0-9]` would silently drop
        // Persian (۰-۹) and Arabic-Indic (٠-٩) digits. isPlausibleNumberInput
        // accepts all three scripts plus one '.' or ',' / '٫'.
        inputFormatters: [FilteringTextInputFormatter.allow(kDigitsAnyScript)],
        decoration: InputDecoration(
          labelText: context.s(labelKey),
          helperText: context.sf('rangeHelper', {
            'min': min.toStringAsFixed(0),
            'max': max.toStringAsFixed(0),
          }),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// A labelled dropdown whose entries carry a numeric code.
  ///
  /// `options[].key` is translated for display; `options[].code` is passed to
  /// the model untouched.
  Widget _dropdown(
    String labelKey,
    List<({String key, double code})> options,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final codes = options.map((o) => o.code).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<double>(
        // Stable key for the widget tests (see _numberField).
        key: ValueKey('field_$labelKey'),
        initialValue: codes.contains(value) ? value : codes.first,
        // isExpanded lets the long Persian labels use the full width instead of
        // overflowing their box.
        isExpanded: true,
        decoration: InputDecoration(
            labelText: context.s(labelKey),
            border: const OutlineInputBorder()),
        items: options
            .map((o) => DropdownMenuItem<double>(
                value: o.code, child: Text(context.s(o.key))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  /// The `ca` dropdown. Its options are plain numbers (0..3), so there is
  /// nothing to translate -- only the field label changes with the language.
  Widget _caDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<double>(
        key: const ValueKey('field_ca'),
        initialValue: kCa.contains(_ca) ? _ca : kCa.first,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: context.s('ca'), border: const OutlineInputBorder()),
        items: kCa
            .map((v) => DropdownMenuItem<double>(
                value: v, child: Text(v.toStringAsFixed(0))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _ca = v);
        },
      ),
    );
  }
}
