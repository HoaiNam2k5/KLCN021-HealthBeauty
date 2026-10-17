import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (kIsWeb || _isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Request notification permission for Android 13+
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Lên lịch thông báo nhắc nhở lịch hẹn
  Future<void> scheduleAppointmentReminder({
    required int id,
    required String title,
    required String body,
    required DateTime reminderTime,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) await init();

      final now = DateTime.now();
      if (reminderTime.isBefore(now)) {
        await showInstantNotification(
          id: id,
          title: title,
          body: body,
        );
        return;
      }

      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        'Nhắc nhở lịch hẹn',
        channelDescription: 'Thông báo nhắc nhở trước giờ hẹn spa',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint('Scheduled reminder at $reminderTime for appointment #$id');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Hiển thị thông báo ngay lập tức
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    try {
      if (!_isInitialized) await init();

      const androidDetails = AndroidNotificationDetails(
        'appointment_reminders',
        'Nhắc nhở lịch hẹn',
        channelDescription: 'Thông báo nhắc nhở trước giờ hẹn spa',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Hủy thông báo theo ID lịch hẹn
  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
}
