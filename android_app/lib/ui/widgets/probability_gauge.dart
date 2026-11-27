// probability_gauge.dart
//
// Custom-painted 240-degree clinical probability gauge reading thresholds from model.json.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../heart_model.dart';
import '../theme.dart';

class ProbabilityGauge extends StatelessWidget {
  const ProbabilityGauge({
    super.key,
    required this.probability,
    required this.lowMax,
    required this.moderateMax,
    required this.riskBand,
    this.size = 132,
  });

  final double probability;
  final double lowMax;
  final double moderateMax;
  final RiskBand riskBand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final bandColor = pal.colorForBand(riskBand);
    final pctText = '${(probability * 100).toStringAsFixed(1)}%';

    return SizedBox(
      width: size,
      height: size * 0.88,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GaugePainter(
                  probability: probability.clamp(0.0, 1.0),
                  lowMax: lowMax,
                  moderateMax: moderateMax,
                  arcColor: bandColor,
                  palette: pal,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                pctText,
                style: tabularStyle(
                  Theme.of(context).textTheme.headlineSmall,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: bandColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.probability,
    required this.lowMax,
    required this.moderateMax,
    required this.arcColor,
    required this.palette,
  });

  final double probability;
  final double lowMax;
  final double moderateMax;
  final Color arcColor;
  final BioVantaPalette palette;

  static const double _startAngle = 5 * math.pi / 6; // 150 deg
  static const double _totalSweep = 4 * math.pi / 3; // 240 deg

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final radius = math.min(size.width, size.height) * 0.43;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = palette.elevated;
    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.borderAccent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 7.5),
      _startAngle,
      _totalSweep,
      false,
      rimPaint,
    );

    // Threshold tick marks at lowMax and moderateMax read from model.json
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = palette.textMuted.withValues(alpha: 0.7);
    for (final thresh in <double>[lowMax, moderateMax]) {
      final angle = _startAngle + thresh.clamp(0.0, 1.0) * _totalSweep;
      final inner = Offset(
        center.dx + (radius - 7) * math.cos(angle),
        center.dy + (radius - 7) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + (radius + 7) * math.cos(angle),
        center.dy + (radius + 7) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final sweep = (probability * _totalSweep).clamp(0.03, _totalSweep);
    if (palette.isDark) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..color = arcColor.withValues(alpha: 0.24);
      canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);
    }

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(rect, _startAngle, sweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.probability != probability ||
        oldDelegate.lowMax != lowMax ||
        oldDelegate.moderateMax != moderateMax ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.palette != palette;
  }
}
