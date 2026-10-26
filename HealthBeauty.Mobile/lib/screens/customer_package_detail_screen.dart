import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/service_package.dart';
import '../providers/auth_provider.dart';
import '../providers/service_package_provider.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';
import 'package_payment_screen.dart';

class CustomerPackageDetailScreen extends StatefulWidget {
  final int customerPackageId;
  const CustomerPackageDetailScreen({
    super.key,
    required this.customerPackageId,
  });
  @override
  State<CustomerPackageDetailScreen> createState() =>
      _CustomerPackageDetailScreenState();
}

class _CustomerPackageDetailScreenState
    extends State<CustomerPackageDetailScreen> {
  bool _acting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    await context.read<ServicePackageProvider>().loadDetail(
      widget.customerPackageId,
    );
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _book() async {
    if (_acting) return;
    setState(() => _acting = true);
    final provider = context.read<ServicePackageProvider>();
    final version = provider.accountVersion;
    try {
      final latest = await provider.loadDetail(widget.customerPackageId);
      if (!mounted ||
          version != provider.accountVersion ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
      if (latest == null) {
        _message(provider.detailError ?? 'Không tải được gói.');
        return;
      }
      if (!latest.package.canUseAt(DateTime.now())) {
        _message(
          'Gói chưa thanh toán, hết hạn hoặc không còn lượt có thể đặt.',
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(initialCustomerPackage: latest.package),
        ),
      );
      if (mounted && version == provider.accountVersion) await _reload();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    if (_acting) return;
    setState(() => _acting = true);
    final provider = context.read<ServicePackageProvider>();
    final version = provider.accountVersion;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Hủy đăng ký gói?'),
          content: const Text('Chỉ gói đang chờ thanh toán mới có thể hủy.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Giữ lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Hủy đăng ký'),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirm != true ||
          version != provider.accountVersion ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
      final ok = await provider.cancelPurchase(widget.customerPackageId);
      if (!mounted ||
          version != provider.accountVersion ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
      if (!ok) {
        _message(provider.actionError ?? 'Không hủy được đăng ký.');
        return;
      }
      _message('Đã hủy đăng ký gói.');
      await _reload();
      await provider.loadMine();
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServicePackageProvider>();
    final auth = context.watch<AuthProvider>();
    final detail = provider.details[widget.customerPackageId];
    final owned = detail?.package;
    return Scaffold(
      appBar: AppBar(title: const Text('Gói dịch vụ đã mua')),
      body: !auth.isLoggedIn
          ? const Center(child: Text('Vui lòng đăng nhập lại để xem gói.'))
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (provider.detailLoading) const LinearProgressIndicator(),
                  if (provider.detailError != null)
                    ErrorState(
                      message: provider.detailError!,
                      onRetry: _reload,
                    ),
                  if (owned != null) ...[
                    Text(
                      owned.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Mã gói đã mua #${owned.id} · ${owned.statusLabel}'),
                    Text('Giá khi đăng ký: ${vnd(owned.price)}'),
                    Text('Đăng ký: ${dateStr(owned.createdAt)}'),
                    if (owned.paidAt != null)
                      Text('Thanh toán: ${dateStr(owned.paidAt!)}'),
                    if (owned.expiresAt != null)
                      Text(
                        'Hết hạn: ${dateStr(owned.expiresAt!)} ${timeStr(owned.expiresAt!)}',
                      ),
                    if (owned.status == 'Pending') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Thanh toán chuyển khoản để kích hoạt gói. Hệ thống tự xác nhận khi nhận tiền; bạn chỉ dùng được lượt sau khi gói đã thanh toán.',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _acting || provider.cancelling
                            ? null
                            : () async {
                                final version = provider.accountVersion;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PackagePaymentScreen(
                                      purchaseId: owned.id,
                                    ),
                                  ),
                                );
                                if (mounted &&
                                    version == provider.accountVersion) {
                                  await _reload();
                                }
                              },
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Thanh toán chuyển khoản'),
                      ),
                      OutlinedButton(
                        onPressed: _acting || provider.cancelling
                            ? null
                            : _cancel,
                        child: const Text('Hủy đăng ký chưa thanh toán'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const SectionTitle('Số lượt theo dịch vụ'),
                    const Text(
                      'Còn lại = được cấp − đã dùng. Có thể đặt đã trừ lượt đang giữ cho lịch hẹn.',
                    ),
                    const SizedBox(height: 8),
                    for (final item in owned.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.serviceName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Được cấp: ${item.granted} · Đã dùng: ${item.used} · Đang giữ: ${item.reserved}',
                              ),
                              Text(
                                'Còn lại: ${item.remaining} · Có thể đặt: ${item.available}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (owned.status == 'Paid')
                      FilledButton.icon(
                        onPressed:
                            _acting ||
                                provider.detailLoading ||
                                !owned.canUseAt(DateTime.now())
                            ? null
                            : _book,
                        icon: const Icon(Icons.event_available),
                        label: const Text('Đặt lịch sử dụng gói'),
                      ),
                    const SizedBox(height: 24),
                    const SectionTitle('Lịch sử sử dụng'),
                    if (detail!.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có lịch sử giữ hoặc sử dụng lượt.'),
                      ),
                    for (final usage in detail.history)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_usageService(owned, usage.customerPackageItemId)} · ${usage.quantity} lượt',
                              ),
                              Text(
                                '${usage.statusLabel} · Lịch hẹn #${usage.appointmentId}',
                              ),
                              Text(
                                '${dateStr(usage.createdAt)} ${timeStr(usage.createdAt)}',
                              ),
                              if (usage.settledAt != null)
                                Text(
                                  'Cập nhật: ${dateStr(usage.settledAt!)} ${timeStr(usage.settledAt!)}',
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  String _usageService(CustomerServicePackage package, int itemId) {
    for (final item in package.items) {
      if (item.id == itemId) return item.serviceName;
    }
    return 'Dịch vụ trong gói';
  }
}
