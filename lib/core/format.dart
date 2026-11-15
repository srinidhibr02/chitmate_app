/// Formatting helpers: Indian-style rupee amounts and plain dates.
///
/// Kept free of the `intl` package on purpose so the app has fewer moving
/// parts.
library;

import 'dates.dart';

const List<String> _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Groups digits the Indian way: 1,00,000 and 12,34,567.
String groupIndian(int value) {
  final digits = value.abs().toString();
  final String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return value < 0 ? '-$grouped' : grouped;
}

/// Rupee amount with the symbol and Indian grouping, e.g. `₹1,00,000`.
String rupees(int amount) {
  if (amount < 0) return '-₹${groupIndian(-amount)}';
  return '₹${groupIndian(amount)}';
}

String _trimDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Short form for tight spaces: `₹10K`, `₹1.5L`, `₹2Cr`.
String rupeesCompact(int amount) {
  final negative = amount < 0;
  final a = amount.abs();
  final String body;
  if (a >= 10000000) {
    body = '${_trimDecimal(a / 10000000)}Cr';
  } else if (a >= 100000) {
    body = '${_trimDecimal(a / 100000)}L';
  } else if (a >= 1000) {
    body = '${_trimDecimal(a / 1000)}K';
  } else {
    body = '$a';
  }
  return '${negative ? '-' : ''}₹$body';
}

/// `14 Nov 2026`
String formatDate(DateTime d) => '${d.day} ${_monthShort[d.month - 1]} ${d.year}';

/// `14 Nov`
String formatDayMonth(DateTime d) => '${d.day} ${_monthShort[d.month - 1]}';

/// `Sat, 14 Nov 2026`
String formatDateLong(DateTime d) =>
    '${_weekdayShort[d.weekday - 1]}, ${formatDate(d)}';

/// `Nov 2026`
String formatMonthYear(DateTime d) => '${_monthShort[d.month - 1]} ${d.year}';

/// How far away a calendar day is: `today`, `tomorrow`, `in 5 days`,
/// `yesterday`, `3 days ago`.
String countdownText(DateTime date, DateTime now) {
  final d = daysBetween(now, date);
  if (d == 0) return 'today';
  if (d == 1) return 'tomorrow';
  if (d > 1) return 'in $d days';
  if (d == -1) return 'yesterday';
  return '${-d} days ago';
}

/// `1 vote` / `3 votes`
String plural(int n, String singular, [String? pluralForm]) =>
    n == 1 ? '$n $singular' : '$n ${pluralForm ?? '${singular}s'}';

/// `1st`, `2nd`, `3rd`, `4th` ...
String ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
