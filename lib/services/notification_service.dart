import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const String channelIdReminders = 'reminders_channel';
  static const String channelNameReminders = 'Reminders';
  static const String channelDescReminders = 'Daily and Monthly reminders';

  static const String channelIdNudge = 'nudge_channel'; // Realtime Nudges
  static const String channelNameNudge = 'Nudges';
  static const String channelDescNudge = 'Payment reminders from friends';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // Android Initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization (Darwin)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
            // Handle notification tap logic here if needed
            // e.g., Navigate to specific screen based on payload
          },
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false; // Web doesn't use this permissions plugin flow
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        // Try again or show dialog explaining why
        return false;
      }
      return status.isGranted;
    } else if (Platform.isIOS) {
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  // Generic Show Notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelIdNudge,
          channelNameNudge,
          channelDescription: channelDescNudge,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Schedule Daily Reminder
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdReminders,
          channelNameReminders,
          channelDescription: channelDescReminders,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Schedule Monthly Reminder (For Due Dates)
  Future<void> scheduleMonthlyNotification({
    required int id, // Use item.id.hashCode
    required String title,
    required String body,
    required int dayOfMonth,
  }) async {
    // If day is past in current month, schedule for next month
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfDayOfMonth(dayOfMonth),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdReminders,
          channelNameReminders,
          channelDescription: channelDescReminders,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  // Schedule Exact Date Reminder (For custom Scheduled Nudges)
  Future<void> scheduleExactNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdNudge,
          channelNameNudge,
          channelDescription: channelDescNudge,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Helpers
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayOfMonth(int day) {
    // Day 1-31. Handle edge cases where current month doesn't have 31 days?
    // The library handles standard logic, but let's be safe.
    // If month doesn't have the day, it might skip or throw.
    // Let's assume standard behavior for now.

    tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Safety check for day validity in current month logic is complex
    // Simplified: Find next valid date matching 'day' in current or future months.

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      day,
      9,
      0,
    ); // 9 AM default

    if (scheduledDate.isBefore(now)) {
      scheduledDate = _nextValidDate(now.year, now.month + 1, day);
    } else if (!_isValidDate(now.year, now.month, day)) {
      // e.g. Trying to set Feb 30th
      // Skip to next month that has it?
      // For simple bills, "Due 30th" usually means "Last day" in Feb or skip.
      // Let's just find next valid instance.
      scheduledDate = _nextValidDate(now.year, now.month, day);
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextValidDate(int year, int month, int day) {
    // Recursive search for a valid month/year that has this day
    // This is a naive implementation but works for typical billing logic
    // Actually, simple monthly repetition using matchDateTimeComponents might fail for Feb 30
    // But for this MVP, we rely on the library's best effort.

    if (month > 12) {
      year++;
      month = 1;
    }

    // Check if day exists in this month
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (day <= daysInMonth) {
      return tz.TZDateTime(tz.local, year, month, day, 9, 0);
    } else {
      // Try next month
      return _nextValidDate(year, month + 1, day);
    }
  }

  bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    return day <= daysInMonth;
  }
}
