import 'package:intl/intl.dart';

import '../constants/app_config.dart';

/// Money and distance formatting, in the shape the mock-ups use.
class Fmt {
  const Fmt._();

  /// "1 840 TMT" — thin space between thousands, the way prices are written
  /// locally.
  static String money(double value) {
    final formatter = NumberFormat.decimalPattern('ru');
    final rounded = value == value.roundToDouble()
        ? formatter.format(value.round())
        : formatter.format(double.parse(value.toStringAsFixed(2)));
    return '$rounded ${AppConfig.currency}';
  }

  /// Bare amount, used inside "с 200".
  static String amount(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }

  /// "2,4 km" — comma decimal separator, as on the order card.
  static String km(double? value) {
    if (value == null) return '—';
    if (value < 1) return '${(value * 1000).round()} m';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  static String time(DateTime value) => DateFormat('HH:mm').format(value);

  /// "4.09" — day.month, locale-independent so it doesn't need intl's
  /// per-language month data loaded.
  static String date(DateTime value) => DateFormat('d.MM').format(value);

  /// Masks the middle of the number the way the mock-up does:
  /// "+993 6X XX XX XX".
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 8) return raw;
    return digits;
  }
}
