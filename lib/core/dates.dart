/// Calendar helpers. All dates in ChitMate are plain calendar days.
library;

/// Drops the time of day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
/// Uses UTC midnights so daylight-saving changes cannot skew the result.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Adds [months] calendar months, clamping the day to the end of a shorter
/// month (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(year, month, day);
}

/// Subtracts [days] calendar days (calendar arithmetic, not 24h blocks).
DateTime subtractDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day - days);

/// True when [a] and [b] fall on the same calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
