// input_parsing.dart
//
// A phone keyboard in Persian (or Arabic) can produce digits that look the same
// to a human but are completely different characters to a computer:
//
//     Latin        0 1 2 3 4 5 6 7 8 9   U+0030..U+0039
//     Persian      ۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹   U+06F0..U+06F9
//     Arabic-Indic ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩   U+0660..U+0669
//
// `double.tryParse("۱۲")` returns null, so without this conversion a Persian
// user typing "۵۵" would see "must be a number". This file fixes that.
//
// It also handles the decimal separators used in the region:
//   * the Arabic decimal separator ٫ (U+066B)
//   * the comma, which is the decimal mark in Persian convention ("۱,۵")
//
// Everything here is plain, dependency-free Dart so it can be unit tested
// without a widget or a device.

/// Converts Persian (U+06F0-U+06F9) and Arabic-Indic (U+0660-U+0669) digits to
/// Latin 0-9, and the Arabic decimal separator to '.'.
///
/// Any other character is left untouched.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      // Persian ۰-۹ -> 0-9
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      // Arabic-Indic ٠-٩ -> 0-9
      buffer.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune == 0x066B) {
      // Arabic decimal separator ٫ -> '.'
      buffer.write('.');
    } else if (rune == 0x066C) {
      // Arabic thousands separator ٬ -> ignore it
      // (it is a grouping mark and carries no numeric value).
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Parses a number typed by the user, accepting Latin, Persian and Arabic
/// digits, and both '.' and ',' as the decimal separator.
///
/// Returns `null` when the text is empty or is not a valid single number.
///
/// Rules, in order:
///   1. trim surrounding whitespace
///   2. convert Persian/Arabic digits and the Arabic decimal separator
///   3. if there is no '.' and exactly one ',', treat that ',' as the decimal
///      point ("1,5" -> 1.5). With several commas ("1,234,567") the number is
///      left alone and parsed as a plain integer, which is the safest reading.
///   4. reject anything that is not a finite number
double? parseLocalizedNumber(String s) {
  // 1. trim
  var text = s.trim();
  if (text.isEmpty) return null;

  // 2. normalize digits and the Arabic decimal separator
  text = normalizeDigits(text);

  // 3. comma as the decimal point, only when it is unambiguous
  final commaCount = ','.allMatches(text).length;
  if (!text.contains('.') && commaCount == 1) {
    text = text.replaceFirst(',', '.');
  } else {
    // Remove thousands separators, but only when they are not being used as
    // the decimal mark: "1,234" stays 1234.
    text = text.replaceAll(',', '');
  }

  // 4. parse
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// The characters the numeric text fields may contain: digits in all three
/// scripts, plus the three decimal separators people actually type.
///
/// Use this with [FilteringTextInputFormatter.allow]. A pattern that allowed
/// only `[0-9]` would silently *delete* Persian digits as the user typed them,
/// which is exactly the bug this avoids.
///
/// (The pattern uses `\uXXXX` escapes; Dart's RegExp engine understands them.)
final RegExp kDigitsAnyScript =
    RegExp(r'[0-9\u06F0-\u06F9\u0660-\u0669.,\u066B]');

/// Whether [s] is an acceptable *complete* number while typing: digits in any
/// script with at most one decimal separator.
///
/// The formatter above blocks stray letters, and this is the stricter check
/// used by the tests.
final RegExp kLocalizedNumberInput = RegExp(
  r'^[0-9\u06F0-\u06F9\u0660-\u0669]*[.,\u066B]?[0-9\u06F0-\u06F9\u0660-\u0669]*$',
);

/// Whether [s] is an acceptable partial number while typing.
bool isPlausibleNumberInput(String s) =>
    s.isEmpty || kLocalizedNumberInput.hasMatch(s);
