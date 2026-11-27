// lab_info_tab.dart
//
// Lab & Info Tab: BioVanta V2.0 identity, theme & language controls,
// dynamic Internal Cleveland 10x5 CV + External UCI Validation tables,
// offline privacy guarantee, and UCI attribution.

import 'package:flutter/material.dart';

import '../heart_model.dart';
import '../l10n/strings.dart';
import 'theme.dart';

class LabInfoTab extends StatelessWidget {
  const LabInfoTab({
    super.key,
    required this.model,
    required this.bottomDockPadding,
  });

  final HeartModel model;
  final double bottomDockPadding;

  String _cohortTitle(AppStrings s, ExternalCohortMetrics c) {
    switch (c.key) {
      case 'hungarian':
        return s.s('cohortHungarian');
      case 'switzerland':
        return s.s('cohortSwitzerland');
      case 'va':
        return s.s('cohortVa');
      case 'pooled_external':
        return s.s('cohortPooled');
      default:
        return c.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final ext = model.externalValidation;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomDockPadding),
      children: [
        // 1. Identity Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.borderAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.s('labTitle'),
                      style: tabularStyle(
                        theme.textTheme.titleLarge,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                        monospace: true,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: pal.cyan.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: pal.cyan.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      s.s('appVersion'),
                      style: tabularStyle(
                        theme.textTheme.labelMedium,
                        color: pal.cyan,
                        fontWeight: FontWeight.w800,
                        monospace: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.s('labTagline'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pal.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Theme & Language Preferences
        ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeModeNotifier,
          builder: (context, mode, _) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.s('themeLabel'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('chip_theme_dark'),
                        avatar: const Icon(Icons.dark_mode_outlined, size: 15),
                        label: Text(s.s('themeDark')),
                        selected: mode == ThemeMode.dark,
                        onSelected: (_) =>
                            appThemeModeNotifier.value = ThemeMode.dark,
                      ),
                      ChoiceChip(
                        key: const ValueKey('chip_theme_light'),
                        avatar: const Icon(Icons.light_mode_outlined, size: 15),
                        label: Text(s.s('themeLight')),
                        selected: mode == ThemeMode.light,
                        onSelected: (_) =>
                            appThemeModeNotifier.value = ThemeMode.light,
                      ),
                      ChoiceChip(
                        key: const ValueKey('chip_theme_system'),
                        avatar: const Icon(
                          Icons.settings_brightness_outlined,
                          size: 15,
                        ),
                        label: Text(s.s('themeSystem')),
                        selected: mode == ThemeMode.system,
                        onSelected: (_) =>
                            appThemeModeNotifier.value = ThemeMode.system,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: pal.border),
                  const SizedBox(height: 12),
                  Text(
                    s.s('languageSectionLabel'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('chip_lang_en'),
                        label: const Text('English'),
                        selected: !s.isFa,
                        onSelected: (_) =>
                            appLocaleNotifier.value = const Locale('en'),
                      ),
                      ChoiceChip(
                        key: const ValueKey('chip_lang_fa'),
                        label: const Text('فارسی'),
                        selected: s.isFa,
                        onSelected: (_) =>
                            appLocaleNotifier.value = const Locale('fa'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. Single Source of Truth Card
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.s('labArchTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.s('labArchBody'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Internal Cleveland Validation (dynamically read from model.json)
        Container(
          key: const ValueKey('lab_internal_card'),
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
                s.s('labInternalTitle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.s('labFoldRangeNote'),
                style: theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
              ),
              const SizedBox(height: 12),
              _InternalModeBlock(
                title: s.s('modeBadgeFull'),
                spec: model.full13,
                strings: s,
              ),
              const SizedBox(height: 12),
              _InternalModeBlock(
                title: s.s('modeBadgeNi'),
                spec: model.nonInvasive11,
                strings: s,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. External UCI Validation (dynamically read from model.json)
        if (ext != null)
          Container(
            key: const ValueKey('lab_external_card'),
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
                  s.s('labExternalTitle'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final key in const [
                  'hungarian',
                  'switzerland',
                  'va',
                  'pooled_external',
                ])
                  if (ext.cohorts.containsKey(key)) ...[
                    _ExternalCohortTile(
                      title: _cohortTitle(s, ext.cohorts[key]!),
                      cohort: ext.cohorts[key]!,
                      strings: s,
                    ),
                    if (key != 'pooled_external') const SizedBox(height: 8),
                  ],
                const SizedBox(height: 10),
                Text(
                  s.s('labExternalNote'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pal.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // 6. Offline Privacy & Attribution
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 18, color: pal.lowRisk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.s('labOfflineTitle'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.s('labOfflineBody'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.s('labAttribution'),
                style: theme.textTheme.labelSmall?.copyWith(color: pal.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                s.s('disclaimer'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pal.moderateRisk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InternalModeBlock extends StatelessWidget {
  const _InternalModeBlock({
    required this.title,
    required this.spec,
    required this.strings,
  });

  final String title;
  final LinearModeSpec spec;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final meta = spec.metadata;
    if (meta == null) return const SizedBox.shrink();

    final rep = meta.cv10x5Repeated;
    final t61 = meta.test61;

    String fmtCv(MetricSummary m) =>
        '${m.mean.toStringAsFixed(3)} ± ${m.std.toStringAsFixed(3)} '
        '[${m.foldRange95[0].toStringAsFixed(3)}, ${m.foldRange95[1].toStringAsFixed(3)}]';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: pal.cyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.sf('labTrainCvFmt', {
              'mean': meta.cv5FoldTrainAuc.toStringAsFixed(4),
              'std': meta.cv5FoldTrainStd.toStringAsFixed(4),
              'c': meta.c.toString(),
              'dims': '${spec.coef.length}',
            }),
            style: tabularStyle(
              theme.textTheme.labelSmall,
              color: pal.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _MetricRow('ROC-AUC', fmtCv(rep.rocAuc), t61.rocAuc.toStringAsFixed(4), strings),
          _MetricRow('PR-AUC', fmtCv(rep.prAuc), t61.prAuc.toStringAsFixed(4), strings),
          _MetricRow('Brier', fmtCv(rep.brier), t61.brier.toStringAsFixed(4), strings),
          _MetricRow('10-Bin ECE', fmtCv(rep.ece10Bin), t61.ece10Bin.toStringAsFixed(4), strings),
          _MetricRow('Log-Loss', fmtCv(rep.logLoss), t61.logLoss.toStringAsFixed(4), strings),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.name, this.cvText, this.testText, this.strings);

  final String name;
  final String cvText;
  final String testText;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: pal.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${strings.s('labRepCvCol')}: $cvText\n${strings.s('labTest61Col')}: $testText',
                style: tabularStyle(
                  theme.textTheme.labelSmall,
                  color: pal.textMuted,
                  monospace: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalCohortTile extends StatelessWidget {
  const _ExternalCohortTile({
    required this.title,
    required this.cohort,
    required this.strings,
  });

  final String title;
  final ExternalCohortMetrics cohort;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    final prevPct = '${(cohort.prevalence * 100).toStringAsFixed(1)}%';
    final raw = cohort.raw;
    final clean = cohort.impossibleZerosAsNan;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: pal.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  'N=${cohort.n} ($prevPct)',
                  style: tabularStyle(
                    theme.textTheme.labelSmall,
                    color: pal.cyan,
                    fontWeight: FontWeight.w700,
                    monospace: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${strings.s('labRawAucEceCol')}: ${raw.rocAuc.toStringAsFixed(4)} / ${raw.ece10Bin.toStringAsFixed(4)}\n'
              '${strings.s('labCleanAucEceCol')}: ${clean.rocAuc.toStringAsFixed(4)} / ${clean.ece10Bin.toStringAsFixed(4)}\n'
              '${strings.s('labPredObsCol')}: ${clean.meanPredProb.toStringAsFixed(3)} / ${cohort.prevalence.toStringAsFixed(3)}',
              style: tabularStyle(
                theme.textTheme.labelSmall,
                color: pal.textMuted,
                monospace: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
