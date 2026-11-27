// heart_controller.dart
//
// Reactive state controller backing the 3-tab BioVanta Heart V2.0.0 instrument.

import 'package:flutter/material.dart';

import '../heart_model.dart';
import '../input_parsing.dart';
import '../l10n/strings.dart';
import '../presets.dart';

class FieldValidationIssue {
  const FieldValidationIssue(this.errorKey, this.params);

  final String errorKey;
  final Map<String, Object> params;
}

class HeartController extends ChangeNotifier {
  HeartController({HeartModel? initialModel}) : _model = initialModel {
    ageCtrl = TextEditingController(text: _fmtNum('age', kDefaultInputs['age']!));
    trestbpsCtrl =
        TextEditingController(text: _fmtNum('trestbps', kDefaultInputs['trestbps']!));
    cholCtrl = TextEditingController(text: _fmtNum('chol', kDefaultInputs['chol']!));
    thalachCtrl =
        TextEditingController(text: _fmtNum('thalach', kDefaultInputs['thalach']!));
    oldpeakCtrl =
        TextEditingController(text: _fmtNum('oldpeak', kDefaultInputs['oldpeak']!));

    for (final c in <TextEditingController>[
      ageCtrl,
      trestbpsCtrl,
      cholCtrl,
      thalachCtrl,
      oldpeakCtrl,
    ]) {
      c.addListener(_onTextChanged);
    }

    _syncWhatIfFromBaseline();
    if (_model != null) {
      recompute();
    }
  }

  HeartModel? _model;
  String? _loadError;

  late final TextEditingController ageCtrl;
  late final TextEditingController trestbpsCtrl;
  late final TextEditingController cholCtrl;
  late final TextEditingController thalachCtrl;
  late final TextEditingController oldpeakCtrl;

  double _sex = kDefaultInputs['sex']!;
  double _cp = kDefaultInputs['cp']!;
  double _fbs = kDefaultInputs['fbs']!;
  double _restecg = kDefaultInputs['restecg']!;
  double _exang = kDefaultInputs['exang']!;
  double _slope = kDefaultInputs['slope']!;
  double? _ca = kDefaultInputs['ca'];
  double? _thal = kDefaultInputs['thal'];

  String _modeChoice = kModeFull13;
  String? _activePresetId;
  bool _suppressListeners = false;

  final Map<String, FieldValidationIssue> _fieldErrors =
      <String, FieldValidationIssue>{};
  PredictionResult? _result;

  // What-If interactive sensitivity state
  double _whatIfTrestbps = kDefaultInputs['trestbps']!;
  double _whatIfChol = kDefaultInputs['chol']!;
  double _whatIfThalach = kDefaultInputs['thalach']!;
  double _whatIfOldpeak = kDefaultInputs['oldpeak']!;
  bool _whatIfMaskInvasive = false;
  bool _whatIfCustomized = false;
  PredictionResult? _whatIfResult;

  HeartModel? get model => _model;
  String? get loadError => _loadError;
  bool get isReady => _model != null;
  String get modeChoice => _modeChoice;
  String? get activePresetId => _activePresetId;

  double get sex => _sex;
  double get cp => _cp;
  double get fbs => _fbs;
  double get restecg => _restecg;
  double get exang => _exang;
  double get slope => _slope;
  double? get ca => _ca;
  double? get thal => _thal;

  Map<String, FieldValidationIssue> get fieldErrors =>
      Map<String, FieldValidationIssue>.unmodifiable(_fieldErrors);
  bool get hasErrors => _fieldErrors.isNotEmpty;
  PredictionResult? get result => _result;

  bool get isAutoRouted =>
      _modeChoice == kModeFull13 &&
      _result != null &&
      _result!.mode == kModeNonInvasive11;

  double get whatIfTrestbps => _whatIfTrestbps;
  double get whatIfChol => _whatIfChol;
  double get whatIfThalach => _whatIfThalach;
  double get whatIfOldpeak => _whatIfOldpeak;
  bool get whatIfMaskInvasive => _whatIfMaskInvasive;
  PredictionResult? get whatIfResult => _whatIfResult;

  void setModel(HeartModel model) {
    _model = model;
    _loadError = null;
    recompute();
  }

  void setLoadError(String err) {
    _loadError = err;
    notifyListeners();
  }

  static String _fmtNum(String col, double val) {
    if (col == 'oldpeak') return val.toStringAsFixed(1);
    return val.toStringAsFixed(0);
  }

  void _onTextChanged() {
    if (_suppressListeners) return;
    _activePresetId = null;
    recompute();
  }

  void setModeChoice(String mode) {
    if (_modeChoice == mode) return;
    _modeChoice = mode;
    _activePresetId = null;
    if (!_whatIfCustomized) {
      _whatIfMaskInvasive =
          mode == kModeNonInvasive11 || _ca == null || _thal == null;
    }
    recompute();
  }

  void setSex(double v) {
    _sex = v;
    _activePresetId = null;
    recompute();
  }

  void setCp(double v) {
    _cp = v;
    _activePresetId = null;
    recompute();
  }

  void setFbs(double v) {
    _fbs = v;
    _activePresetId = null;
    recompute();
  }

  void setRestecg(double v) {
    _restecg = v;
    _activePresetId = null;
    recompute();
  }

  void setExang(double v) {
    _exang = v;
    _activePresetId = null;
    recompute();
  }

  void setSlope(double v) {
    _slope = v;
    _activePresetId = null;
    recompute();
  }

  void setCa(double? v) {
    _ca = v;
    _activePresetId = null;
    if (!_whatIfCustomized) {
      _whatIfMaskInvasive =
          _modeChoice == kModeNonInvasive11 || _ca == null || _thal == null;
    }
    recompute();
  }

  void setThal(double? v) {
    _thal = v;
    _activePresetId = null;
    if (!_whatIfCustomized) {
      _whatIfMaskInvasive =
          _modeChoice == kModeNonInvasive11 || _ca == null || _thal == null;
    }
    recompute();
  }

  void applyPreset(ClinicalPreset preset) {
    _suppressListeners = true;
    try {
      final p = preset.inputs;
      ageCtrl.text = _fmtNum('age', p['age']!);
      trestbpsCtrl.text = _fmtNum('trestbps', p['trestbps']!);
      cholCtrl.text = _fmtNum('chol', p['chol']!);
      thalachCtrl.text = _fmtNum('thalach', p['thalach']!);
      oldpeakCtrl.text = _fmtNum('oldpeak', p['oldpeak']!);
      _sex = p['sex']!;
      _cp = p['cp']!;
      _fbs = p['fbs']!;
      _restecg = p['restecg']!;
      _exang = p['exang']!;
      _slope = p['slope']!;
      _ca = p['ca'];
      _thal = p['thal'];
      _modeChoice = preset.expectedMode;
      _activePresetId = preset.id;
      _whatIfCustomized = false;
      _syncWhatIfFromBaseline();
    } finally {
      _suppressListeners = false;
    }
    recompute();
  }

  void updateWhatIf({
    double? trestbps,
    double? chol,
    double? thalach,
    double? oldpeak,
    bool? maskInvasive,
  }) {
    _whatIfCustomized = true;
    if (trestbps != null) _whatIfTrestbps = trestbps;
    if (chol != null) _whatIfChol = chol;
    if (thalach != null) _whatIfThalach = thalach;
    if (oldpeak != null) _whatIfOldpeak = oldpeak;
    if (maskInvasive != null) _whatIfMaskInvasive = maskInvasive;
    _recomputeWhatIfOnly();
    notifyListeners();
  }

  void resetWhatIf() {
    _whatIfCustomized = false;
    _syncWhatIfFromBaseline();
    _recomputeWhatIfOnly();
    notifyListeners();
  }

  double? _parseField(String col, TextEditingController ctrl) {
    final raw = ctrl.text;
    if (raw.trim().isEmpty) {
      _fieldErrors[col] = FieldValidationIssue('errorPleaseEnter', {'field': col});
      return null;
    }
    final parsed = parseLocalizedNumber(raw);
    if (parsed == null) {
      _fieldErrors[col] = FieldValidationIssue('errorNotANumber', {'field': col});
      return null;
    }
    final b = kNumericBounds[col]!;
    if (parsed < b.min || parsed > b.max) {
      _fieldErrors[col] = FieldValidationIssue('errorOutOfRange', {
        'field': col,
        'min': b.min.toStringAsFixed(0),
        'max': b.max.toStringAsFixed(0),
      });
      return null;
    }
    return parsed;
  }

  void _syncWhatIfFromBaseline() {
    _whatIfTrestbps =
        (parseLocalizedNumber(trestbpsCtrl.text) ?? kDefaultInputs['trestbps']!)
            .clamp(kNumericBounds['trestbps']!.min, kNumericBounds['trestbps']!.max);
    _whatIfChol =
        (parseLocalizedNumber(cholCtrl.text) ?? kDefaultInputs['chol']!)
            .clamp(kNumericBounds['chol']!.min, kNumericBounds['chol']!.max);
    _whatIfThalach =
        (parseLocalizedNumber(thalachCtrl.text) ?? kDefaultInputs['thalach']!)
            .clamp(kNumericBounds['thalach']!.min, kNumericBounds['thalach']!.max);
    _whatIfOldpeak =
        (parseLocalizedNumber(oldpeakCtrl.text) ?? kDefaultInputs['oldpeak']!)
            .clamp(kNumericBounds['oldpeak']!.min, kNumericBounds['oldpeak']!.max);
    _whatIfMaskInvasive =
        _modeChoice == kModeNonInvasive11 || _ca == null || _thal == null;
  }

  Map<String, double?>? _buildCurrentInputs() {
    _fieldErrors.clear();
    final age = _parseField('age', ageCtrl);
    final trestbps = _parseField('trestbps', trestbpsCtrl);
    final chol = _parseField('chol', cholCtrl);
    final thalach = _parseField('thalach', thalachCtrl);
    final oldpeak = _parseField('oldpeak', oldpeakCtrl);
    if (_fieldErrors.isNotEmpty) return null;

    return <String, double?>{
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
      'ca': _modeChoice == kModeFull13 ? _ca : null,
      'thal': _modeChoice == kModeFull13 ? _thal : null,
    };
  }

  void recompute() {
    final mdl = _model;
    if (mdl == null) {
      notifyListeners();
      return;
    }
    final inputs = _buildCurrentInputs();
    if (inputs != null) {
      final requestedMode =
          _modeChoice == kModeFull13 ? kModeAuto : kModeNonInvasive11;
      _result = mdl.predict(inputs, mode: requestedMode, validate: true);
      if (!_whatIfCustomized) {
        _syncWhatIfFromBaseline();
      }
      _recomputeWhatIfOnly(baselineInputs: inputs);
    }
    notifyListeners();
  }

  void _recomputeWhatIfOnly({Map<String, double?>? baselineInputs}) {
    final mdl = _model;
    if (mdl == null) return;
    final base = baselineInputs ?? _buildCurrentInputs();
    if (base == null) return;

    final sim = Map<String, double?>.from(base);
    sim['trestbps'] = _whatIfTrestbps;
    sim['chol'] = _whatIfChol;
    sim['thalach'] = _whatIfThalach;
    sim['oldpeak'] = _whatIfOldpeak;
    if (_whatIfMaskInvasive) {
      sim['ca'] = null;
      sim['thal'] = null;
    }

    final reqMode = _whatIfMaskInvasive
        ? kModeNonInvasive11
        : (_modeChoice == kModeFull13 && sim['ca'] != null && sim['thal'] != null
            ? kModeAuto
            : kModeNonInvasive11);
    _whatIfResult = mdl.predict(sim, mode: reqMode, validate: true);
  }

  String formatIssue(AppStrings s, FieldValidationIssue issue) {
    final resolved = <String, Object>{
      for (final entry in issue.params.entries)
        entry.key: entry.key == 'field'
            ? s.s(entry.value as String)
            : entry.value,
    };
    return s.sf(issue.errorKey, resolved);
  }

  String formatContributionValue(AppStrings s, FeatureContribution c) {
    if (c.imputed) return s.s('unknownOption');
    final v = c.usedValue;
    switch (c.feature) {
      case 'sex':
        return _optLabel(s, kSexOptions, v);
      case 'cp':
        return _optLabel(s, kCpOptions, v);
      case 'fbs':
        return _optLabel(s, kFbsOptions, v);
      case 'restecg':
        return _optLabel(s, kRestecgOptions, v);
      case 'exang':
        return _optLabel(s, kExangOptions, v);
      case 'slope':
        return _optLabel(s, kSlopeOptions, v);
      case 'thal':
        final opt = kThalOptions.where((o) => o.code == v).firstOrNull;
        return opt != null ? '${s.s(opt.key)} (${v.toInt()})' : v.toString();
      case 'ca':
        return v.toStringAsFixed(0);
      case 'oldpeak':
        return v.toStringAsFixed(1);
      default:
        return v.toStringAsFixed(0);
    }
  }

  String _optLabel(
    AppStrings s,
    List<({String key, double code})> options,
    double v,
  ) {
    final opt = options.where((o) => o.code == v).firstOrNull;
    return opt != null ? s.s(opt.key) : v.toString();
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      ageCtrl,
      trestbpsCtrl,
      cholCtrl,
      thalachCtrl,
      oldpeakCtrl,
    ]) {
      c.removeListener(_onTextChanged);
      c.dispose();
    }
    super.dispose();
  }
}
