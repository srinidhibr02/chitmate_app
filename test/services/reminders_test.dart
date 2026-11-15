import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/services/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('one reminder per undecided month, 3 days before at 9:00', () {
    final a = testActions();
    final b = example1(a, start: true); // announcements 1 Dec, 1 Jan, 1 Feb, 1 Mar
    final plans = planReminders(<ChitGroup>[b.group], kToday);
    expect(plans.length, 4);
    expect(plans[0].when, DateTime(2026, 11, 28, 9));
    expect(plans[1].when, DateTime(2026, 12, 29, 9));
    expect(plans[2].when, DateTime(2027, 1, 29, 9));
    expect(plans[3].when, DateTime(2027, 2, 26, 9));
    expect(plans.map((p) => p.id).toSet().length, 4);
    expect(plans.first.title, contains('3 days'));
    expect(plans.first.body, contains('Month 1 of 4'));
  });

  test('reminders in the past are skipped', () {
    final a = testActions();
    final b = example1(a, start: true);
    final later = DateTime(2026, 12, 30);
    final plans = planReminders(<ChitGroup>[b.group], later);
    expect(plans.length, 2);
    expect(plans.first.when, DateTime(2027, 1, 29, 9));
  });

  test('exactly at reminder time is not scheduled again', () {
    final a = testActions();
    final b = example1(a, start: true);
    final plans = planReminders(<ChitGroup>[b.group], DateTime(2026, 11, 28, 9));
    expect(plans.first.when, DateTime(2026, 12, 29, 9));
  });

  test('decided months, unstarted and muted groups get none', () {
    final a = testActions();
    final started = example1(a, start: true);
    a.openRound(started.group, 0, method: RoundMethod.random, actor: 'x');
    a.randomDraw(started.group, 0, actor: 'x');
    expect(planReminders(<ChitGroup>[started.group], kToday).length, 3);

    final notStarted = example1(a);
    expect(planReminders(<ChitGroup>[notStarted.group], kToday), isEmpty);

    final muted = example1(a, start: true);
    a.setRemindersEnabled(muted.group, false);
    expect(planReminders(<ChitGroup>[muted.group], kToday), isEmpty);
  });

  test('the limit keeps the soonest reminders', () {
    final a = testActions();
    final b = example1(a, start: true);
    final c = example1(a, start: true);
    final plans = planReminders(<ChitGroup>[b.group, c.group], kToday, limit: 3);
    expect(plans.length, 3);
    for (var i = 1; i < plans.length; i++) {
      expect(plans[i].when.isBefore(plans[i - 1].when), isFalse);
    }
  });
}
