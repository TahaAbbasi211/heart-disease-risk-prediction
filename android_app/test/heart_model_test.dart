// heart_model_test.dart
//
// These tests prove that the Dart formula in the app produces exactly the
// same probabilities as the Python/scikit-learn model.
//
// test/golden_cases.json is a copy of mobile_export/golden_cases.json: it holds
// 15 input rows (including rows with missing ca/thal and one unseen category)
// together with the probability scikit-learn computed for each of them.
//
// Run with:  flutter test

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/heart_model.dart';

void main() {
  // The exported model, read from the same asset file the app ships.
  late HeartModel model;
  // The expected probabilities produced by the Python pipeline.
  late Map<String, dynamic> golden;

  setUpAll(() {
    // In a Dart test the asset bundle is not available, so we read the files
    // straight from disk instead.
    model = HeartModel.fromJsonString(
      File('assets/model.json').readAsStringSync(),
    );
    golden = jsonDecode(File('test/golden_cases.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  /// Turn one JSON row into the Map<String, double?> the model expects.
  /// A JSON null means "missing" and must stay null so it gets imputed.
  Map<String, double?> inputOf(Map<String, dynamic> c) {
    final raw = c['input'] as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        entry.key:
            entry.value == null ? null : (entry.value as num).toDouble(),
    };
  }

  test('the exported formula has one coefficient per output feature', () {
    final spec = jsonDecode(File('assets/model.json').readAsStringSync())
        as Map<String, dynamic>;
    final outputFeatures = spec['output_features'] as List;
    final oneHotWidth = model.categoricalCols
        .fold<int>(0, (s, c) => s + model.categorical[c]!.categories.length);

    expect(model.coef.length, outputFeatures.length);
    expect(model.coef.length, model.numericCols.length + oneHotWidth);
    expect(model.coef.length, 28);
  });

  test('golden cases match scikit-learn within 1e-6', () {
    final tolerance = (golden['tolerance'] as num).toDouble();
    final cases = golden['cases'] as List;

    expect(cases.length, greaterThanOrEqualTo(15));

    var checked = 0;
    for (final item in cases) {
      final c = item as Map<String, dynamic>;
      final name = c['name'] as String;
      final expected = (c['probability'] as num).toDouble();
      final actual = model.predictProbability(inputOf(c));
      final diff = (actual - expected).abs();

      // `reason` shows up in the failure message, which makes a broken case
      // easy to identify.
      expect(
        diff,
        lessThan(tolerance),
        reason: '$name: Dart=$actual, sklearn=$expected, |diff|=$diff',
      );
      checked++;
    }
    // ignore: avoid_print
    print('checked $checked golden cases, all within $tolerance');
  });

  test('probabilities stay inside [0, 1]', () {
    final cases = golden['cases'] as List;
    for (final item in cases) {
      final p = model.predictProbability(inputOf(item as Map<String, dynamic>));
      expect(p, greaterThanOrEqualTo(0.0));
      expect(p, lessThanOrEqualTo(1.0));
    }
  });

  test('a missing value falls back to the imputer statistic', () {
    // Passing null for ca/thal must give the same answer as passing the
    // exported mode, because that is what the imputer does.
    final base = <String, double?>{
      'age': 53, 'sex': 0, 'cp': 3, 'trestbps': 128, 'chol': 216, 'fbs': 0,
      'restecg': 2, 'thalach': 115, 'exang': 0, 'oldpeak': 0, 'slope': 1,
    };
    final withNull = model.predictProbability(
        {...base, 'ca': null, 'thal': null});
    final withMode = model.predictProbability({
      ...base,
      'ca': model.categorical['ca']!.mode,
      'thal': model.categorical['thal']!.mode,
    });
    expect((withNull - withMode).abs(), lessThan(1e-12));
  });

  test('an unseen category matches no one-hot column', () {
    // thal=5 never appears in the training data, so its one-hot block must be
    // all zeros -- the same thing OneHotEncoder(handle_unknown="ignore") does.
    final input = <String, double?>{
      'age': 63, 'sex': 1, 'cp': 1, 'trestbps': 145, 'chol': 233, 'fbs': 1,
      'restecg': 2, 'thalach': 150, 'exang': 0, 'oldpeak': 2.3, 'slope': 3,
      'ca': 0, 'thal': 5,
    };
    final x = model.buildFeatureVector(input);
    // The last three entries are the thal one-hot columns (3, 6, 7).
    expect(x.sublist(x.length - 3), [0.0, 0.0, 0.0]);
    expect(model.predictProbability(input), closeTo(0.209344875521012, 1e-6));
  });
}
