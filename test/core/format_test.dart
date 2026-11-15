import 'package:chit_mate/core/dates.dart';
import 'package:chit_mate/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rupees', () {
    test('uses Indian digit grouping', () {
      expect(rupees(0), '₹0');
      expect(rupees(999), '₹999');
      expect(rupees(1000), '₹1,000');
      expect(rupees(10000), '₹10,000');
      expect(rupees(100000), '₹1,00,000');
      expect(rupees(1234567), '₹12,34,567');
      expect(rupees(10000000), '₹1,00,00,000');
    });

    test('handles negative amounts', () {
      expect(rupees(-1500), '-₹1,500');
      expect(groupIndian(-100000), '-1,00,000');
    });

    test('compact form', () {
      expect(rupeesCompact(500), '₹500');
      expect(rupeesCompact(1000), '₹1K');
      expect(rupeesCompact(10000), '₹10K');
      expect(rupeesCompact(150000), '₹1.5L');
      expect(rupeesCompact(10000000), '₹1Cr');
    });
  });

  group('text helpers', () {
    test('plural', () {
      expect(plural(1, 'vote'), '1 vote');
      expect(plural(3, 'vote'), '3 votes');
      expect(plural(0, 'chit'), '0 chits');
      expect(plural(2, 'person', 'people'), '2 people');
    });

    test('ordinal', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
      expect(ordinal(21), '21st');
      expect(ordinal(112), '112th');
    });

    test('countdownText', () {
      final now = DateTime(2026, 11, 14, 15);
      expect(countdownText(DateTime(2026, 11, 14), now), 'today');
      expect(countdownText(DateTime(2026, 11, 15), now), 'tomorrow');
      expect(countdownText(DateTime(2026, 11, 19), now), 'in 5 days');
      expect(countdownText(DateTime(2026, 11, 13), now), 'yesterday');
      expect(countdownText(DateTime(2026, 11, 10), now), '4 days ago');
    });

    test('dates', () {
      final d = DateTime(2026, 11, 14);
      expect(formatDate(d), '14 Nov 2026');
      expect(formatDayMonth(d), '14 Nov');
      expect(formatDateLong(d), 'Sat, 14 Nov 2026');
      expect(formatMonthYear(d), 'Nov 2026');
    });
  });

  group('calendar helpers', () {
    test('addMonths clamps to the end of shorter months', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
      expect(addMonths(DateTime(2026, 11, 14), 2), DateTime(2027, 1, 14));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(addMonths(DateTime(2026, 3, 10), 0), DateTime(2026, 3, 10));
    });

    test('addMonths is computed from the start, not chained', () {
      final first = DateTime(2026, 1, 31);
      expect(addMonths(first, 1), DateTime(2026, 2, 28));
      expect(addMonths(first, 2), DateTime(2026, 3, 31));
      expect(addMonths(first, 3), DateTime(2026, 4, 30));
    });

    test('daysBetween counts calendar days', () {
      expect(daysBetween(DateTime(2026, 11, 14, 23), DateTime(2026, 11, 15, 1)), 1);
      expect(daysBetween(DateTime(2026, 11, 14), DateTime(2026, 11, 14)), 0);
      expect(daysBetween(DateTime(2026, 11, 14), DateTime(2026, 11, 11)), -3);
      expect(daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
    });

    test('subtractDays and sameDay', () {
      expect(subtractDays(DateTime(2026, 3, 2), 3), DateTime(2026, 2, 27));
      expect(sameDay(DateTime(2026, 5, 5, 1), DateTime(2026, 5, 5, 23)), isTrue);
      expect(sameDay(DateTime(2026, 5, 5), DateTime(2026, 5, 6)), isFalse);
      expect(dateOnly(DateTime(2026, 5, 5, 17, 30)), DateTime(2026, 5, 5));
    });
  });
}
