import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/notification_item.dart';
import 'package:app_doancunhan/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationItem Model Tests', () {
    test('parses notification item JSON correctly', () {
      final json = {
        'id': 105,
        'title': 'Lịch hẹn #LH12 đã được xác nhận',
        'body': 'Kỹ thuật viên sẵn sàng đón tiếp quý khách.',
        'type': 'LichHen',
        'data': '{"appointmentId":"12","type":"APPOINTMENT"}',
        'isRead': false,
        'createdAt': '2026-10-17T09:15:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 105);
      expect(item.title, 'Lịch hẹn #LH12 đã được xác nhận');
      expect(item.body, 'Kỹ thuật viên sẵn sàng đón tiếp quý khách.');
      expect(item.type, 'LichHen');
      expect(item.isRead, false);
      expect(item.parsedData, isNotNull);
      expect(item.parsedData?['appointmentId'], '12');
      expect(item.parsedData?['type'], 'APPOINTMENT');
    });

    test('handles null or empty data string gracefully', () {
      final json = {
        'id': 106,
        'title': 'Thông báo hệ thống',
        'body': 'Bảo trì máy chủ định kỳ.',
        'type': 'HeThong',
        'data': null,
        'isRead': true,
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, 106);
      expect(item.parsedData, isNull);
      expect(item.isRead, true);
    });

    test('copyWith updates fields as expected', () {
      final item = NotificationItem(
        id: 1,
        title: 'Title',
        body: 'Body',
        type: 'LichHen',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final readItem = item.copyWith(isRead: true);
      expect(readItem.id, 1);
      expect(readItem.isRead, true);
      expect(readItem.title, 'Title');
    });
  });

  group('NotificationProvider Logic Tests', () {
    test('bind sets account and resets items when account changes', () {
      final provider = NotificationProvider();
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);

      provider.bind(1);
      provider.items.add(
        NotificationItem(
          id: 1,
          title: 'T',
          body: 'B',
          type: 'LichHen',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
      provider.unreadCount = 1;

      // Đổi tài khoản khác
      provider.bind(2);
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);

      // Đăng xuất
      provider.bind(null);
      expect(provider.items, isEmpty);
      expect(provider.unreadCount, 0);
    });

    test('markAsRead updates item locally and decrements unreadCount', () async {
      final dio = Dio();
      final provider = NotificationProvider(dio: dio);
      provider.bind(1);

      provider.items = [
        NotificationItem(
          id: 10,
          title: 'Lịch hẹn',
          body: 'Nội dung',
          type: 'LichHen',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationItem(
          id: 11,
          title: 'Ưu đãi',
          body: 'Nội dung',
          type: 'KhuyenMai',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];
      provider.unreadCount = 2;

      await provider.markAsRead(10);

      expect(provider.items.firstWhere((x) => x.id == 10).isRead, true);
      expect(provider.unreadCount, 1);
    });

    test('markAllAsRead sets all items as read and clears unreadCount', () async {
      final dio = Dio();
      final provider = NotificationProvider(dio: dio);
      provider.bind(1);

      provider.items = [
        NotificationItem(
          id: 1,
          title: 'Tin 1',
          body: 'Body 1',
          type: 'LichHen',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationItem(
          id: 2,
          title: 'Tin 2',
          body: 'Body 2',
          type: 'Voucher',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];
      provider.unreadCount = 2;

      await provider.markAllAsRead();

      expect(provider.items.every((x) => x.isRead), true);
      expect(provider.unreadCount, 0);
    });
  });
}
