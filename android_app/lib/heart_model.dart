// heart_model.dart
//
// This file contains ALL the "machine learning" of the app.
// There is no ML library here: the exported Logistic Regression is just
// arithmetic, so we re-implement it in about 40 lines.
//
// The whole prediction is:
//
//     z    = intercept + coef[0]*x[0] + coef[1]*x[1] + ... + coef[n]*x[n]
//     prob = 1 / (1 + exp(-z))          <-- the sigmoid function
//
// where x is built from the raw form values in two steps:
//   1. numeric columns: fill missing with the median, then standardize
//   2. categorical columns: fill missing with the mode, then one-hot encode
//
// Every number (medians, means, scales, modes, categories, coefficients)
// comes from assets/model.json, which was produced by
// mobile_export/export_model.py in the Python project.

import 'dart:convert';
import 'dart:math' as math;

/// Statistics for one numeric feature (age, chol, ...).
class NumericStats {
  final double median; // used when the value is missing
  final double mean; // used by the scaler
  final double scale; // used by the scaler

  NumericStats({required this.median, required this.mean, required this.scale});

  factory NumericStats.fromJson(Map<String, dynamic> json) => NumericStats(
        median: (json['median'] as num).toDouble(),
        mean: (json['mean'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
      );
}

/// Statistics for one categorical feature (sex, cp, ...).
class CategoricalStats {
  final double mode; // used when the value is missing
  final List<double> categories; // the one-hot order, exactly as trained

  CategoricalStats({required this.mode, required this.categories});

  factory CategoricalStats.fromJson(Map<String, dynamic> json) =>
      CategoricalStats(
        mode: (json['mode'] as num).toDouble(),
        categories: (json['categories'] as List)
            .map((c) => (c as num).toDouble())
            .toList(),
      );
}

/// The exported logistic-regression model.
class HeartModel {
  final List<String> numericCols;
  final List<String> categoricalCols;
  final Map<String, NumericStats> numeric;
  final Map<String, CategoricalStats> categorical;
  final List<double> coef;
  final double intercept;

  HeartModel({
    required this.numericCols,
    required this.categoricalCols,
    required this.numeric,
    required this.categorical,
    required this.coef,
    required this.intercept,
  });

  /// Build the model from the text of assets/model.json.
  factory HeartModel.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;

    final numeric = <String, NumericStats>{};
    (json['numeric'] as Map<String, dynamic>).forEach((key, value) {
      numeric[key] = NumericStats.fromJson(value as Map<String, dynamic>);
    });

    final categorical = <String, CategoricalStats>{};
    (json['categorical'] as Map<String, dynamic>).forEach((key, value) {
      categorical[key] =
          CategoricalStats.fromJson(value as Map<String, dynamic>);
    });

    return HeartModel(
      numericCols: (json['numeric_cols'] as List).cast<String>(),
      categoricalCols: (json['categorical_cols'] as List).cast<String>(),
      numeric: numeric,
      categorical: categorical,
      coef: (json['coef'] as List).map((c) => (c as num).toDouble()).toList(),
      intercept: (json['intercept'] as num).toDouble(),
    );
  }

  /// Turn one raw input row into the vector of numbers the model expects.
  ///
  /// A value of `null` means "missing" and gets imputed. A category that is
  /// not in [CategoricalStats.categories] is unknown: it matches nothing, so
  /// its whole one-hot block stays at 0.0 -- exactly what scikit-learn's
  /// OneHotEncoder(handle_unknown="ignore") does.
  List<double> buildFeatureVector(Map<String, double?> input) {
    final x = <double>[];

    // --- numeric block: median impute, then standardize -------------------
    for (final col in numericCols) {
      final stats = numeric[col]!;
      final raw = input[col] ?? stats.median;
      x.add((raw - stats.mean) / stats.scale);
    }

    // --- categorical block: mode impute, then one-hot ---------------------
    for (final col in categoricalCols) {
      final stats = categorical[col]!;
      final raw = input[col] ?? stats.mode;
      for (final category in stats.categories) {
        x.add(raw == category ? 1.0 : 0.0);
      }
    }

    return x;
  }

  /// Probability of the positive class ("disease"), between 0 and 1.
  double predictProbability(Map<String, double?> input) {
    final x = buildFeatureVector(input);

    // z = intercept + w . x
    var z = intercept;
    for (var i = 0; i < x.length; i++) {
      z += coef[i] * x[i];
    }

    // sigmoid(z) = 1 / (1 + e^-z)
    return 1.0 / (1.0 + math.exp(-z));
  }
}
