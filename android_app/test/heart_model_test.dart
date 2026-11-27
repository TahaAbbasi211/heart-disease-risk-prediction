// heart_model_test.dart
//
// Proves exact parity between Dart HeartModel v2, Python heart_risk/engine.py,
// scikit-learn golden cases v2 (< 1e-12), clinical auto-routing safety, and validation.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/heart_model.dart';
import 'package:heart_risk_offline/presets.dart';

void main() {
  late HeartModel model;
  late Map<String, dynamic> golden;

  setUpAll(() {
    model = HeartModel.fromJsonString(
      File('assets/model.json').readAsStringSync(),
    );
    golden = jsonDecode(File('test/golden_cases.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  Map<String, double?> inputOf(Map<String, dynamic> c) {
    final raw = c['input'] as Map<String, dynamic>;
    return <String, double?>{
      for (final entry in raw.entries)
        entry.key:
            entry.value == null ? null : (entry.value as num).toDouble(),
    };
  }

  test('assets/model.json and test/golden_cases.json match mobile_export byte-for-byte', () {
    expect(
      File('assets/model.json').readAsBytesSync(),
      orderedEquals(File('../mobile_export/model.json').readAsBytesSync()),
    );
    expect(
      File('test/golden_cases.json').readAsBytesSync(),
      orderedEquals(File('../mobile_export/golden_cases.json').readAsBytesSync()),
    );
  });

  test('schema v2 exposes full_13 (28), non_invasive_11 (21), risk_bands & external validation', () {
    expect(model.schemaVersion, 2);
    expect(model.format, kExpectedFormat);
    expect(model.lowMax, 0.35);
    expect(model.moderateMax, 0.65);

    expect(model.full13.nInputFeatures, 13);
    expect(model.full13.coef.length, 28);
    expect(model.full13.outputFeatures.length, 28);
    expect(model.full13.metadata?.sklearnVersion, '1.6.1');

    expect(model.nonInvasive11.nInputFeatures, 11);
    expect(model.nonInvasive11.coef.length, 21);
    expect(model.nonInvasive11.outputFeatures.length, 21);
    expect(model.nonInvasive11.categoricalCols.contains('ca'), isFalse);
    expect(model.nonInvasive11.categoricalCols.contains('thal'), isFalse);
    expect(model.nonInvasive11.metadata?.sklearnVersion, '1.6.1');

    expect(model.externalValidation, isNotNull);
    expect(
      model.externalValidation!.cohorts.keys,
      containsAll(<String>['hungarian', 'switzerland', 'va', 'pooled_external']),
    );
  });

  test('all 27 golden cases match probability, z, intercept, and deltaZ within 1e-12', () {
    expect(golden['schema_version'], 2);
    expect(golden['format'], 'heart-risk-golden-cases/2');
    final cases = golden['cases'] as List<dynamic>;
    expect(cases.length, 27);

    final modesSeen = <String>{};
    for (final item in cases) {
      final c = item as Map<String, dynamic>;
      final name = c['name'] as String;
      final mode = c['mode'] as String;
      modesSeen.add(mode);

      final res = model.predict(inputOf(c), mode: mode, validate: false);
      final expProb = (c['probability'] as num).toDouble();
      final expZ = (c['z'] as num).toDouble();
      final expIntercept = (c['intercept'] as num).toDouble();
      final expContrib = c['contributions'] as Map<String, dynamic>;

      expect((res.probability - expProb).abs(), lessThan(1e-12), reason: name);
      expect((res.z - expZ).abs(), lessThan(1e-12), reason: name);
      expect((res.intercept - expIntercept).abs(), lessThan(1e-12), reason: name);

      var reconstructedZ = res.intercept;
      for (final fc in res.contributions) {
        reconstructedZ += fc.deltaZ;
      }
      expect((reconstructedZ - res.z).abs(), lessThan(1e-12), reason: name);

      final actualMap = res.contributionMap();
      expect(actualMap.keys.toSet(), equals(expContrib.keys.toSet()), reason: name);
      for (final entry in expContrib.entries) {
        final diff = (actualMap[entry.key]! - (entry.value as num).toDouble()).abs();
        expect(diff, lessThan(1e-12), reason: '$name:${entry.key}');
      }
    }
    expect(modesSeen, equals(<String>{kModeFull13, kModeNonInvasive11}));
  });

  test('auto-routing prevents healthy-mode false-reassurance trap (including row 292)', () {
    final fullRes = model.predict(kDefaultInputs, mode: kModeAuto);
    expect(fullRes.mode, kModeFull13);
    expect(fullRes.probability, closeTo(0.0561, 1e-3));

    expect(
      model.predict({...kDefaultInputs, 'ca': null}, mode: kModeAuto).mode,
      kModeNonInvasive11,
    );
    expect(
      model.predict({...kDefaultInputs, 'thal': null}, mode: kModeAuto).mode,
      kModeNonInvasive11,
    );

    // Real positive Cleveland row 292: missing ca/thal keeps high risk (71.4%)
    // via auto-routing, whereas naive mode-imputation drops below 50% (44.5%).
    const row292Masked = <String, double?>{
      'age': 44,
      'sex': 1,
      'cp': 4,
      'trestbps': 120,
      'chol': 169,
      'fbs': 0,
      'restecg': 0,
      'thalach': 144,
      'exang': 1,
      'oldpeak': 2.8,
      'slope': 3,
      'ca': null,
      'thal': null,
    };
    final safeRes = model.predict(row292Masked, mode: kModeAuto);
    final naiveRes = model.predict(row292Masked, mode: kModeFull13);
    expect(safeRes.mode, kModeNonInvasive11);
    expect(safeRes.riskBand, RiskBand.high);
    expect(safeRes.predClass, 1);
    expect(naiveRes.predClass, 0);
    expect(naiveRes.imputedCols, equals(<String>['ca', 'thal']));
  });

  test('validate:true rejects NaN, Infinity, out-of-bounds, and invalid categoricals', () {
    final invalidPatches = <Map<String, double?>>[
      {'age': double.nan},
      {'age': double.infinity},
      {'oldpeak': double.negativeInfinity},
      {'age': 19},
      {'age': 101},
      {'trestbps': 79},
      {'trestbps': 221},
      {'chol': 99},
      {'chol': 601},
      {'thalach': 59},
      {'thalach': 221},
      {'oldpeak': -0.1},
      {'oldpeak': 7.1},
      {'ca': 99},
      {'thal': 5},
      {'ca': 99, 'thal': null},
      {'ca': null, 'thal': 5},
      {'cp': 9},
      {'sex': 2},
      {'slope': 9},
    ];

    for (final patch in invalidPatches) {
      expect(
        () => model.predict({...kDefaultInputs, ...patch}, mode: kModeAuto),
        throwsA(isA<HeartValidationException>()),
        reason: 'Expected HeartValidationException for $patch',
      );
    }

    expect(
      () => model.predict({...kDefaultInputs, 'cp': 9}, mode: kModeNonInvasive11),
      throwsA(isA<HeartValidationException>()),
    );
  });

  test('validate:false supports unseen category parity with sklearn handle_unknown=ignore', () {
    final resFull = model.predict(
      {...kDefaultInputs, 'thal': 5.0},
      mode: kModeFull13,
      validate: false,
    );
    expect(resFull.unseenCols, equals(<String>['thal']));
    expect(resFull.contributionMap()['thal'], 0.0);

    final resNi = model.predict(
      {...kDefaultInputs, 'cp': 9.0, 'ca': null, 'thal': null},
      mode: kModeAuto,
      validate: false,
    );
    expect(resNi.mode, kModeNonInvasive11);
    expect(resNi.unseenCols, equals(<String>['cp']));
    expect(resNi.contributionMap()['cp'], 0.0);
  });

  test('risk_bands thresholds are read from JSON and validated', () {
    final raw = jsonDecode(File('assets/model.json').readAsStringSync())
        as Map<String, dynamic>;
    raw['risk_bands'] = <String, dynamic>{
      'low_max': 0.04,
      'moderate_max': 0.05,
    };
    final strictModel = HeartModel.fromJson(raw);
    expect(
      strictModel.predict(kDefaultInputs, mode: kModeAuto).riskBand,
      RiskBand.high,
    );

    raw['risk_bands'] = <String, dynamic>{
      'low_max': 0.70,
      'moderate_max': 0.50,
    };
    expect(
      () => HeartModel.fromJson(raw),
      throwsA(isA<HeartValidationException>()),
    );
  });

  test('stableSigmoid handles extreme z without overflow and rejects non-finite', () {
    expect(stableSigmoid(-1000.0), 0.0);
    expect(stableSigmoid(1000.0), 1.0);
    expect(stableSigmoid(0.0), 0.5);
    expect(stableSigmoid(-12.5), closeTo(1.0 - stableSigmoid(12.5), 1e-12));
    expect(() => stableSigmoid(double.nan), throwsA(isA<HeartValidationException>()));
    expect(() => stableSigmoid(double.infinity), throwsA(isA<HeartValidationException>()));
  });

  test('canonical defaults and all 4 presets match expected modes and risk bands', () {
    expect(kDefaultInputs['sex'], 1.0);
    for (final preset in kClinicalPresets) {
      final res = model.predict(preset.inputs, mode: kModeAuto);
      expect(res.mode, preset.expectedMode, reason: preset.id);
      expect(res.riskBand, preset.expectedBand, reason: preset.id);
    }
  });
}
