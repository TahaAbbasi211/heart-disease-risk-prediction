// widget_test.dart
//
// End-to-end UI smoke & layout tests for BIOVANTA · HEART V2.0.0:
//   * Obsidian Dark <-> Clinical Paper Light toggle
//   * 4 clinical presets + dual-mode toggle + unknown ca/thal auto-routing banner
//   * Explain tab (equation, Δz chart, What-If sensitivity, collinearity caveat)
//   * Lab & Info tab (dynamic 10x5 CV + external UCI validation tables)
//   * 360x640 at 1.3x text scale overflow checks in EN and FA across all 3 tabs

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/heart_model.dart';
import 'package:heart_risk_offline/l10n/strings.dart';
import 'package:heart_risk_offline/main.dart';
import 'package:heart_risk_offline/ui/theme.dart';

void main() {
  late HeartModel model;

  setUpAll(() {
    model = HeartModel.fromJsonString(
      File('assets/model.json').readAsStringSync(),
    );
  });

  tearDown(() {
    appLocaleNotifier.value = const Locale('en');
    appThemeModeNotifier.value = ThemeMode.dark;
  });

  testWidgets('theme toggle switches Obsidian Dark <-> Clinical Paper Light',
      (tester) async {
    await tester.pumpWidget(HeartRiskApp(model: model));
    await tester.pumpAndSettle();

    var pal = BioVantaPalette.of(
      tester.element(find.byKey(const ValueKey('hero_result_card'))),
    );
    expect(pal.isDark, isTrue);

    await tester.tap(find.byKey(const ValueKey('btn_theme_toggle')));
    await tester.pumpAndSettle();

    pal = BioVantaPalette.of(
      tester.element(find.byKey(const ValueKey('hero_result_card'))),
    );
    expect(pal.isDark, isFalse);
  });

  testWidgets('presets, dual-mode switch, and unknown ca/thal auto-routing work cleanly',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(HeartRiskApp(model: model));
    await tester.pumpAndSettle();

    // Default Male 55 -> 5.6%, Full 13
    expect(find.text('5.6%'), findsOneWidget);
    expect(find.byKey(const ValueKey('banner_auto_route')), findsNothing);

    // Preset: High-risk Non-Invasive 11 -> 94.5%, Non-Invasive 11 mode
    final deckScrollable = find.descendant(
      of: find.byKey(const ValueKey('preset_deck')),
      matching: find.byType(Scrollable),
    );
    Future<void> scrollDeckTo(Finder target) async {
      for (var i = 0; i < 12; i++) {
        if (target.evaluate().isNotEmpty) {
          final cx = tester.getRect(target).center.dx;
          if (cx >= 32 && cx <= 398) return;
          await tester.drag(deckScrollable, Offset(cx < 32 ? 220.0 : -220.0, 0));
        } else {
          await tester.drag(deckScrollable, const Offset(-220.0, 0));
        }
        await tester.pumpAndSettle();
      }
    }

    final highNiPreset =
        find.byKey(const ValueKey('preset_high_risk_non_invasive'));
    await scrollDeckTo(highNiPreset);
    await tester.tap(highNiPreset);
    await tester.pumpAndSettle();
    expect(find.text('94.5%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('non_invasive_omitted_note')),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('non_invasive_omitted_note')),
      findsOneWidget,
    );

    // Scroll back to the very top so both hero_result_card and preset_deck are mounted
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('disclaimer_card')),
      -300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Preset: High-risk Full 13 -> 99.7%
    final highFullPreset = find.byKey(const ValueKey('preset_high_risk_full'));
    await scrollDeckTo(highFullPreset);
    await tester.tap(highFullPreset);
    await tester.pumpAndSettle();
    expect(find.text('99.7%'), findsOneWidget);

    // Set ca = Not tested / Unknown in Full Clinical mode -> auto-route banner
    final caFinder = find.byKey(const ValueKey('field_ca'));
    await tester.scrollUntilVisible(
      caFinder,
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(caFinder);
    await tester.pumpAndSettle();
    await tester.tap(caFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not tested / Unknown').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('disclaimer_card')),
      -350.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('banner_auto_route')), findsOneWidget);
    expect(find.text('Non-Invasive 11'), findsOneWidget);
  });

  testWidgets('Explain and Lab & Info tabs render dynamic content in EN and FA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(HeartRiskApp(model: model));
    await tester.pumpAndSettle();

    // Switch to Explain tab
    await tester.tap(find.byKey(const ValueKey('nav_explain')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('explain_equation_card')), findsOneWidget);
    expect(find.textContaining('intercept (-'), findsOneWidget);
    expect(find.byKey(const ValueKey('explain_chart_card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('explain_what_if_card')),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('explain_what_if_card')), findsOneWidget);

    // Switch to Lab & Info tab
    await tester.tap(find.byKey(const ValueKey('nav_lab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lab_internal_card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('0.914 ± 0.032 [0.847, 0.964]'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('0.914 ± 0.032 [0.847, 0.964]'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lab_external_card')),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('lab_external_card')), findsOneWidget);
    expect(find.text('Hungarian'), findsOneWidget);

    // Switch language inside Lab & Info tab to Persian
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chip_lang_fa')),
      -300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chip_lang_fa')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('مجارستان'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('مجارستان'), findsOneWidget);
    expect(find.text('سوئیس'), findsOneWidget);
  });

  testWidgets('zero layout overflow at 360x640 dp with textScale 1.3 across EN & FA',
      (tester) async {
    Future<void> verifyNoOverflow(String lang) async {
      appLocaleNotifier.value = Locale(lang);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: HeartRiskApp(model: model),
        ),
      );
      await tester.pumpAndSettle();

      for (final navKey in const ['nav_explain', 'nav_lab', 'nav_assess']) {
        await tester.tap(find.byKey(ValueKey(navKey)));
        await tester.pumpAndSettle();
      }
    }

    await verifyNoOverflow('en');
    await verifyNoOverflow('fa');
  });
}
