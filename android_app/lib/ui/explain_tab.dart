// explain_tab.dart
//
// Explain Tab: exact additive equation, diverging Δz contribution bar chart,
// interactive What-If sensitivity sliders, and Cleveland collinearity caveats.

import 'package:flutter/material.dart';

import '../heart_model.dart';
import '../l10n/strings.dart';
import 'heart_controller.dart';
import 'theme.dart';
import 'widgets/delta_z_chart.dart';

class ExplainTab extends StatelessWidget {
  const ExplainTab({
    super.key,
    required this.controller,
    required this.bottomDockPadding,
  });

  final HeartController controller;
  final double bottomDockPadding;

  String _signed(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final res = controller.result;

    if (res == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.s('errorModelLoading')),
        ),
      );
    }

    var dzSum = 0.0;
    for (final c in res.contributions) {
      dzSum += c.deltaZ;
    }

    final whatIf = controller.whatIfResult ?? res;
    final probDelta = (whatIf.probability - res.probability) * 100.0;
    final deltaSign = probDelta >= 0 ? '+' : '';
    final deltaColor = probDelta.abs() < 0.05
        ? pal.textMuted
        : (probDelta > 0 ? pal.highRisk : pal.lowRisk);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomDockPadding),
      children: [
        // 1. Exact Logistic Equation Card
        Container(
          key: const ValueKey('explain_equation_card'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.borderAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.s('equationTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.s('equationFormulaNote'),
                style: theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: pal.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.border),
                  ),
                  child: Text(
                    'intercept (${_signed(res.intercept)}) + '
                    'Σ Δz (${_signed(dzSum)}) = '
                    'z (${_signed(res.z)})\n'
                    'sigmoid(z) = ${res.probability.toStringAsFixed(4)} '
                    '(${(res.probability * 100).toStringAsFixed(1)}%)',
                    style: tabularStyle(
                      theme.textTheme.bodySmall,
                      color: pal.cyan,
                      fontWeight: FontWeight.w700,
                      monospace: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Custom-Painted Diverging Δz Bar Chart
        Container(
          key: const ValueKey('explain_chart_card'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.s('contributionsTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.s('contributionsSubtitle'),
                style:
                    theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
              ),
              const SizedBox(height: 12),
              DeltaZChart(
                contributions: res.contributions,
                controller: controller,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Interactive What-If Sensitivity Explorer
        Container(
          key: const ValueKey('explain_what_if_card'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.s('whatIfTitle'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.s('whatIfSubtitle'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: pal.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('btn_what_if_reset'),
                    onPressed: controller.resetWhatIf,
                    child: Text(s.s('whatIfReset')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatBox(
                    label: s.s('whatIfBaseline'),
                    value: '${(res.probability * 100).toStringAsFixed(1)}%',
                    color: pal.textPrimary,
                  ),
                  _StatBox(
                    label: s.s('whatIfSimulated'),
                    value: '${(whatIf.probability * 100).toStringAsFixed(1)}%',
                    color: pal.colorForBand(whatIf.riskBand),
                  ),
                  _StatBox(
                    label: s.s('whatIfDelta'),
                    value: '$deltaSign${probDelta.toStringAsFixed(1)}%',
                    color: deltaColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _WhatIfSlider(
                label: s.s('trestbps'),
                value: controller.whatIfTrestbps,
                min: kNumericBounds['trestbps']!.min,
                max: kNumericBounds['trestbps']!.max,
                digits: 0,
                onChanged: (v) => controller.updateWhatIf(trestbps: v),
              ),
              _WhatIfSlider(
                label: s.s('chol'),
                value: controller.whatIfChol,
                min: kNumericBounds['chol']!.min,
                max: kNumericBounds['chol']!.max,
                digits: 0,
                onChanged: (v) => controller.updateWhatIf(chol: v),
              ),
              _WhatIfSlider(
                label: s.s('thalach'),
                value: controller.whatIfThalach,
                min: kNumericBounds['thalach']!.min,
                max: kNumericBounds['thalach']!.max,
                digits: 0,
                onChanged: (v) => controller.updateWhatIf(thalach: v),
              ),
              _WhatIfSlider(
                label: s.s('oldpeak'),
                value: controller.whatIfOldpeak,
                min: kNumericBounds['oldpeak']!.min,
                max: kNumericBounds['oldpeak']!.max,
                divisions: 70,
                digits: 1,
                onChanged: (v) => controller.updateWhatIf(oldpeak: v),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => controller.updateWhatIf(
                        maskInvasive: !controller.whatIfMaskInvasive,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          s.s('whatIfInvasiveToggle'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: const ValueKey('switch_what_if_invasive'),
                    value: controller.whatIfMaskInvasive,
                    onChanged: (val) =>
                        controller.updateWhatIf(maskInvasive: val),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Collinearity & Referral Bias Caveat
        Material(
          color: pal.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: pal.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(
                s.s('caveatTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    s.s('caveatBody'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textMuted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: pal.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: tabularStyle(
                theme.textTheme.titleMedium,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatIfSlider extends StatelessWidget {
  const _WhatIfSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.digits,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int digits;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: pal.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value.toStringAsFixed(digits),
                style: tabularStyle(
                  theme.textTheme.labelMedium,
                  color: pal.cyan,
                  fontWeight: FontWeight.w700,
                  monospace: true,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
