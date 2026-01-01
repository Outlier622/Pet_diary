import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CleanReminderService {
  CleanReminderService._();
  static final CleanReminderService instance = CleanReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final String localTz = DateTime.now().timeZoneName;
    tz.setLocalLocation(tz.getLocation(localTz));

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'clean_reminders',
      'Clean Reminders',
      channelDescription: 'Pet cleaning reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    return const NotificationDetails(android: android);
  }

  Future<void> cancelAll(List<int> ids) async {
    for (final int id in ids) {
      await _plugin.cancel(id);
    }
  }

  Future<void> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleWeekly({
    required int id,
    required int weekday, // 1..7
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final tz.TZDateTime next =
        _nextInstance(weekday, hour, minute);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _details(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstance(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    int daysAhead = (weekday - scheduled.weekday) % 7;
    if (daysAhead == 0 && scheduled.isBefore(now)) {
      daysAhead = 7;
    }
    return scheduled.add(Duration(days: daysAhead));
  }
}
