import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../firebase_options.dart';
import '../screens/main_shell.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('FCM background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessageReceived => _messageStreamController.stream;

  bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'spa_notifications',
    'Thông báo Spa',
    description: 'Kênh nhận thông báo lịch hẹn, ưu đãi và hóa đơn',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Khởi tạo Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase.initializeApp warning: $e');
      }

      // 2. Khởi tạo Local Notifications
      if (!kIsWeb) {
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
            if (details.payload != null && details.payload!.isNotEmpty) {
              try {
                final data = jsonDecode(details.payload!) as Map<String, dynamic>;
                _handlePayloadNavigation(data);
              } catch (e) {
                debugPrint('Error parsing notification payload: $e');
              }
            }
          },
        );

        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(_channel);
          await androidImplementation.requestNotificationsPermission();
        }
      }

      // 3. Cấu hình FCM nếu khả dụng
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final messaging = FirebaseMessaging.instance;

        // Xin quyền nhận push notification
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        // Đăng ký background handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Lắng nghe khi app đang mở (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground FCM message: ${message.notification?.title}');
          _messageStreamController.add(message);

          final notification = message.notification;
          if (notification != null) {
            _notificationsPlugin.show(
              id: message.hashCode,
              title: notification.title,
              body: notification.body,
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  icon: '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: jsonEncode(message.data),
            );
          }
        });

        // Xử lý khi nhấn thông báo từ background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('FCM message clicked from background: ${message.data}');
          _handlePayloadNavigation(message.data);
        });

        // Xử lý khi app được mở từ trạng thái terminated bằng cách bấm thông báo
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('FCM app opened from terminated: ${initialMessage.data}');
          _handlePayloadNavigation(initialMessage.data);
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Lấy FCM Token thiết bị hiện tại
  Future<String?> getDeviceToken() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM device token: $e');
      return null;
    }
  }

  /// Stream lắng nghe token thay đổi
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh {
    try {
      // ignore: deprecated_member_use
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream<String>.empty();
    }
  }

  /// Điều hướng tự động theo loại thông báo
  static void _handlePayloadNavigation(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString().toUpperCase();
      if (type == 'APPOINTMENT' || type == 'LICHHEN') {
        mainTab.value = 2; // Chuyển sang Tab Lịch hẹn
      } else if (type == 'PROMOTION' || type == 'KHUYENMAI' || type == 'VOUCHER') {
        mainTab.value = 3; // Chuyển sang Tab Ưu đãi / Voucher
      } else if (type == 'INVOICE' || type == 'HOADON') {
        mainTab.value = 4; // Chuyển sang Tab Tài khoản / Lịch sử
      }
    } catch (e) {
      debugPrint('Error navigating from notification payload: $e');
    }
  }

  /// Lên lịch thông báo nhắc nhở lịch hẹn cục bộ
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
        'spa_notifications',
        'Thông báo Spa',
        channelDescription: 'Thông báo lịch hẹn, ưu đãi và hóa đơn',
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
