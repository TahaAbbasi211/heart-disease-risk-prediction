// delta_z_chart.dart
//
// Custom-painted diverging horizontal Δz contribution bar chart (zero chart plugins).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../heart_model.dart';
import '../../l10n/strings.dart';
import '../heart_controller.dart';
import '../theme.dart';

class DeltaZChart extends StatelessWidget {
  const DeltaZChart({
    super.key,
    required this.contributions,
    required this.controller,
  });

  final List<FeatureContribution> contributions;
  final HeartController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);

    final sorted = List<FeatureContribution>.from(contributions)
      ..sort((a, b) => b.deltaZ.abs().compareTo(a.deltaZ.abs()));

    var maxAbs = 0.25;
    for (final c in sorted) {
      maxAbs = math.max(maxAbs, c.deltaZ.abs());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scale & color legend
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: pal.highRisk, label: s.s('dirRisk')),
            _LegendDot(color: pal.lowRisk, label: s.s('dirProtective')),
          ],
        ),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '-${maxAbs.toStringAsFixed(2)}',
                style: tabularStyle(
                  theme.textTheme.labelSmall,
                  color: pal.lowRisk,
                  monospace: true,
                ),
              ),
              Text(
                '0.00',
                style: tabularStyle(
                  theme.textTheme.labelSmall,
                  color: pal.textMuted,
                  monospace: true,
                ),
              ),
              Text(
                '+${maxAbs.toStringAsFixed(2)}',
                style: tabularStyle(
                  theme.textTheme.labelSmall,
                  color: pal.highRisk,
                  monospace: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < sorted.length; i++) ...[
          _DeltaZRow(
            contribution: sorted[i],
            formattedValue:
                controller.formatContributionValue(s, sorted[i]),
            featureLabel: s.featureLabel(sorted[i].feature),
            maxAbs: maxAbs,
          ),
          if (i < sorted.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: pal.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DeltaZRow extends StatelessWidget {
  const _DeltaZRow({
    required this.contribution,
    required this.formattedValue,
    required this.featureLabel,
    required this.maxAbs,
  });

  final FeatureContribution contribution;
  final String formattedValue;
  final String featureLabel;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final dz = contribution.deltaZ;
    final Color barColor;
    if (dz > 1e-12) {
      barColor = pal.highRisk;
    } else if (dz < -1e-12) {
      barColor = pal.lowRisk;
    } else {
      barColor = pal.neutral;
    }
    final sign = dz >= 0 ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                '$featureLabel · $formattedValue',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$sign${dz.toStringAsFixed(3)}',
                style: tabularStyle(
                  theme.textTheme.labelMedium,
                  color: barColor,
                  fontWeight: FontWeight.w700,
                  monospace: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 11,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(
              painter: _DivergingBarPainter(
                deltaZ: dz,
                maxAbs: maxAbs,
                barColor: barColor,
                palette: pal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DivergingBarPainter extends CustomPainter {
  const _DivergingBarPainter({
    required this.deltaZ,
    required this.maxAbs,
    required this.barColor,
    required this.palette,
  });

  final double deltaZ;
  final double maxAbs;
  final Color barColor;
  final BioVantaPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(5),
    );
    canvas.drawRRect(bgRect, Paint()..color = palette.elevated);

    final midX = size.width / 2;
    final frac = (deltaZ / maxAbs).clamp(-1.0, 1.0);
    final barWidth = (frac.abs() * (size.width / 2 - 4)).clamp(0.0, size.width / 2 - 4);

    if (barWidth > 0.5) {
      final left = frac >= 0 ? midX : midX - barWidth;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 1.5, barWidth, size.height - 3.0),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, Paint()..color = barColor);
    }

    canvas.drawLine(
      Offset(midX, 0),
      Offset(midX, size.height),
      Paint()
        ..color = palette.borderAccent
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _DivergingBarPainter oldDelegate) {
    return oldDelegate.deltaZ != deltaZ ||
        oldDelegate.maxAbs != maxAbs ||
        oldDelegate.barColor != barColor ||
        oldDelegate.palette != palette;
  }
}
