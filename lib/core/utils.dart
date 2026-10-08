import 'package:intl/intl.dart';

/// Formatting + period helpers shared across the app.
library;

class Fmt {
  Fmt._();

  static final NumberFormat _money = NumberFormat('#,##0');
  static final NumberFormat _money2 = NumberFormat('#,##0.00');
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

  static String money(num v) => _money.format(v);
  static String money2(num v) => _money2.format(v);
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);

  /// '2025-04' -> 'Apr 2025'
  static String period(String p) {
    final parts = p.split('-');
    if (parts.length != 2) return p;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (y == 0 || m == 0 || m > 12) return p;
    return '${_monthNames[m - 1]} $y';
  }

  /// 'Apr-2025' / 'Apr 2025' -> '2025-04'  (Google Sheets month headers)
  static String? sheetMonthToPeriod(String label) {
    final clean = label.trim();
    for (var i = 0; i < 12; i++) {
      for (final pat in [
        _monthNames[i],
        _monthNames[i].substring(0, 3),
      ]) {
        if (clean.toLowerCase().startsWith(pat.toLowerCase())) {
          final yearMatch = RegExp(r'(20\d{2})').firstMatch(clean);
          if (yearMatch != null) {
            return '${yearMatch.group(1)}-${(i + 1).toString().padLeft(2, '0')}';
          }
        }
      }
    }
    return null;
  }

  static String currentPeriod([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  /// Last [n] periods ending at current month, oldest first.
  static List<String> lastPeriods(int n, [DateTime? now]) {
    final d = now ?? DateTime.now();
    var y = d.year, m = d.month;
    final out = <String>[];
    for (var i = 0; i < n; i++) {
      out.add('$y-${m.toString().padLeft(2, '0')}');
      m--;
      if (m == 0) {
        m = 12;
        y--;
      }
    }
    return out.reversed.toList();
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
}
