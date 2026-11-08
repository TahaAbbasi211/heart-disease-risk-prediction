// main.dart
//
// The whole user interface of the offline heart-risk app.
//
// Structure:
//   * `main()`          -> starts the app
//   * `HomePage`        -> holds the form state and does the prediction
//   * `_numberField()`  -> small helper that builds a numeric input with a range
//   * `_dropdown()`     -> small helper that builds a labelled dropdown
//
// There is NO network access anywhere in this app: the model is a JSON file
// bundled in the APK and the maths happens on the phone.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, rootBundle;

import 'heart_model.dart';

void main() {
  runApp(const HeartRiskApp());
}

class HeartRiskApp extends StatelessWidget {
  const HeartRiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Disease Risk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// The option lists below are copied EXACTLY from app.py:
// each display label maps to the numeric code the model was trained with.
// ---------------------------------------------------------------------------
const Map<String, double> kSex = {'Female': 0, 'Male': 1};

const Map<String, double> kCp = {
  'Typical angina': 1,
  'Atypical angina': 2,
  'Non-anginal pain': 3,
  'Asymptomatic': 4,
};

const Map<String, double> kFbs = {
  'No (≤ 120 mg/dl)': 0,
  'Yes (> 120 mg/dl)': 1,
};

const Map<String, double> kRestecg = {
  'Normal': 0,
  'ST-T abnormality': 1,
  'LV hypertrophy': 2,
};

const Map<String, double> kExang = {'No': 0, 'Yes': 1};

const Map<String, double> kSlope = {
  'Upsloping': 1,
  'Flat': 2,
  'Downsloping': 3,
};

const Map<String, double> kThal = {
  'Normal': 3,
  'Fixed defect': 6,
  'Reversible defect': 7,
};

/// Number of coloured vessels (ca). app.py offers 0..3.
const List<double> kCa = [0, 1, 2, 3];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The loaded model. Null until the asset has been read.
  HeartModel? _model;
  String? _loadError;

  // Controllers for the five numeric inputs (defaults match app.py).
  final _age = TextEditingController(text: '55');
  final _trestbps = TextEditingController(text: '130');
  final _chol = TextEditingController(text: '240');
  final _thalach = TextEditingController(text: '150');
  final _oldpeak = TextEditingController(text: '1.0');

  // Currently selected codes for the categorical inputs.
  double _sex = 0; // app.py: first entry of SEX ("Female")
  double _cp = 1; // first entry of CP ("Typical angina")
  double _fbs = 0;
  double _restecg = 0;
  double _exang = 0;
  double _slope = 1; // first entry of SLOPE ("Upsloping")
  double _ca = 0;
  double _thal = 3; // first entry of THAL ("Normal")

  double? _probability; // the last prediction, or null
  String? _error; // validation message, or null

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  /// Read assets/model.json from the APK (no network involved).
  Future<void> _loadModel() async {
    try {
      final source = await rootBundle.loadString('assets/model.json');
      setState(() => _model = HeartModel.fromJsonString(source));
    } catch (e) {
      setState(() => _loadError = 'Could not load the model: $e');
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
  double? _readNumber(
      TextEditingController c, double min, double max, String label) {
    final value = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (value == null) {
      _error = '$label must be a number.';
      return null;
    }
    if (value < min || value > max) {
      _error = '$label must be between '
          '${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
      return null;
    }
    return value;
  }

  /// Validate every field, then run the formula locally.
  void _predict() {
    _error = null;

    if (_model == null) {
      setState(() =>
          _error = _loadError ?? 'The model is still loading, please wait.');
      return;
    }

    // Ranges are exactly the ones used in app.py.
    final age = _readNumber(_age, 20, 100, 'Age');
    final trestbps = _readNumber(_trestbps, 80, 220, 'Resting blood pressure');
    final chol = _readNumber(_chol, 100, 600, 'Cholesterol');
    final thalach = _readNumber(_thalach, 60, 220, 'Max heart rate achieved');
    final oldpeak = _readNumber(_oldpeak, 0, 7, 'ST depression (oldpeak)');

    if (_error != null) {
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

  /// Risk band wording, identical to the thresholds used in app.py.
  (String, Color) _band(double p) {
    if (p < 0.35) return ('Lower risk band', Colors.green);
    if (p < 0.65) return ('Moderate risk band', Colors.orange);
    return ('Higher risk band', Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Disease Risk Prediction'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(_loadError!)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- the permanent, always-visible disclaimer -------------
                Card(
                  color: Colors.amber.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Educational project. NOT a medical diagnostic tool.\n'
                            'This app runs entirely on your phone, with no internet connection.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- the 13 inputs ---------------------------------------
                _numberField(_age, 'Age', 20, 100, isInteger: true),
                _dropdown('Sex', kSex, _sex, (v) => setState(() => _sex = v)),
                _dropdown('Chest pain type', kCp, _cp,
                    (v) => setState(() => _cp = v)),
                _numberField(_trestbps, 'Resting blood pressure (mm Hg)', 80, 220,
                    isInteger: true),
                _numberField(_chol, 'Cholesterol (mg/dl)', 100, 600,
                    isInteger: true),
                _dropdown('Fasting blood sugar', kFbs, _fbs,
                    (v) => setState(() => _fbs = v)),
                _dropdown('Resting ECG', kRestecg, _restecg,
                    (v) => setState(() => _restecg = v)),
                _numberField(_thalach, 'Max heart rate achieved', 60, 220,
                    isInteger: true),
                _dropdown('Exercise-induced angina', kExang, _exang,
                    (v) => setState(() => _exang = v)),
                _numberField(_oldpeak, 'ST depression (oldpeak)', 0, 7),
                _dropdown('ST segment slope', kSlope, _slope,
                    (v) => setState(() => _slope = v)),
                _dropdown('Major vessels colored by fluoroscopy', _intKeyed(kCa),
                    _ca, (v) => setState(() => _ca = v)),
                _dropdown('Thallium test result', kThal, _thal,
                    (v) => setState(() => _thal = v)),

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _predict,
                  icon: const Icon(Icons.favorite),
                  label: const Text('Predict'),
                ),

                // --- validation message ----------------------------------
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
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

  /// Build the result card: percentage, progress bar and risk band.
  Widget _resultCard(double p) {
    final (label, color) = _band(p);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estimated probability of heart disease',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${(p * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            // LinearProgressIndicator expects a value between 0.0 and 1.0.
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
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            // Kept visible on purpose: bands are arbitrary cut-offs.
            const Text(
              'Risk bands (<35% lower, 35-65% moderate, >65% higher) are illustrative '
              'cut-offs, not clinical thresholds. This is an educational project and must '
              'not be used for medical decisions.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// A labelled numeric input with a built-in range check.
  Widget _numberField(
    TextEditingController controller,
    String label,
    double min,
    double max, {
    bool isInteger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
          ),
        ],
        decoration: InputDecoration(
          labelText: label,
          helperText:
              'Range: ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)}',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// A labelled dropdown whose entries carry a numeric code.
  Widget _dropdown(
    String label,
    Map<String, double> options,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<double>(
        initialValue:
            options.containsValue(value) ? value : options.values.first,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: options.entries
            .map((e) =>
                DropdownMenuItem<double>(value: e.value, child: Text(e.key)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  /// Helper: turn [0, 1, 2, 3] into {'0': 0.0, '1': 1.0, ...} for the dropdown.
  Map<String, double> _intKeyed(List<double> values) {
    return {for (final v in values) v.toStringAsFixed(0): v};
  }
}
