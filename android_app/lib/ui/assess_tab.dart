// assess_tab.dart
//
// Assess Tab: BioVanta header, live probability gauge, auto-route safety banner,
// horizontal preset deck, dual-mode toggle, and grouped clinical input cards.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../heart_model.dart';
import '../input_parsing.dart';
import '../l10n/strings.dart';
import '../presets.dart';
import 'heart_controller.dart';
import 'theme.dart';
import 'widgets/probability_gauge.dart';

class AssessTab extends StatelessWidget {
  const AssessTab({
    super.key,
    required this.controller,
    required this.bottomDockPadding,
  });

  final HeartController controller;
  final double bottomDockPadding;

  void _toggleTheme() {
    final cur = appThemeModeNotifier.value;
    appThemeModeNotifier.value =
        cur == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void _toggleLocale() {
    final cur = appLocaleNotifier.value.languageCode;
    appLocaleNotifier.value =
        cur == 'fa' ? const Locale('en') : const Locale('fa');
  }

  String _bandText(AppStrings s, RiskBand band) {
    switch (band) {
      case RiskBand.low:
        return s.s('bandLower');
      case RiskBand.moderate:
        return s.s('bandModerate');
      case RiskBand.high:
        return s.s('bandHigher');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final model = controller.model!;
    final result = controller.result;
    final kbStr = (model.sourceBytes / 1024).toStringAsFixed(1);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomDockPadding),
      children: [
        // 1. BioVanta Instrument Header
        _HeaderBar(
          palette: pal,
          strings: s,
          onToggleTheme: _toggleTheme,
          onToggleLocale: _toggleLocale,
        ),
        const SizedBox(height: 12),

        // 2. Permanent Offline Educational Disclaimer
        Container(
          key: const ValueKey('disclaimer_card'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: pal.moderateRisk.withValues(alpha: pal.isDark ? 0.12 : 0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pal.moderateRisk.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: pal.moderateRisk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.s('disclaimer'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Hero Live Probability & Telemetry Card
        if (result != null)
          Container(
            key: const ValueKey('hero_result_card'),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pal.borderAccent),
              boxShadow: pal.isDark
                  ? [
                      BoxShadow(
                        color: pal.cyan.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProbabilityGauge(
                        probability: result.probability,
                        lowMax: model.lowMax,
                        moderateMax: model.moderateMax,
                        riskBand: result.riskBand,
                        size: 124,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.s('estimatedProbability'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: pal.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _PillBadge(
                                  label: _bandText(s, result.riskBand),
                                  color: pal.colorForBand(result.riskBand),
                                  dot: true,
                                ),
                                _PillBadge(
                                  label: result.mode == kModeFull13
                                      ? s.s('modeBadgeFull')
                                      : s.s('modeBadgeNi'),
                                  color: pal.cyan,
                                ),
                              ],
                            ),
                            if (controller.hasErrors) ...[
                              const SizedBox(height: 8),
                              Text(
                                s.s('fixValidationPrompt'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: pal.highRisk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    s.s('bandNote'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.textMuted,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: pal.elevated.withValues(alpha: 0.72),
                    border: Border(top: BorderSide(color: pal.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: pal.lowRisk),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.sf('telemetryFmt', {'kb': kbStr}),
                          style: tabularStyle(
                            theme.textTheme.labelSmall,
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 4. Clinical Safety Auto-Routing Banner
        if (controller.isAutoRouted) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('banner_auto_route'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.cyan.withValues(alpha: pal.isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pal.cyan.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_outlined,
                    size: 19, color: pal.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.s('autoRouteBanner'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 5. Horizontal Swipeable Clinical Presets Deck
        Text(
          s.s('presetsHeading'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: pal.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          s.s('presetsHint'),
          style: theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = math.min(
              224.0,
              math.max(182.0, constraints.maxWidth * 0.60),
            );
            return SizedBox(
              key: const ValueKey('preset_deck'),
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kClinicalPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final preset = kClinicalPresets[idx];
                  final selected = controller.activePresetId == preset.id;
                  final accent = pal.colorForBand(preset.expectedBand);
                  return SizedBox(
                    width: cardWidth,
                    child: Material(
                      color: selected
                          ? accent.withValues(alpha: pal.isDark ? 0.15 : 0.10)
                          : pal.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('preset_${preset.id}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.applyPreset(preset);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? accent : pal.border,
                              width: selected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      s.s(preset.labelKey),
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: pal.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                s.s(preset.subtitleKey),
                                style: tabularStyle(
                                  theme.textTheme.labelSmall,
                                  color: pal.textMuted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // 6. Mode Selector (Full Clinical 13 vs Non-Invasive 11)
        Text(
          s.s('modeLabel'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: pal.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              _ModeSegment(
                key: const ValueKey('mode_full_13'),
                label: s.s('modeFull13'),
                selected: controller.modeChoice == kModeFull13,
                onTap: () => controller.setModeChoice(kModeFull13),
              ),
              const SizedBox(width: 4),
              _ModeSegment(
                key: const ValueKey('mode_non_invasive_11'),
                label: s.s('modeNonInvasive11'),
                selected: controller.modeChoice == kModeNonInvasive11,
                onTap: () => controller.setModeChoice(kModeNonInvasive11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 7. Grouped Clinical Input Cards
        _InputGroupCard(
          title: s.s('groupDemographics'),
          icon: Icons.person_outline,
          children: [
            _numberField(
              context,
              s,
              pal,
              col: 'age',
              ctrl: controller.ageCtrl,
              isInteger: true,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'sex',
              options: kSexOptions,
              value: controller.sex,
              onChanged: controller.setSex,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'cp',
              options: kCpOptions,
              value: controller.cp,
              onChanged: controller.setCp,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _InputGroupCard(
          title: s.s('groupVitalsLabs'),
          icon: Icons.bloodtype_outlined,
          children: [
            _numberField(
              context,
              s,
              pal,
              col: 'trestbps',
              ctrl: controller.trestbpsCtrl,
              isInteger: true,
            ),
            const SizedBox(height: 12),
            _numberField(
              context,
              s,
              pal,
              col: 'chol',
              ctrl: controller.cholCtrl,
              isInteger: true,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'fbs',
              options: kFbsOptions,
              value: controller.fbs,
              onChanged: controller.setFbs,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'restecg',
              options: kRestecgOptions,
              value: controller.restecg,
              onChanged: controller.setRestecg,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _InputGroupCard(
          title: s.s('groupStressTest'),
          icon: Icons.monitor_heart_outlined,
          children: [
            _numberField(
              context,
              s,
              pal,
              col: 'thalach',
              ctrl: controller.thalachCtrl,
              isInteger: true,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'exang',
              options: kExangOptions,
              value: controller.exang,
              onChanged: controller.setExang,
            ),
            const SizedBox(height: 12),
            _numberField(
              context,
              s,
              pal,
              col: 'oldpeak',
              ctrl: controller.oldpeakCtrl,
              isInteger: false,
            ),
            const SizedBox(height: 12),
            _codeDropdown(
              context,
              s,
              pal,
              col: 'slope',
              options: kSlopeOptions,
              value: controller.slope,
              onChanged: controller.setSlope,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _InputGroupCard(
          title: s.s('groupSpecializedTests'),
          icon: Icons.biotech_outlined,
          children: controller.modeChoice == kModeFull13
              ? [
                  _nullableCaDropdown(context, s, pal),
                  const SizedBox(height: 12),
                  _nullableThalDropdown(context, s, pal),
                ]
              : [
                  Container(
                    key: const ValueKey('non_invasive_omitted_note'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_moon_outlined,
                            size: 18, color: pal.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.s('nonInvasiveOmitted'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _numberField(
    BuildContext context,
    AppStrings s,
    BioVantaPalette pal, {
    required String col,
    required TextEditingController ctrl,
    required bool isInteger,
  }) {
    final bounds = kNumericBounds[col]!;
    final issue = controller.fieldErrors[col];
    return TextField(
      key: ValueKey('field_$col'),
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      inputFormatters: [FilteringTextInputFormatter.allow(kDigitsAnyScript)],
      style: tabularStyle(
        Theme.of(context).textTheme.bodyLarge,
        color: pal.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: s.s(col),
        helperText: s.sf('rangeHelper', {
          'min': bounds.min.toStringAsFixed(0),
          'max': bounds.max.toStringAsFixed(0),
        }),
        errorText: issue == null ? null : controller.formatIssue(s, issue),
      ),
    );
  }

  Widget _codeDropdown(
    BuildContext context,
    AppStrings s,
    BioVantaPalette pal, {
    required String col,
    required List<({String key, double code})> options,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final effective =
        options.any((o) => o.code == value) ? value : options.first.code;
    return InputDecorator(
      decoration: InputDecoration(labelText: s.s(col)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          key: ValueKey('field_$col'),
          value: effective,
          isExpanded: true,
          isDense: true,
          dropdownColor: pal.elevated,
          items: options
              .map(
                (o) => DropdownMenuItem<double>(
                  value: o.code,
                  child: Text(
                    s.s(o.key),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _nullableCaDropdown(
    BuildContext context,
    AppStrings s,
    BioVantaPalette pal,
  ) {
    final current = controller.ca;
    return InputDecorator(
      decoration: InputDecoration(labelText: s.s('ca')),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double?>(
          key: const ValueKey('field_ca'),
          value: kCaOptions.contains(current) ? current : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: pal.elevated,
          items: kCaOptions
              .map(
                (v) => DropdownMenuItem<double?>(
                  value: v,
                  child: Text(
                    v == null ? s.s('unknownOption') : v.toStringAsFixed(0),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: controller.setCa,
        ),
      ),
    );
  }

  Widget _nullableThalDropdown(
    BuildContext context,
    AppStrings s,
    BioVantaPalette pal,
  ) {
    final current = controller.thal;
    return InputDecorator(
      decoration: InputDecoration(labelText: s.s('thal')),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double?>(
          key: const ValueKey('field_thal'),
          value: kThalOptions.any((o) => o.code == current) ? current : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: pal.elevated,
          items: kThalOptions
              .map(
                (o) => DropdownMenuItem<double?>(
                  value: o.code,
                  child: Text(
                    s.s(o.key),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: controller.setThal,
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.palette,
    required this.strings,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });

  final BioVantaPalette palette;
  final AppStrings strings;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.borderAccent),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: palette.lowRisk,
              shape: BoxShape.circle,
              boxShadow: palette.isDark
                  ? [
                      BoxShadow(
                        color: palette.lowRisk.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  strings.s('brandName'),
                  style: tabularStyle(
                    theme.textTheme.labelLarge,
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    monospace: true,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: palette.cyan.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    strings.s('appVersion'),
                    style: tabularStyle(
                      theme.textTheme.labelSmall,
                      color: palette.cyan,
                      fontWeight: FontWeight.w700,
                      monospace: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('btn_theme_toggle'),
            tooltip: strings.s('themeTooltip'),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: palette.elevated,
              foregroundColor: palette.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: palette.border),
              ),
            ),
            icon: Icon(
              palette.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            onPressed: onToggleTheme,
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: strings.s('languageTooltip'),
            child: InkWell(
              key: const ValueKey('btn_lang_toggle'),
              onTap: onToggleLocale,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate, size: 15, color: palette.cyan),
                    const SizedBox(width: 4),
                    Text(
                      strings.s('languageToggle'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.color,
    this.dot = false,
  });

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? pal.cyan.withValues(alpha: pal.isDark ? 0.18 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: pal.cyan.withValues(alpha: 0.45))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? pal.cyan : pal.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputGroupCard extends StatelessWidget {
  const _InputGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 17, color: pal.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
