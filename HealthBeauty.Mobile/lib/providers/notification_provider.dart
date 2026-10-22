import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/notification_service.dart';
import '../models/notification_item.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({Dio? dio, NotificationService? notificationService})
      : _dio = dio ?? ApiClient().dio,
        _notificationService = notificationService ?? NotificationService() {
    // Lắng nghe khi có push notification tới khi app đang mở
    _messageSubscription =
        _notificationService.onMessageReceived.listen((_) {
      if (_accountId != null) {
        fetchUnreadCount();
        if (items.isNotEmpty) {
          loadNotifications(refresh: true);
        }
      }
    });

    // Lắng nghe token refresh từ Firebase
    _tokenSubscription = _notificationService.onTokenRefresh.listen((token) {
      if (_accountId != null) {
        syncDeviceToken(explicitToken: token);
      }
    });
  }

  final Dio _dio;
  final NotificationService _notificationService;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _tokenSubscription;

  int? _accountId;
  int _generation = 0;
  bool _disposed = false;

  List<NotificationItem> items = [];
  int unreadCount = 0;
  int totalCount = 0;
  int currentPage = 1;
  static const int pageSize = 20;
  bool hasMore = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;

  String? _lastRegisteredToken;

  bool _current(int generation) =>
      !_disposed && generation == _generation && _accountId != null;

  void bind(int? accountId) {
    if (accountId == _accountId) return;
    _accountId = accountId;
    _generation++;
    items = [];
    unreadCount = 0;
    totalCount = 0;
    currentPage = 1;
    hasMore = false;
    error = null;
    isLoading = false;
    isLoadingMore = false;

    if (accountId != null) {
      // Khi đăng nhập: tự động đồng bộ FCM token và đếm tin chưa đọc
      syncDeviceToken();
      fetchUnreadCount();
    } else {
      // Khi đăng xuất: hủy đăng ký token trên server
      if (_lastRegisteredToken != null) {
        deleteDeviceToken(_lastRegisteredToken!);
        _lastRegisteredToken = null;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _messageSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  /// Lấy số lượng thông báo chưa đọc
  Future<void> fetchUnreadCount() async {
    if (_accountId == null) return;
    final generation = _generation;
    try {
      final res = await _dio.get('/notifications/unread-count');
      if (!_current(generation)) return;
      if (res.data is Map && res.data['unreadCount'] != null) {
        unreadCount = (res.data['unreadCount'] as num).toInt();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  /// Tải danh sách thông báo
  Future<void> loadNotifications({
    bool refresh = false,
    bool unreadOnly = false,
  }) async {
    if (_accountId == null) return;
    if (isLoading || (isLoadingMore && !refresh)) return;

    final targetPage = refresh ? 1 : currentPage;
    if (refresh) {
      isLoading = true;
      error = null;
      notifyListeners();
    } else if (targetPage > 1) {
      isLoadingMore = true;
      notifyListeners();
    } else {
      isLoading = true;
      error = null;
      notifyListeners();
    }

    final generation = _generation;

    try {
      final res = await _dio.get(
        '/notifications',
        queryParameters: {
          'page': targetPage,
          'pageSize': pageSize,
          'unreadOnly': unreadOnly,
        },
      );

      if (!_current(generation)) return;

      final data = res.data as Map<String, dynamic>;
      final rawList = data['items'] as List<dynamic>? ?? [];
      final loadedItems = rawList
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();

      totalCount = (data['totalCount'] as num?)?.toInt() ?? loadedItems.length;
      unreadCount = (data['unreadCount'] as num?)?.toInt() ?? unreadCount;

      if (refresh || targetPage == 1) {
        items = loadedItems;
        currentPage = 1;
      } else {
        items.addAll(loadedItems);
        currentPage = targetPage;
      }

      hasMore = items.length < totalCount && loadedItems.isNotEmpty;
    } catch (e) {
      if (_current(generation)) {
        error = 'Không thể tải thông báo. Vui lòng thử lại.';
        debugPrint('Error loading notifications: $e');
      }
    } finally {
      if (_current(generation)) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Tải trang tiếp theo
  Future<void> loadMore({bool unreadOnly = false}) async {
    if (!hasMore || isLoading || isLoadingMore) return;
    currentPage++;
    await loadNotifications(refresh: false, unreadOnly: unreadOnly);
  }

  /// Đánh dấu 1 thông báo là đã đọc
  Future<bool> markAsRead(int id) async {
    if (_accountId == null) return false;
    final index = items.indexWhere((x) => x.id == id);
    if (index != -1 && !items[index].isRead) {
      items[index] = items[index].copyWith(isRead: true);
      if (unreadCount > 0) unreadCount--;
      notifyListeners();
    }

    try {
      await _dio.patch('/notifications/$id/read');
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<bool> markAllAsRead() async {
    if (_accountId == null) return false;
    items = items.map((x) => x.copyWith(isRead: true)).toList();
    unreadCount = 0;
    notifyListeners();

    try {
      await _dio.patch('/notifications/read-all');
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Gửi FCM Token thiết bị lên backend
  Future<void> syncDeviceToken({String? explicitToken}) async {
    if (_accountId == null) return;
    try {
      final token = explicitToken ?? await _notificationService.getDeviceToken();
      if (token == null || token.isEmpty) return;

      final deviceType = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : (kIsWeb ? 'web' : 'android');

      await _dio.post(
        '/notifications/device-token',
        data: {
          'token': token,
          'deviceType': deviceType,
        },
      );
      _lastRegisteredToken = token;
      debugPrint('FCM Device Token synced successfully: $token');
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  /// Xóa token thiết bị khi đăng xuất
  Future<void> deleteDeviceToken(String token) async {
    try {
      await _dio.delete(
        '/notifications/device-token',
        queryParameters: {'token': token},
      );
      debugPrint('FCM Device Token unregistered successfully');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
