// localization_test.dart
//
// Enforces EN/FA string parity, verified Persian medical terminology,
// zero storage dependencies, numeric code immutability, and RTL/LTR direction.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/heart_model.dart';
import 'package:heart_risk_offline/l10n/strings.dart';
import 'package:heart_risk_offline/main.dart';
import 'package:heart_risk_offline/presets.dart';
import 'package:heart_risk_offline/ui/theme.dart';

void main() {
  late HeartModel model;

  setUpAll(() {
    model = HeartModel.fromJsonString(
      File('assets/model.json').readAsStringSync(),
    );
  });

  group('string maps', () {
    test('en and fa have identical keys and zero empty values', () {
      final en = kEnglishStrings.keys.toSet();
      final fa = kPersianStrings.keys.toSet();

      expect(fa.difference(en), isEmpty);
      expect(en.difference(fa), isEmpty);

      expect(
        kEnglishStrings.entries.where((e) => e.value.trim().isEmpty),
        isEmpty,
      );
      expect(
        kPersianStrings.entries.where((e) => e.value.trim().isEmpty),
        isEmpty,
      );
    });

    test('language toggle names the other language', () {
      expect(kEnglishStrings['languageToggle'], 'فارسی');
      expect(kPersianStrings['languageToggle'], 'English');
    });

    test('verified Persian clinical terminology is preserved verbatim', () {
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
      expect(kPersianStrings['estimatedProbability'], 'احتمال تخمینی بیماری قلبی');
      expect(kPersianStrings['bandLower'], 'ریسک کمتر');
      expect(kPersianStrings['bandModerate'], 'ریسک متوسط');
      expect(kPersianStrings['bandHigher'], 'ریسک بالاتر');
    });

    test('fill substitutes placeholders cleanly', () {
      final out = AppStrings.fill('{field} between {min} and {max}', {
        'field': 'Age',
        'min': '20',
        'max': '100',
      });
      expect(out, 'Age between 20 and 100');
      expect(out.contains('{'), isFalse);
    });
  });

  group('security & option code invariants', () {
    test('no persistent storage or network plugin is declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final banned in <String>[
        'shared_preferences',
        'path_provider',
        'sqflite',
        'flutter_secure_storage',
        'isar',
        'http:',
        'dio:',
      ]) {
        expect(pubspec.contains(banned), isFalse, reason: banned);
      }
      expect(pubspec.contains('flutter_localizations'), isTrue);
    });

    test('option codes stay invariant across languages', () {
      expect(kCpOptions.map((o) => o.code).toList(), [1, 2, 3, 4]);
      expect(kThalOptions.map((o) => o.code).toList(), [3, 6, 7, null]);
      expect(kSexOptions.map((o) => o.code).toList(), [0, 1]);
      expect(kFbsOptions.map((o) => o.code).toList(), [0, 1]);
      expect(kRestecgOptions.map((o) => o.code).toList(), [0, 1, 2]);
      expect(kExangOptions.map((o) => o.code).toList(), [0, 1]);
      expect(kSlopeOptions.map((o) => o.code).toList(), [1, 2, 3]);
      expect(kCaOptions, [0, 1, 2, 3, null]);
    });
  });

  group('directionality & runtime locale toggle', () {
    tearDown(() {
      appLocaleNotifier.value = const Locale('en');
      appThemeModeNotifier.value = ThemeMode.dark;
    });

    testWidgets('switches EN <-> FA RTL/LTR and keeps Latin percentage digits',
        (tester) async {
      await tester.pumpWidget(HeartRiskApp(model: model));
      await tester.pumpAndSettle();

      expect(find.text('BIOVANTA · HEART'), findsOneWidget);
      expect(find.text('5.6%'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn_lang_toggle')));
      await tester.pumpAndSettle();

      final faCtx = tester.element(find.byKey(const ValueKey('hero_result_card')));
      expect(Localizations.localeOf(faCtx).languageCode, 'fa');
      expect(Directionality.of(faCtx), TextDirection.rtl);
      expect(find.text('5.6%'), findsOneWidget);

      // Persian-digit numeric entry updates live without error and keeps Latin % digits
      final ageField = find.byKey(const ValueKey('field_age'));
      await tester.scrollUntilVisible(
        ageField,
        240.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(ageField, '۵۲');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('btn_lang_toggle')),
        -300.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              RegExp(r'^[0-9]+\.[0-9]%$').hasMatch(w.data!),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('btn_lang_toggle')));
      await tester.pumpAndSettle();
      final enCtx = tester.element(find.byKey(const ValueKey('hero_result_card')));
      expect(Localizations.localeOf(enCtx).languageCode, 'en');
      expect(Directionality.of(enCtx), TextDirection.ltr);
    });
  });
}
