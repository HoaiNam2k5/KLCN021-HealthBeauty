import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/notification_item.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'login_screen.dart';
import 'invoice_notification_screen.dart';
import '../core/invoice_navigation.dart';
import 'main_shell.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(refresh: true);
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMore(unreadOnly: _unreadOnly);
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    await context
        .read<NotificationProvider>()
        .loadNotifications(refresh: refresh, unreadOnly: _unreadOnly);
  }

  String _formatNotificationTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24 && dt.day == now.day) {
      return 'Hôm nay, ${timeStr(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day &&
        dt.month == yesterday.month &&
        dt.year == yesterday.year) {
      return 'Hôm qua, ${timeStr(dt)}';
    }
    return '${dateStr(dt)} lúc ${timeStr(dt)}';
  }

  void _handleItemClick(NotificationItem item) {
    // 1. Đánh dấu đã đọc trên server và local
    if (!item.isRead) {
      context.read<NotificationProvider>().markAsRead(item.id);
    }

    // 2. Bóc tách dữ liệu để điều hướng
    final data = item.parsedData;
    final type = (data?['type'] ?? item.type).toString().toUpperCase();

    if (type == 'APPOINTMENT' || type == 'LICHHEN') {
      Navigator.pop(context);
      mainTab.value = 2; // Sang tab Lịch hẹn
    } else if (type == 'PROMOTION' || type == 'KHUYENMAI' || type == 'VOUCHER') {
      Navigator.pop(context);
      mainTab.value = 3; // Sang tab Ưu đãi
    } else if (type == 'INVOICE' || type == 'HOADON') {
      final target = InvoiceNotificationTarget.fromPayload({...?data, 'type': type})!;
      Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceNotificationScreen(target: target)));
    } else {
      // Hiển thị dialog xem nội dung chi tiết nếu là thông báo hệ thống
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatNotificationTime(item.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              Text(item.body, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hộp thư thông báo',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (auth.isLoggedIn && notif.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Đánh dấu tất cả là đã đọc',
              onPressed: () async {
                final success =
                    await context.read<NotificationProvider>().markAllAsRead();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: !auth.isLoggedIn
          ? _buildNotLoggedIn(context)
          : Column(
              children: [
                // Filter Tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('Tất cả (${notif.totalCount})'),
                        selected: !_unreadOnly,
                        onSelected: (selected) {
                          if (selected && _unreadOnly) {
                            setState(() => _unreadOnly = false);
                            _loadData(refresh: true);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('Chưa đọc (${notif.unreadCount})'),
                        selected: _unreadOnly,
                        selectedColor: AppColors.roseContainer,
                        onSelected: (selected) {
                          if (selected && !_unreadOnly) {
                            setState(() => _unreadOnly = true);
                            _loadData(refresh: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Danh sách thông báo
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadData(refresh: true),
                    child: notif.isLoading && notif.items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : notif.items.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: notif.items.length +
                                    (notif.isLoadingMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index >= notif.items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }

                                  final item = notif.items[index];
                                  return _NotificationCard(
                                    item: item,
                                    timeStr: _formatNotificationTime(item.createdAt),
                                    onTap: () => _handleItemClick(item),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 72,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Đăng nhập để xem thông báo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn cần đăng nhập vào tài khoản để nhận và xem lịch sử thông báo lịch hẹn, ưu đãi và hóa đơn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (context.mounted &&
                    context.read<AuthProvider>().isLoggedIn) {
                  _loadData(refresh: true);
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.roseContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  size: 44,
                  color: AppColors.rose,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _unreadOnly
                    ? 'Không có thông báo chưa đọc'
                    : 'Chưa có thông báo nào',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _unreadOnly
                      ? 'Tất cả các thông báo của bạn đã được đọc.'
                      : 'Các cập nhật về lịch hẹn, ưu đãi và quà tặng sẽ hiển thị ở đây.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final String timeStr;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.timeStr,
    required this.onTap,
  });

  IconData _getIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('lichhen') || lower.contains('appointment')) {
      return Icons.calendar_today_outlined;
    }
    if (lower.contains('khuyenmai') || lower.contains('promotion')) {
      return Icons.local_offer_outlined;
    }
    if (lower.contains('voucher')) {
      return Icons.card_giftcard_outlined;
    }
    if (lower.contains('hoadon') || lower.contains('invoice')) {
      return Icons.receipt_long_outlined;
    }
    return Icons.notifications_none_outlined;
  }

  Color _getIconBgColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('lichhen') || lower.contains('appointment')) {
      return const Color(0xFFE3F2FD); // Light blue
    }
    if (lower.contains('khuyenmai') || lower.contains('promotion')) {
      return const Color(0xFFFFF3E0); // Light orange
    }
    if (lower.contains('voucher')) {
      return AppColors.roseContainer;
    }
    if (lower.contains('hoadon') || lower.contains('invoice')) {
      return AppColors.sageContainer;
    }
    return AppColors.surfaceTint;
  }

  Color _getIconColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('lichhen') || lower.contains('appointment')) {
      return const Color(0xFF1976D2);
    }
    if (lower.contains('khuyenmai') || lower.contains('promotion')) {
      return const Color(0xFFE65100);
    }
    if (lower.contains('voucher')) {
      return AppColors.rose;
    }
    if (lower.contains('hoadon') || lower.contains('invoice')) {
      return AppColors.sage;
    }
    return AppColors.inkMuted;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    return Material(
      color: isUnread ? Colors.white : AppColors.cream.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      elevation: isUnread ? 1.5 : 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppColors.rose.withValues(alpha: 0.3)
                  : AppColors.outline.withValues(alpha: 0.4),
              width: isUnread ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon loại thông báo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getIconBgColor(item.type),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(item.type),
                  color: _getIconColor(item.type),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              color: isUnread ? AppColors.ink : AppColors.ink.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.rose,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread
                            ? AppColors.ink.withValues(alpha: 0.85)
                            : AppColors.inkMuted,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
