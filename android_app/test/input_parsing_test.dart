// input_parsing_test.dart
//
// Unit tests for the Persian/Arabic digit and separator handling.
//
// Run with:  flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_risk_offline/input_parsing.dart';

void main() {
  group('parseLocalizedNumber', () {
    test('accepts Persian digits', () {
      expect(parseLocalizedNumber('۱۲۳'), 123);
    });

    test('accepts Arabic-Indic digits', () {
      expect(parseLocalizedNumber('٣٠'), 30);
    });

    test('accepts the Arabic decimal separator', () {
      expect(parseLocalizedNumber('۱۲٫۵'), 12.5);
    });

    test('treats a single comma as the decimal point', () {
      expect(parseLocalizedNumber('1,5'), 1.5);
    });

    test('trims surrounding whitespace', () {
      expect(parseLocalizedNumber('  42 '), 42);
    });

    test('rejects letters', () {
      expect(parseLocalizedNumber('abc'), isNull);
    });

    test('rejects an empty string', () {
      expect(parseLocalizedNumber(''), isNull);
      expect(parseLocalizedNumber('   '), isNull);
    });

    // --- extra cases that matter for the form ------------------------------

    test('accepts a plain Latin number and a plain Latin decimal', () {
      expect(parseLocalizedNumber('55'), 55);
      expect(parseLocalizedNumber('1.0'), 1.0);
      expect(parseLocalizedNumber('2.3'), 2.3);
    });

    test('handles a Persian decimal with Persian digits and ٫', () {
      expect(parseLocalizedNumber('۰٫۸'), 0.8);
      expect(parseLocalizedNumber('۱۲٫۰'), 12.0);
    });

    test('handles a comma-decimal with Persian digits', () {
      expect(parseLocalizedNumber('۱,۵'), 1.5);
    });

    test('handles a mixed-script number (Persian and Latin digits)', () {
      expect(parseLocalizedNumber('۱۲3'), 123);
    });

    test('treats a single comma as the decimal point (per the spec)', () {
      // The rule is explicit: with no '.' and exactly one ',', that comma IS
      // the decimal mark. So "1,234" means 1.234, exactly like "1,5" means 1.5.
      expect(parseLocalizedNumber('1,234'), 1.234);
    });

    test('treats several commas as thousands separators', () {
      // Two or more commas cannot be a decimal point, so they are grouping
      // marks and simply disappear.
      expect(parseLocalizedNumber('1,234,567'), 1234567);
    });

    test('ignores the Arabic thousands separator', () {
      // U+066C is a grouping mark and carries no numeric value.
      expect(parseLocalizedNumber('1٬234'), 1234);
    });

    test('rejects a lone separator and junk', () {
      expect(parseLocalizedNumber(','), isNull);
      expect(parseLocalizedNumber('.'), isNull);
      expect(parseLocalizedNumber('-'), isNull);
      expect(parseLocalizedNumber('12abc'), isNull);
    });

    test('never returns a non-finite value', () {
      // A 400-digit number overflows a double; the parser must give up rather
      // than hand back an infinity.
      final huge = parseLocalizedNumber(List.filled(400, '9').join());
      expect(huge == null || huge.isFinite, isTrue);
    });
  });

  group('normalizeDigits', () {
    test('converts each digit script to Latin', () {
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(normalizeDigits('0123456789'), '0123456789');
    });

    test('converts the Arabic decimal separator to a dot', () {
      expect(normalizeDigits('۱۲٫۵'), '12.5');
    });

    test('leaves other characters untouched', () {
      expect(normalizeDigits('ab-'), 'ab-');
    });
  });

  group('isPlausibleNumberInput (the TextField formatter rule)', () {
    test('allows partial input in every script', () {
      expect(isPlausibleNumberInput(''), isTrue);
      expect(isPlausibleNumberInput('12'), isTrue);
      expect(isPlausibleNumberInput('۱۲'), isTrue);
      expect(isPlausibleNumberInput('٣٠'), isTrue);
      expect(isPlausibleNumberInput('1.'), isTrue);
      expect(isPlausibleNumberInput('1,'), isTrue);
      expect(isPlausibleNumberInput('۱٫'), isTrue);
    });

    test('rejects letters and a second separator', () {
      expect(isPlausibleNumberInput('1a'), isFalse);
      expect(isPlausibleNumberInput('1.2.3'), isFalse);
      expect(isPlausibleNumberInput('1,2,3'), isFalse);
    });

    test('kDigitsAnyScript keeps Persian and Arabic digits', () {
      // This is the pattern handed to FilteringTextInputFormatter.allow in the
      // form; it must not strip non-Latin digits.
      expect(kDigitsAnyScript.hasMatch('۵'), isTrue);
      expect(kDigitsAnyScript.hasMatch('٥'), isTrue);
      expect(kDigitsAnyScript.hasMatch('5'), isTrue);
      expect(kDigitsAnyScript.hasMatch('٫'), isTrue);
      expect(kDigitsAnyScript.hasMatch('a'), isFalse);
    });
  });
}
