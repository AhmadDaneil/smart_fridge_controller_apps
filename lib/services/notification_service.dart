import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/fridge_item.dart';

/// How many days before expiry the "expiring soon" notification fires.
/// This matches `isExpiringSoon` in fridge_item.dart (daysUntilExpiry <= 3).
/// If you change one, change the other.
const int kExpiryReminderDaysBefore = 3;

/// Hour of day (24h) the reminder notification is delivered at.
const int kExpiryReminderHour = 9;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTz));
    } catch (_) {
      // Fall back to UTC if the device timezone can't be resolved —
      // reminders will still fire, just possibly off by your UTC offset.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // we ask explicitly below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Deterministic notification id derived from the item id, so we can
  /// reliably cancel/replace it later without tracking ids separately.
  int _idFor(String itemId) => itemId.hashCode & 0x7fffffff;

  /// Schedule (or reschedule) an "expiring soon" reminder for [item].
  /// Call this whenever an item is added or its expiry date is edited.
  ///
  /// Failures here (e.g. notification permission denied) are swallowed —
  /// they should never block saving an item, which is a much more
  /// important action to the user than the reminder itself.
  Future<void> scheduleExpiryReminder(FridgeItem item) async {
    try {
      await cancelReminder(item.id); // clear any previous schedule for this item

      final reminderDate = DateTime(
        item.expiryDate.year,
        item.expiryDate.month,
        item.expiryDate.day - kExpiryReminderDaysBefore,
        kExpiryReminderHour,
      );

      // Don't schedule reminders in the past (e.g. item already expiring
      // today or added with less notice than the reminder window).
      if (reminderDate.isBefore(DateTime.now())) return;

      const androidDetails = AndroidNotificationDetails(
        'expiry_channel',
        'Expiry Reminders',
        channelDescription: 'Reminds you when food items are about to expire',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        _idFor(item.id),
        '${item.name} is expiring soon',
        'Expires in $kExpiryReminderDaysBefore day(s) — use it up before it goes to waste!',
        tz.TZDateTime.from(reminderDate, tz.local),
        details,
        // inexactAllowWhileIdle does NOT require the special "Alarms &
        // reminders" permission that exact scheduling needs on Android 12+.
        // A reminder firing within a few minutes of the target time is
        // perfectly fine for "your food expires soon".
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Log only — never let a notification failure surface as an
      // "add item failed" error to the user.
      debugPrint('Could not schedule expiry reminder: $e');
    }
  }

  Future<void> showImmediateNotification({
  required String id,
  required String title,
  required String body,
}) async {
  try {
    const androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Reminders',
      channelDescription: 'Reminds you when food items are about to expire',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      _idFor(id),
      title,
      body,
      details,
    );
  } catch (e) {
    debugPrint('Could not show immediate notification: $e');
  }
}

  Future<void> cancelReminder(String itemId) async {
    await _plugin.cancel(_idFor(itemId));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}