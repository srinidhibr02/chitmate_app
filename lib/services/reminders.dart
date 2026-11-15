/// Reminders three days before every announcement date.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/format.dart';
import '../domain/models.dart';

/// How many days before the announcement the reminder fires.
const int kReminderLeadDays = 3;

/// Hour of the day (local time) the reminder fires.
const int kReminderHour = 9;

/// One notification to schedule.
class ReminderPlan {
  const ReminderPlan({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.groupId,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String groupId;
}

/// Works out which reminders should exist. Pure, so it can be tested without
/// a phone.
///
/// A reminder is planned for every month that is not decided yet, at 9:00,
/// three days before its announcement date, if that moment is still ahead.
/// At most [limit] are returned, soonest first (iOS keeps at most 64).
List<ReminderPlan> planReminders(
  List<ChitGroup> groups,
  DateTime now, {
  int limit = 60,
}) {
  final plans = <ReminderPlan>[];
  for (final g in groups) {
    if (!g.remindersEnabled || !g.started) continue;
    for (final r in g.rounds) {
      if (r.isCompleted) continue;
      final day = subtractDays(dateOnly(r.announcementDate), kReminderLeadDays);
      final when = DateTime(day.year, day.month, day.day, kReminderHour);
      if (!when.isAfter(now)) continue;
      final pool = rupees(g.poolAmount);
      plans.add(ReminderPlan(
        id: 0,
        when: when,
        groupId: g.id,
        title: '${g.name}: announcement in $kReminderLeadDays days',
        body: 'Month ${r.number} of ${g.rounds.length} is announced on '
            '${formatDateLong(r.announcementDate)} (pool $pool). '
            'Admin: choose how the chit is picked and post it. '
            'Everyone: pay your share and be ready to vote.',
      ));
    }
  }
  plans.sort((a, b) => a.when.compareTo(b.when));
  final capped = plans.take(limit).toList();
  return <ReminderPlan>[
    for (var i = 0; i < capped.length; i++)
      ReminderPlan(
        id: 1000 + i,
        when: capped[i].when,
        title: capped[i].title,
        body: capped[i].body,
        groupId: capped[i].groupId,
      ),
  ];
}

/// Schedules phone notifications for the plans above.
abstract class ReminderService {
  Future<void> init();

  /// Asks the phone for permission to show notifications.
  Future<bool> requestPermission();

  /// Replaces all scheduled reminders with the ones for [groups].
  Future<void> sync(List<ChitGroup> groups, DateTime now);
}

/// Does nothing. Used in tests and on platforms without notifications.
class NoopReminderService implements ReminderService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync(List<ChitGroup> groups, DateTime now) async {}
}

/// Real notifications through `flutter_local_notifications`.
///
/// Reminders use India Standard Time (the app works in rupees).
class LocalReminderService implements ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'chitmate_reminders',
      'Announcement reminders',
      channelDescription: 'Reminders three days before each chit announcement',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        // Keep the default (UTC) if the zone database is unavailable.
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
      _ready = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final a = await android?.requestNotificationsPermission();
      final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return a == true || i == true;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  @override
  Future<void> sync(List<ChitGroup> groups, DateTime now) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      for (final p in planReminders(groups, now)) {
        final when = tz.TZDateTime(
            tz.local, p.when.year, p.when.month, p.when.day, p.when.hour, p.when.minute);
        await _plugin.zonedSchedule(
          p.id,
          p.title,
          p.body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: p.groupId,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}
