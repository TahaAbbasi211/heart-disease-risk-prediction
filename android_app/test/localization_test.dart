// localization_test.dart
//
// Checks that the two string maps stay in step, and drives the REAL app UI in
// both languages with widget tests.
//
// Run with:  flutter test

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/heart_model.dart';
import 'package:heart_risk_offline/main.dart' as app;
import 'package:heart_risk_offline/strings.dart';

/// Wraps the app's real [app.HomePage] in a MaterialApp configured exactly like
/// `HeartRiskApp`, but with the starting language forced.
///
/// The AppBar toggle is the production path; this wrapper is only so a test can
/// *start* in a given language. [model] is injected so no asynchronous asset
/// read is involved (see the note in `main`).
Widget hostApp({
  required String languageCode,
  double textScale = 1.0,
  HeartModel? model,
}) {
  return _Host(
      languageCode: languageCode, textScale: textScale, model: model);
}

class _Host extends StatefulWidget {
  const _Host({
    required this.languageCode,
    required this.textScale,
    this.model,
  });

  final String languageCode;
  final double textScale;
  final HeartModel? model;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Locale _locale = Locale(widget.languageCode);

  @override
  void didUpdateWidget(covariant _Host old) {
    super.didUpdateWidget(old);
    // Pumping hostApp with another language must actually switch it, otherwise
    // the State (and its locale) survives the rebuild.
    if (old.languageCode != widget.languageCode) {
      _locale = Locale(widget.languageCode);
    }
  }

  void _toggle() {
    setState(() {
      _locale = Locale(_locale.languageCode == 'fa' ? 'en' : 'fa');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        return supported.any((l) => l.languageCode == locale.languageCode)
            ? Locale(locale.languageCode)
            : const Locale('en');
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final persian = Localizations.localeOf(context).languageCode == 'fa';
        Widget body = child!;
        if (persian) {
          body = DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Vazirmatn'),
            child: body,
          );
        }
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(widget.textScale)),
          child: body,
        );
      },
      home: app.HomePage(onToggleLanguage: _toggle, model: widget.model),
    );
  }
}

// ---------------------------------------------------------------------------
// Golden-case helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> goldenCase(int index) {
  final golden = jsonDecode(File('test/golden_cases.json').readAsStringSync())
      as Map<String, dynamic>;
  return (golden['cases'] as List)[index] as Map<String, dynamic>;
}

/// The percentage the app should display, formatted exactly like the result
/// card formats it.
String expectedPercent(int index) {
  final p = (goldenCase(index)['probability'] as num).toDouble();
  return '${(p * 100).toStringAsFixed(1)}%';
}

/// Golden cases that the UI can actually reproduce.
///
/// The `thal=5` case (index 14) is deliberately excluded: 5 is an *unseen*
/// category that only exists in the model test, and the form only offers the
/// three trained values (3, 6, 7), so it cannot be entered by hand.
///
/// Index 0 has `thal = null` (imputed to the mode, 3) and index 2 has
/// `ca = null`, so both exercise the "missing value" path. No numeric input is
/// null in either, which matters because the form's defaults are the app.py
/// defaults, not the imputer medians.
const List<int> kUiGoldenCases = [0, 2];

/// Fills the form with one golden case.
///
/// Text fields and dropdowns are found by their stable widget keys
/// (`field_<name>`), so this works in either language.
Future<void> enterGoldenCase(
  WidgetTester tester,
  int index, {
  required bool persian,
  bool persianDigits = false,
}) async {
  final input = goldenCase(index)['input'] as Map<String, dynamic>;
  final s = persian ? kPersianStrings : kEnglishStrings;

  String digits(String latin) {
    if (!persianDigits) return latin;
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return latin.split('').map((ch) {
      final d = int.tryParse(ch);
      return d != null ? fa[d] : ch;
    }).join();
  }

  Future<void> setNumber(String name, Object? value) async {
    if (value == null) return; // imputed by the model; keep the default
    final field = find.byKey(ValueKey('field_$name'));
    expect(field, findsOneWidget, reason: 'no numeric field "$name"');
    await tester.enterText(field, digits((value as num).toString()));
    await tester.pump();
  }

  await setNumber('age', input['age']);
  await setNumber('trestbps', input['trestbps']);
  await setNumber('chol', input['chol']);
  await setNumber('thalach', input['thalach']);
  await setNumber('oldpeak', input['oldpeak']);

  /// Opens the dropdown keyed [name] and taps the entry carrying [code].
  ///
  /// The visible label is computed from the production option lists in
  /// main.dart plus the active language's string map, so the test never
  /// guesses a translation.
  Future<void> setDropdown(
    String name,
    List<({String key, double code})> options,
    Object? code,
  ) async {
    if (code == null) return; // imputed to the mode; the default already is it
    final dropdown = find.byKey(ValueKey('field_$name'));
    expect(dropdown, findsOneWidget, reason: 'no dropdown "$name"');

    final option = options.firstWhere(
      (o) => o.code == (code as num).toDouble(),
      orElse: () => throw StateError('code $code not offered by "$name"'),
    );
    final label = s[option.key]!;

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // The menu shows the label; the closed field also shows the currently
    // selected one, so take the last match (the open menu's entry).
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  await setDropdown('sex', app.kSex, input['sex']);
  await setDropdown('cp', app.kCp, input['cp']);
  await setDropdown('fbs', app.kFbs, input['fbs']);
  await setDropdown('restecg', app.kRestecg, input['restecg']);
  await setDropdown('exang', app.kExang, input['exang']);
  await setDropdown('slope', app.kSlope, input['slope']);
  await setDropdown('thal', app.kThal, input['thal']);

  // `ca` is a plain 0..3 dropdown (no translation of its options).
  final ca = input['ca'];
  if (ca != null) {
    final dropdown = find.byKey(const ValueKey('field_ca'));
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${(ca as num).toInt()}').last);
    await tester.pumpAndSettle();
  }
}

/// Makes the test surface tall enough that the whole form is laid out.
///
/// The screen is a `ListView`, which builds its children lazily: on the default
/// 800x600 surface the lower half of the form simply does not exist, so finders
/// would not see it. Tests that only care about content use this; the
/// overflow tests deliberately keep the real 360x640 phone size instead.
Future<void> useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Taps the Predict button, scrolling it into view first if needed.
///
/// On a short phone surface the button lives below the fold and the ListView
/// has not built it yet, so we scroll the form (not `scrollUntilVisible`, which
/// cannot tell the page's Scrollable apart from the ones inside the dropdowns).
Future<void> tapPredict(WidgetTester tester, {required bool persian}) async {
  final label = persian ? 'پیش‌بینی' : 'Predict';
  final finder = find.text(label);

  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  // The form is driven with a model built from the same asset the app ships.
  // HomePage normally reads that asset itself, but that read is real file I/O:
  // inside a widget test it races `pumpAndSettle`, which can return before the
  // read finishes and leave the screen showing "model is still loading".
  // Passing the model in (see the `model` parameter of HomePage) removes that
  // race and keeps these tests deterministic.
  late HeartModel model;

  setUpAll(() {
    model = HeartModel.fromJsonString(
      File('assets/model.json').readAsStringSync(),
    );
  });

  group('string maps', () {
    test('en and fa have exactly the same keys', () {
      final en = kEnglishStrings.keys.toSet();
      final fa = kPersianStrings.keys.toSet();

      expect(fa.difference(en), isEmpty,
          reason: 'keys present in fa but missing in en');
      expect(en.difference(fa), isEmpty,
          reason: 'keys present in en but missing in fa');
    });

    test('no Persian value is empty', () {
      final empty = kPersianStrings.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(empty, isEmpty, reason: 'empty Persian values: $empty');
    });

    test('no English value is empty either', () {
      final empty = kEnglishStrings.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(empty, isEmpty, reason: 'empty English values: $empty');
    });

    test('the toggle names the other language', () {
      expect(kEnglishStrings['languageToggle'], 'فارسی');
      expect(kPersianStrings['languageToggle'], 'English');
    });

    test('the user-specified translations are used verbatim', () {
      expect(kPersianStrings['appTitle'], 'ریسک بیماری قلبی');
      expect(kPersianStrings['age'], 'سن');
      expect(kPersianStrings['sex'], 'جنسیت');
      expect(kPersianStrings['sexFemale'], 'زن');
      expect(kPersianStrings['sexMale'], 'مرد');
      expect(kPersianStrings['cp'], 'نوع درد قفسه سینه');
      expect(kPersianStrings['cpTypical'], 'آنژین تیپیک');
      expect(kPersianStrings['cpAtypical'], 'آنژین آتیپیک');
      expect(kPersianStrings['cpNonAnginal'], 'درد غیرآنژینی');
      expect(kPersianStrings['cpAsymptomatic'], 'بدون علامت');
      expect(kPersianStrings['trestbps'], 'فشار خون در حالت استراحت (mm Hg)');
      expect(kPersianStrings['chol'], 'کلسترول (mg/dl)');
      expect(kPersianStrings['fbs'], 'قند خون ناشتا');
      expect(kPersianStrings['fbsNo'], 'خیر (≤ 120 mg/dl)');
      expect(kPersianStrings['fbsYes'], 'بله (> 120 mg/dl)');
      expect(kPersianStrings['restecg'], 'نوار قلب در حالت استراحت');
      expect(kPersianStrings['restecgStt'], 'ناهنجاری ST-T');
      expect(kPersianStrings['restecgLvh'], 'هیپرتروفی بطن چپ');
      expect(kPersianStrings['thalach'], 'حداکثر ضربان قلب');
      expect(kPersianStrings['exang'], 'آنژین ناشی از ورزش');
      expect(kPersianStrings['exangNo'], 'خیر');
      expect(kPersianStrings['exangYes'], 'بله');
      expect(kPersianStrings['oldpeak'], 'افت قطعه ST (oldpeak)');
      expect(kPersianStrings['slope'], 'شیب قطعه ST');
      expect(kPersianStrings['slopeUpsloping'], 'صعودی');
      expect(kPersianStrings['slopeFlat'], 'تخت');
      expect(kPersianStrings['slopeDownsloping'], 'نزولی');
      expect(kPersianStrings['ca'], 'تعداد رگ‌های اصلی رنگ‌شده در فلوروسکوپی');
      expect(kPersianStrings['thal'], 'نتیجه‌ی اسکن تالیوم');
      expect(kPersianStrings['thalNormal'], 'طبیعی');
      expect(kPersianStrings['thalFixed'], 'نقص ثابت');
      expect(kPersianStrings['thalReversible'], 'نقص برگشت‌پذیر');
      expect(kPersianStrings['predict'], 'پیش‌بینی');
      expect(kPersianStrings['estimatedProbability'], 'احتمال تخمینی بیماری قلبی');
      expect(kPersianStrings['bandLower'], 'ریسک کمتر');
      expect(kPersianStrings['bandModerate'], 'ریسک متوسط');
      expect(kPersianStrings['bandHigher'], 'ریسک بالاتر');
    });

    test('fill substitutes every placeholder', () {
      final out = AppStrings.fill('{field} between {min} and {max}', {
        'field': 'Age',
        'min': '20',
        'max': '100',
      });
      expect(out, 'Age between 20 and 100');
      expect(out.contains('{'), isFalse);
    });
  });

  group('direction', () {
    testWidgets('Persian renders right-to-left', (tester) async {
      await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(app.HomePage));
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(Localizations.localeOf(ctx).languageCode, 'fa');
    });

    testWidgets('English renders left-to-right', (tester) async {
      await tester.pumpWidget(hostApp(languageCode: 'en', model: model));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(app.HomePage));
      expect(Directionality.of(ctx), TextDirection.ltr);
      expect(Localizations.localeOf(ctx).languageCode, 'en');
    });
  });

  group('the AppBar toggle', () {
    testWidgets('switches language at runtime, both ways', (tester) async {
      await tester.pumpWidget(hostApp(languageCode: 'en', model: model));
      await tester.pumpAndSettle();

      expect(find.text('Heart Disease Risk Prediction'), findsOneWidget);
      expect(find.text('فارسی'), findsOneWidget);

      await tester.tap(find.text('فارسی'));
      await tester.pumpAndSettle();

      var ctx = tester.element(find.byType(app.HomePage));
      expect(Localizations.localeOf(ctx).languageCode, 'fa');
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(find.text('ریسک بیماری قلبی'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      ctx = tester.element(find.byType(app.HomePage));
      expect(Localizations.localeOf(ctx).languageCode, 'en');
      expect(Directionality.of(ctx), TextDirection.ltr);
      expect(find.text('Heart Disease Risk Prediction'), findsOneWidget);
    });

    test('no storage plugin is declared', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final banned in [
        'shared_preferences',
        'path_provider',
        'sqflite',
        'flutter_secure_storage',
        'isar',
      ]) {
        expect(pubspec.contains(banned), isFalse,
            reason: '$banned must not be a dependency');
      }
      expect(pubspec.contains('flutter_localizations'), isTrue);
    });
  });

  group('labels and disclaimer', () {
    testWidgets('the disclaimer is permanently visible in both languages',
        (tester) async {
      await useTallSurface(tester);

      await tester.pumpWidget(hostApp(languageCode: 'en', model: model));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('NOT a medical diagnostic tool'), findsOneWidget);

      await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
      await tester.pumpAndSettle();
      expect(find.textContaining('ابزار تشخیص پزشکی نیست'), findsOneWidget);
    });

    testWidgets('Persian labels replace the English ones', (tester) async {
      await useTallSurface(tester);

      await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
      await tester.pumpAndSettle();

      expect(find.text('سن'), findsOneWidget);
      expect(find.text('جنسیت'), findsOneWidget);
      expect(find.text('پیش‌بینی'), findsOneWidget);
      expect(find.text('Age'), findsNothing);
      expect(find.text('Predict'), findsNothing);
    });

    testWidgets('the dropdown values keep the same numeric codes',
        (tester) async {
      // The visible labels change with language, the codes behind them do not.
      // This is what keeps the model's input identical in both languages.
      expect(app.kCp.map((o) => o.code).toList(), [1, 2, 3, 4]);
      expect(app.kThal.map((o) => o.code).toList(), [3, 6, 7]);
      expect(app.kSex.map((o) => o.code).toList(), [0, 1]);
      expect(app.kFbs.map((o) => o.code).toList(), [0, 1]);
      expect(app.kRestecg.map((o) => o.code).toList(), [0, 1, 2]);
      expect(app.kExang.map((o) => o.code).toList(), [0, 1]);
      expect(app.kSlope.map((o) => o.code).toList(), [1, 2, 3]);
      expect(app.kCa, [0, 1, 2, 3]);
    });
  });

  group('the same golden case gives the same answer in both languages', () {
    for (final index in kUiGoldenCases) {
      testWidgets('golden case $index', (tester) async {
        await useTallSurface(tester);
        final shown = expectedPercent(index);

        // --- English ---
        await tester.pumpWidget(hostApp(languageCode: 'en', model: model));
        await tester.pumpAndSettle();
        await enterGoldenCase(tester, index, persian: false);
        await tapPredict(tester, persian: false);
        expect(find.text(shown), findsOneWidget,
            reason: 'English run should display $shown');

        // --- Persian ---
        await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
        await tester.pumpAndSettle();
        await enterGoldenCase(tester, index, persian: true);
        await tapPredict(tester, persian: true);
        expect(find.text(shown), findsOneWidget,
            reason: 'Persian run must display the identical $shown');
      });
    }

    testWidgets('Persian-digit input gives the same answer as Latin input',
        (tester) async {
      await useTallSurface(tester);
      final shown = expectedPercent(0);

      await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
      await tester.pumpAndSettle();
      // Same case, typed the way a Persian user would: ۵۳, ۱۲۸, ۲۱۶ ...
      await enterGoldenCase(tester, 0, persian: true, persianDigits: true);
      await tapPredict(tester, persian: true);

      expect(find.text(shown), findsOneWidget,
          reason: 'Persian digits must parse to the same values');
    });

    testWidgets('the percentage always uses Latin digits', (tester) async {
      await useTallSurface(tester);

      await tester.pumpWidget(hostApp(languageCode: 'fa', model: model));
      await tester.pumpAndSettle();
      await tapPredict(tester, persian: true);

      // A Latin-digit percentage exists ...
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data != null &&
            RegExp(r'^[0-9]+\.[0-9]%$').hasMatch(w.data!)),
        findsOneWidget,
      );
      // ... and no Persian-digit percentage does.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data != null &&
            RegExp(r'[۰-۹]').hasMatch(w.data!)),
        findsNothing,
      );
    });
  });

  group('layout at 360x640 dp with text scale 1.3', () {
    // Scrolls the list to the very bottom, which forces every child -- the
    // result card included -- to be built and laid out, and surfaces any
    // RenderFlex overflow as an exception.
    Future<void> scrollToBottom(WidgetTester tester) async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 25; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('Persian does not overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(hostApp(languageCode: 'fa', textScale: 1.3, model: model));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Produce a result, then build the whole page bottom-to-top.
      await tapPredict(tester, persian: true);
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);

      // The result card really was rendered.
      expect(find.textContaining('ریسک'), findsWidgets);
    });

    testWidgets('English does not overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(hostApp(languageCode: 'en', textScale: 1.3, model: model));
      await tester.pumpAndSettle();
      await tapPredict(tester, persian: false);
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);

      expect(find.textContaining('risk band'), findsOneWidget);
    });
  });
}
