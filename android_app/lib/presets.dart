// presets.dart
//
// Canonical ecosystem default inputs, clinical option codes, and 4 one-click
// clinical presets matching Python heart_risk/presets.py identically.

import 'heart_model.dart';

/// Canonical defaults shared across Streamlit and mobile clients (sex=1 Male).
const Map<String, double?> kDefaultInputs = <String, double?>{
  'age': 55.0,
  'sex': 1.0,
  'cp': 1.0,
  'trestbps': 130.0,
  'chol': 240.0,
  'fbs': 0.0,
  'restecg': 0.0,
  'thalach': 150.0,
  'exang': 0.0,
  'oldpeak': 1.0,
  'slope': 1.0,
  'ca': 0.0,
  'thal': 3.0,
};

/// Canonical categorical codes. Only labels change with language; codes never do.
const List<({String key, double code})> kSexOptions = [
  (key: 'sexFemale', code: 0.0),
  (key: 'sexMale', code: 1.0),
];

const List<({String key, double code})> kCpOptions = [
  (key: 'cpTypical', code: 1.0),
  (key: 'cpAtypical', code: 2.0),
  (key: 'cpNonAnginal', code: 3.0),
  (key: 'cpAsymptomatic', code: 4.0),
];

const List<({String key, double code})> kFbsOptions = [
  (key: 'fbsNo', code: 0.0),
  (key: 'fbsYes', code: 1.0),
];

const List<({String key, double code})> kRestecgOptions = [
  (key: 'restecgNormal', code: 0.0),
  (key: 'restecgStt', code: 1.0),
  (key: 'restecgLvh', code: 2.0),
];

const List<({String key, double code})> kExangOptions = [
  (key: 'exangNo', code: 0.0),
  (key: 'exangYes', code: 1.0),
];

const List<({String key, double code})> kSlopeOptions = [
  (key: 'slopeUpsloping', code: 1.0),
  (key: 'slopeFlat', code: 2.0),
  (key: 'slopeDownsloping', code: 3.0),
];

const List<double?> kCaOptions = <double?>[0.0, 1.0, 2.0, 3.0, null];

const List<({String key, double? code})> kThalOptions = [
  (key: 'thalNormal', code: 3.0),
  (key: 'thalFixed', code: 6.0),
  (key: 'thalReversible', code: 7.0),
  (key: 'unknownOption', code: null),
];

class ClinicalPreset {
  const ClinicalPreset({
    required this.id,
    required this.labelKey,
    required this.subtitleKey,
    required this.expectedMode,
    required this.expectedBand,
    required this.inputs,
  });

  final String id;
  final String labelKey;
  final String subtitleKey;
  final String expectedMode;
  final RiskBand expectedBand;
  final Map<String, double?> inputs;
}

const List<ClinicalPreset> kClinicalPresets = <ClinicalPreset>[
  ClinicalPreset(
    id: 'low_risk',
    labelKey: 'presetLowTitle',
    subtitleKey: 'presetLowDesc',
    expectedMode: kModeFull13,
    expectedBand: RiskBand.low,
    inputs: <String, double?>{
      'age': 42.0,
      'sex': 0.0,
      'cp': 3.0,
      'trestbps': 118.0,
      'chol': 195.0,
      'fbs': 0.0,
      'restecg': 0.0,
      'thalach': 176.0,
      'exang': 0.0,
      'oldpeak': 0.0,
      'slope': 1.0,
      'ca': 0.0,
      'thal': 3.0,
    },
  ),
  ClinicalPreset(
    id: 'moderate_risk',
    labelKey: 'presetModerateTitle',
    subtitleKey: 'presetModerateDesc',
    expectedMode: kModeFull13,
    expectedBand: RiskBand.moderate,
    inputs: <String, double?>{
      'age': 58.0,
      'sex': 1.0,
      'cp': 2.0,
      'trestbps': 142.0,
      'chol': 255.0,
      'fbs': 0.0,
      'restecg': 2.0,
      'thalach': 145.0,
      'exang': 0.0,
      'oldpeak': 1.2,
      'slope': 2.0,
      'ca': 0.0,
      'thal': 3.0,
    },
  ),
  ClinicalPreset(
    id: 'high_risk_full',
    labelKey: 'presetHighFullTitle',
    subtitleKey: 'presetHighFullDesc',
    expectedMode: kModeFull13,
    expectedBand: RiskBand.high,
    inputs: <String, double?>{
      'age': 63.0,
      'sex': 1.0,
      'cp': 4.0,
      'trestbps': 155.0,
      'chol': 285.0,
      'fbs': 0.0,
      'restecg': 2.0,
      'thalach': 118.0,
      'exang': 1.0,
      'oldpeak': 2.4,
      'slope': 2.0,
      'ca': 2.0,
      'thal': 7.0,
    },
  ),
  ClinicalPreset(
    id: 'high_risk_non_invasive',
    labelKey: 'presetHighNiTitle',
    subtitleKey: 'presetHighNiDesc',
    expectedMode: kModeNonInvasive11,
    expectedBand: RiskBand.high,
    inputs: <String, double?>{
      'age': 63.0,
      'sex': 1.0,
      'cp': 4.0,
      'trestbps': 155.0,
      'chol': 285.0,
      'fbs': 0.0,
      'restecg': 2.0,
      'thalach': 118.0,
      'exang': 1.0,
      'oldpeak': 2.4,
      'slope': 2.0,
      'ca': null,
      'thal': null,
    },
  ),
];
