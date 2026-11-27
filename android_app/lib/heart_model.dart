// heart_model.dart
//
// Pure dependency-free Dart implementation of the dual-mode Logistic Regression
// heart risk formula exported in assets/model.json (schema heart-risk-linear-formula/2).
//
// Mirrors Python heart_risk/engine.py identically:
//   * Supports two modes: full_13 (28 encoded features) and non_invasive_11 (21 encoded features)
//   * Auto-routes to non_invasive_11 whenever ca == null or thal == null
//   * Enforces physiological bounds and valid category codes when validate == true
//   * Reads risk_bands (low_max, moderate_max) directly from model.json
//   * Returns exact additive log-odds contributions (intercept + sum(deltaZ) == z)

import 'dart:convert';
import 'dart:math' as math;

const String kExpectedFormat = 'heart-risk-linear-formula/2';
const int kExpectedSchemaVersion = 2;

const String kModeAuto = 'auto';
const String kModeFull13 = 'full_13';
const String kModeNonInvasive11 = 'non_invasive_11';
const List<String> kValidModes = <String>[
  kModeAuto,
  kModeFull13,
  kModeNonInvasive11,
];

const Map<String, ({double min, double max})> kNumericBounds =
    <String, ({double min, double max})>{
  'age': (min: 20.0, max: 100.0),
  'trestbps': (min: 80.0, max: 220.0),
  'chol': (min: 100.0, max: 600.0),
  'thalach': (min: 60.0, max: 220.0),
  'oldpeak': (min: 0.0, max: 7.0),
};

class HeartValidationException implements Exception {
  HeartValidationException(this.message);

  final String message;

  @override
  String toString() => 'HeartValidationException: $message';
}

enum RiskBand { low, moderate, high }

/// Numerically stable two-branch logistic sigmoid avoiding overflow for large |z|.
double stableSigmoid(double z) {
  if (!z.isFinite) {
    throw HeartValidationException('Log-odds z must be finite, got $z.');
  }
  if (z >= 0.0) {
    return 1.0 / (1.0 + math.exp(-z));
  }
  final ez = math.exp(z);
  return ez / (1.0 + ez);
}

RiskBand classifyRiskBand(
  double probability, {
  required double lowMax,
  required double moderateMax,
}) {
  if (probability < lowMax) return RiskBand.low;
  if (probability < moderateMax) return RiskBand.moderate;
  return RiskBand.high;
}

class NumericStats {
  const NumericStats({
    required this.median,
    required this.mean,
    required this.scale,
  });

  final double median;
  final double mean;
  final double scale;

  factory NumericStats.fromJson(String col, Map<String, dynamic> json) {
    final median = (json['median'] as num).toDouble();
    final mean = (json['mean'] as num).toDouble();
    final scale = (json['scale'] as num).toDouble();
    if (!median.isFinite || !mean.isFinite || !scale.isFinite || scale <= 0.0) {
      throw HeartValidationException(
        'Invalid numeric stats for "$col": scale must be finite and > 0.',
      );
    }
    return NumericStats(median: median, mean: mean, scale: scale);
  }
}

class CategoricalStats {
  const CategoricalStats({
    required this.mode,
    required this.categories,
  });

  final double mode;
  final List<double> categories;

  factory CategoricalStats.fromJson(String col, Map<String, dynamic> json) {
    final rawCats = json['categories'];
    if (rawCats is! List || rawCats.isEmpty) {
      throw HeartValidationException(
        'Categorical "$col" must define a non-empty categories list.',
      );
    }
    return CategoricalStats(
      mode: (json['mode'] as num).toDouble(),
      categories: rawCats.map((c) => (c as num).toDouble()).toList(),
    );
  }
}

class MetricSummary {
  const MetricSummary({
    required this.mean,
    required this.std,
    required this.foldRange95,
  });

  final double mean;
  final double std;
  final List<double> foldRange95;

  factory MetricSummary.fromJson(Map<String, dynamic> json) {
    final rangeRaw = (json['fold_range_95'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    return MetricSummary(
      mean: (json['mean'] as num).toDouble(),
      std: (json['std'] as num).toDouble(),
      foldRange95: rangeRaw,
    );
  }
}

class RepeatedCvMetadata {
  const RepeatedCvMetadata({
    required this.rocAuc,
    required this.prAuc,
    required this.brier,
    required this.ece10Bin,
    required this.logLoss,
  });

  final MetricSummary rocAuc;
  final MetricSummary prAuc;
  final MetricSummary brier;
  final MetricSummary ece10Bin;
  final MetricSummary logLoss;

  factory RepeatedCvMetadata.fromJson(Map<String, dynamic> json) {
    return RepeatedCvMetadata(
      rocAuc: MetricSummary.fromJson(json['roc_auc'] as Map<String, dynamic>),
      prAuc: MetricSummary.fromJson(json['pr_auc'] as Map<String, dynamic>),
      brier: MetricSummary.fromJson(json['brier'] as Map<String, dynamic>),
      ece10Bin:
          MetricSummary.fromJson(json['ece_10bin'] as Map<String, dynamic>),
      logLoss: MetricSummary.fromJson(json['log_loss'] as Map<String, dynamic>),
    );
  }
}

class Test61Metadata {
  const Test61Metadata({
    required this.n,
    required this.rocAuc,
    required this.prAuc,
    required this.brier,
    required this.ece10Bin,
    required this.logLoss,
    required this.recall,
    required this.precision,
  });

  final int n;
  final double rocAuc;
  final double prAuc;
  final double brier;
  final double ece10Bin;
  final double logLoss;
  final double recall;
  final double precision;

  factory Test61Metadata.fromJson(Map<String, dynamic> json) {
    return Test61Metadata(
      n: (json['n'] as num).toInt(),
      rocAuc: (json['roc_auc'] as num).toDouble(),
      prAuc: (json['pr_auc'] as num).toDouble(),
      brier: (json['brier'] as num).toDouble(),
      ece10Bin: (json['ece_10bin'] as num).toDouble(),
      logLoss: (json['log_loss'] as num).toDouble(),
      recall: (json['recall'] as num).toDouble(),
      precision: (json['precision'] as num).toDouble(),
    );
  }
}

class ModeMetadata {
  const ModeMetadata({
    required this.c,
    required this.cv5FoldTrainAuc,
    required this.cv5FoldTrainStd,
    required this.cv10x5Repeated,
    required this.test61,
    required this.sklearnVersion,
  });

  final double c;
  final double cv5FoldTrainAuc;
  final double cv5FoldTrainStd;
  final RepeatedCvMetadata cv10x5Repeated;
  final Test61Metadata test61;
  final String sklearnVersion;

  factory ModeMetadata.fromJson(Map<String, dynamic> json) {
    return ModeMetadata(
      c: (json['C'] as num).toDouble(),
      cv5FoldTrainAuc: (json['cv_5fold_train_auc'] as num).toDouble(),
      cv5FoldTrainStd: (json['cv_5fold_train_std'] as num).toDouble(),
      cv10x5Repeated: RepeatedCvMetadata.fromJson(
        json['cv_10x5_repeated'] as Map<String, dynamic>,
      ),
      test61: Test61Metadata.fromJson(json['test_61'] as Map<String, dynamic>),
      sklearnVersion: json['sklearn_version'] as String,
    );
  }
}

class ExternalVariantMetrics {
  const ExternalVariantMetrics({
    required this.rocAuc,
    required this.prAuc,
    required this.brier,
    required this.ece10Bin,
    required this.logLoss,
    required this.meanPredProb,
  });

  final double rocAuc;
  final double prAuc;
  final double brier;
  final double ece10Bin;
  final double logLoss;
  final double meanPredProb;

  factory ExternalVariantMetrics.fromJson(Map<String, dynamic> json) {
    return ExternalVariantMetrics(
      rocAuc: (json['roc_auc'] as num).toDouble(),
      prAuc: (json['pr_auc'] as num).toDouble(),
      brier: (json['brier'] as num).toDouble(),
      ece10Bin: (json['ece_10bin'] as num).toDouble(),
      logLoss: (json['log_loss'] as num).toDouble(),
      meanPredProb: (json['mean_pred_prob'] as num).toDouble(),
    );
  }
}

class ExternalCohortMetrics {
  const ExternalCohortMetrics({
    required this.key,
    required this.label,
    required this.n,
    required this.nPos,
    required this.prevalence,
    required this.cholZeroCount,
    required this.trestbpsZeroCount,
    required this.raw,
    required this.impossibleZerosAsNan,
  });

  final String key;
  final String label;
  final int n;
  final int nPos;
  final double prevalence;
  final int cholZeroCount;
  final int trestbpsZeroCount;
  final ExternalVariantMetrics raw;
  final ExternalVariantMetrics impossibleZerosAsNan;

  factory ExternalCohortMetrics.fromJson(
    String key,
    Map<String, dynamic> json,
  ) {
    return ExternalCohortMetrics(
      key: key,
      label: json['label'] as String,
      n: (json['n'] as num).toInt(),
      nPos: (json['n_pos'] as num).toInt(),
      prevalence: (json['prevalence'] as num).toDouble(),
      cholZeroCount: (json['chol_zero_count'] as num).toInt(),
      trestbpsZeroCount: (json['trestbps_zero_count'] as num).toInt(),
      raw: ExternalVariantMetrics.fromJson(json['raw'] as Map<String, dynamic>),
      impossibleZerosAsNan: ExternalVariantMetrics.fromJson(
        json['impossible_zeros_as_nan'] as Map<String, dynamic>,
      ),
    );
  }
}

class ExternalValidationMetadata {
  const ExternalValidationMetadata({
    required this.modelEvaluated,
    required this.zeroRetraining,
    required this.cohorts,
  });

  final String modelEvaluated;
  final bool zeroRetraining;
  final Map<String, ExternalCohortMetrics> cohorts;

  factory ExternalValidationMetadata.fromJson(Map<String, dynamic> json) {
    final rawCohorts = json['cohorts'] as Map<String, dynamic>;
    return ExternalValidationMetadata(
      modelEvaluated: json['model_evaluated'] as String,
      zeroRetraining: json['zero_retraining'] as bool,
      cohorts: <String, ExternalCohortMetrics>{
        for (final entry in rawCohorts.entries)
          entry.key: ExternalCohortMetrics.fromJson(
            entry.key,
            entry.value as Map<String, dynamic>,
          ),
      },
    );
  }
}

class LinearModeSpec {
  LinearModeSpec({
    required this.name,
    required this.nInputFeatures,
    required this.numericCols,
    required this.categoricalCols,
    required this.numeric,
    required this.categorical,
    required this.outputFeatures,
    required this.coef,
    required this.intercept,
    this.metadata,
  }) : allowedCategories = <String, Set<double>>{
          for (final col in categoricalCols)
            col: categorical[col]!.categories.toSet(),
        };

  final String name;
  final int nInputFeatures;
  final List<String> numericCols;
  final List<String> categoricalCols;
  final Map<String, NumericStats> numeric;
  final Map<String, CategoricalStats> categorical;
  final List<String> outputFeatures;
  final List<double> coef;
  final double intercept;
  final ModeMetadata? metadata;
  final Map<String, Set<double>> allowedCategories;

  factory LinearModeSpec.fromJson(
    String expectedName,
    Map<String, dynamic> json,
  ) {
    final numericCols = (json['numeric_cols'] as List).cast<String>();
    final categoricalCols = (json['categorical_cols'] as List).cast<String>();
    final outputFeatures = (json['output_features'] as List).cast<String>();
    final coef = (json['coef'] as List).map((c) => (c as num).toDouble()).toList();
    final intercept = (json['intercept'] as num).toDouble();

    if (coef.length != outputFeatures.length) {
      throw HeartValidationException(
        'Model "$expectedName" coef length (${coef.length}) != output_features (${outputFeatures.length}).',
      );
    }

    final rawNum = json['numeric'] as Map<String, dynamic>;
    final numeric = <String, NumericStats>{
      for (final col in numericCols)
        col: NumericStats.fromJson(col, rawNum[col] as Map<String, dynamic>),
    };

    final rawCat = json['categorical'] as Map<String, dynamic>;
    final categorical = <String, CategoricalStats>{
      for (final col in categoricalCols)
        col: CategoricalStats.fromJson(col, rawCat[col] as Map<String, dynamic>),
    };

    final expectedDim = numericCols.length +
        categoricalCols.fold<int>(
          0,
          (sum, col) => sum + categorical[col]!.categories.length,
        );
    if (expectedDim != coef.length) {
      throw HeartValidationException(
        'Model "$expectedName" expanded width ($expectedDim) != coef length (${coef.length}).',
      );
    }

    final metaRaw = json['metadata'];
    return LinearModeSpec(
      name: (json['name'] as String?) ?? expectedName,
      nInputFeatures: (json['n_input_features'] as num?)?.toInt() ??
          (numericCols.length + categoricalCols.length),
      numericCols: numericCols,
      categoricalCols: categoricalCols,
      numeric: numeric,
      categorical: categorical,
      outputFeatures: outputFeatures,
      coef: coef,
      intercept: intercept,
      metadata: metaRaw is Map<String, dynamic>
          ? ModeMetadata.fromJson(metaRaw)
          : null,
    );
  }
}

class FeatureContribution {
  const FeatureContribution({
    required this.feature,
    required this.kind,
    required this.rawValue,
    required this.usedValue,
    required this.deltaZ,
    required this.imputed,
    required this.unseen,
    required this.outputFeature,
  });

  final String feature;
  final String kind;
  final double? rawValue;
  final double usedValue;
  final double deltaZ;
  final bool imputed;
  final bool unseen;
  final String? outputFeature;
}

class PredictionResult {
  const PredictionResult({
    required this.mode,
    required this.requestedMode,
    required this.probability,
    required this.probabilityAbsent,
    required this.predClass,
    required this.riskBand,
    required this.z,
    required this.intercept,
    required this.contributions,
    required this.imputedCols,
    required this.unseenCols,
  });

  final String mode;
  final String requestedMode;
  final double probability;
  final double probabilityAbsent;
  final int predClass;
  final RiskBand riskBand;
  final double z;
  final double intercept;
  final List<FeatureContribution> contributions;
  final List<String> imputedCols;
  final List<String> unseenCols;

  Map<String, double> contributionMap() => <String, double>{
        for (final c in contributions) c.feature: c.deltaZ,
      };
}

class HeartModel {
  HeartModel({
    required this.schemaVersion,
    required this.format,
    required this.defaultMode,
    required this.lowMax,
    required this.moderateMax,
    required this.models,
    required this.sourceBytes,
    this.externalValidation,
    this.datasetLabel,
    this.sklearnVersion,
  });

  final int schemaVersion;
  final String format;
  final String defaultMode;
  final double lowMax;
  final double moderateMax;
  final Map<String, LinearModeSpec> models;
  final int sourceBytes;
  final ExternalValidationMetadata? externalValidation;
  final String? datasetLabel;
  final String? sklearnVersion;

  LinearModeSpec get full13 => models[kModeFull13]!;
  LinearModeSpec get nonInvasive11 => models[kModeNonInvasive11]!;

  factory HeartModel.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw HeartValidationException('Model JSON root must be an object.');
    }
    final byteLen = utf8.encode(source).length;
    return HeartModel.fromJson(decoded, sourceBytes: byteLen);
  }

  factory HeartModel.fromJson(
    Map<String, dynamic> json, {
    int sourceBytes = 0,
  }) {
    final format = json['format'];
    final schemaVersion = (json['schema_version'] as num?)?.toInt();
    if (format != kExpectedFormat || schemaVersion != kExpectedSchemaVersion) {
      throw HeartValidationException(
        'Unsupported model schema: format=$format, schema_version=$schemaVersion.',
      );
    }

    final rawBands = json['risk_bands'];
    if (rawBands is! Map<String, dynamic> ||
        rawBands['low_max'] is! num ||
        rawBands['moderate_max'] is! num) {
      throw HeartValidationException(
        'Model JSON must define numeric risk_bands.low_max and risk_bands.moderate_max.',
      );
    }
    final lowMax = (rawBands['low_max'] as num).toDouble();
    final moderateMax = (rawBands['moderate_max'] as num).toDouble();
    if (!lowMax.isFinite ||
        !moderateMax.isFinite ||
        !(0.0 < lowMax && lowMax < moderateMax && moderateMax < 1.0)) {
      throw HeartValidationException(
        'Invalid risk_bands thresholds: low_max=$lowMax, moderate_max=$moderateMax.',
      );
    }

    final rawModels = json['models'];
    if (rawModels is! Map<String, dynamic>) {
      throw HeartValidationException('Model JSON missing "models" object.');
    }
    for (final key in const [kModeFull13, kModeNonInvasive11]) {
      if (rawModels[key] is! Map<String, dynamic>) {
        throw HeartValidationException('Model JSON missing required "$key" model.');
      }
    }

    final models = <String, LinearModeSpec>{
      kModeFull13: LinearModeSpec.fromJson(
        kModeFull13,
        rawModels[kModeFull13] as Map<String, dynamic>,
      ),
      kModeNonInvasive11: LinearModeSpec.fromJson(
        kModeNonInvasive11,
        rawModels[kModeNonInvasive11] as Map<String, dynamic>,
      ),
    };

    final meta = json['metadata'] as Map<String, dynamic>?;
    final rawExt = meta?['external_validation'];
    return HeartModel(
      schemaVersion: schemaVersion!,
      format: format as String,
      defaultMode: (json['default_mode'] as String?) ?? kModeFull13,
      lowMax: lowMax,
      moderateMax: moderateMax,
      models: models,
      sourceBytes: sourceBytes,
      externalValidation: rawExt is Map<String, dynamic>
          ? ExternalValidationMetadata.fromJson(rawExt)
          : null,
      datasetLabel: meta?['dataset'] as String?,
      sklearnVersion: meta?['sklearn_version'] as String?,
    );
  }

  double? _coerceValue(String col, double? raw, {required bool validate}) {
    if (raw == null) return null;
    if (raw.isNaN) {
      if (validate) {
        throw HeartValidationException("Input '$col' cannot be NaN.");
      }
      return null;
    }
    if (!raw.isFinite) {
      throw HeartValidationException("Input '$col' must be finite, got $raw.");
    }
    return raw;
  }

  String _selectMode(
    Map<String, double?> inputs,
    String mode, {
    required bool validate,
  }) {
    if (!kValidModes.contains(mode)) {
      throw HeartValidationException(
        'Unknown mode "$mode"; expected one of $kValidModes.',
      );
    }
    if (mode != kModeAuto) {
      return mode;
    }

    final caVal = _coerceValue('ca', inputs['ca'], validate: validate);
    final thalVal = _coerceValue('thal', inputs['thal'], validate: validate);
    if (validate) {
      final allowedCa = full13.allowedCategories['ca']!;
      if (caVal != null && !allowedCa.contains(caVal)) {
        throw HeartValidationException(
          "Invalid 'ca'=$caVal; allowed values: ${allowedCa.toList()..sort()}.",
        );
      }
      final allowedThal = full13.allowedCategories['thal']!;
      if (thalVal != null && !allowedThal.contains(thalVal)) {
        throw HeartValidationException(
          "Invalid 'thal'=$thalVal; allowed values: ${allowedThal.toList()..sort()}.",
        );
      }
    }

    if (caVal == null || thalVal == null) {
      return kModeNonInvasive11;
    }
    return kModeFull13;
  }

  PredictionResult predict(
    Map<String, double?> inputs, {
    String mode = kModeAuto,
    bool validate = true,
  }) {
    final activeMode = _selectMode(inputs, mode, validate: validate);
    final spec = models[activeMode]!;
    final contributions = <FeatureContribution>[];
    final imputedCols = <String>[];
    final unseenCols = <String>[];
    var offset = 0;

    for (final col in spec.numericCols) {
      final stats = spec.numeric[col]!;
      final rawVal = _coerceValue(col, inputs[col], validate: validate);
      final double usedVal;
      final bool imputed;
      if (rawVal == null) {
        usedVal = stats.median;
        imputed = true;
        imputedCols.add(col);
      } else {
        if (validate && kNumericBounds.containsKey(col)) {
          final bounds = kNumericBounds[col]!;
          if (rawVal < bounds.min || rawVal > bounds.max) {
            throw HeartValidationException(
              "Input '$col'=$rawVal is outside [${bounds.min}, ${bounds.max}].",
            );
          }
        }
        usedVal = rawVal;
        imputed = false;
      }

      final standardized = (usedVal - stats.mean) / stats.scale;
      final deltaZ = spec.coef[offset] * standardized;
      contributions.add(
        FeatureContribution(
          feature: col,
          kind: 'numeric',
          rawValue: rawVal,
          usedValue: usedVal,
          deltaZ: deltaZ,
          imputed: imputed,
          unseen: false,
          outputFeature: spec.outputFeatures[offset],
        ),
      );
      offset += 1;
    }

    for (final col in spec.categoricalCols) {
      final cat = spec.categorical[col]!;
      final rawVal = _coerceValue(col, inputs[col], validate: validate);
      final double usedVal;
      final bool imputed;
      if (rawVal == null) {
        usedVal = cat.mode;
        imputed = true;
        imputedCols.add(col);
      } else {
        usedVal = rawVal;
        imputed = false;
      }

      int? matchedIdx;
      for (var i = 0; i < cat.categories.length; i++) {
        if (usedVal == cat.categories[i]) {
          matchedIdx = i;
          break;
        }
      }

      final double deltaZ;
      final String? outFeature;
      final bool unseen;
      if (matchedIdx != null) {
        deltaZ = spec.coef[offset + matchedIdx];
        outFeature = spec.outputFeatures[offset + matchedIdx];
        unseen = false;
      } else {
        if (validate && rawVal != null) {
          throw HeartValidationException(
            "Input '$col'=$rawVal is invalid for mode '$activeMode'; "
            'allowed values: ${cat.categories}.',
          );
        }
        deltaZ = 0.0;
        outFeature = null;
        unseen = true;
        unseenCols.add(col);
      }

      contributions.add(
        FeatureContribution(
          feature: col,
          kind: 'categorical',
          rawValue: rawVal,
          usedValue: usedVal,
          deltaZ: deltaZ,
          imputed: imputed,
          unseen: unseen,
          outputFeature: outFeature,
        ),
      );
      offset += cat.categories.length;
    }

    var z = spec.intercept;
    for (final c in contributions) {
      z += c.deltaZ;
    }
    final prob = stableSigmoid(z);

    return PredictionResult(
      mode: activeMode,
      requestedMode: mode,
      probability: prob,
      probabilityAbsent: 1.0 - prob,
      predClass: prob >= 0.5 ? 1 : 0,
      riskBand: classifyRiskBand(
        prob,
        lowMax: lowMax,
        moderateMax: moderateMax,
      ),
      z: z,
      intercept: spec.intercept,
      contributions: List<FeatureContribution>.unmodifiable(contributions),
      imputedCols: List<String>.unmodifiable(imputedCols),
      unseenCols: List<String>.unmodifiable(unseenCols),
    );
  }
}
