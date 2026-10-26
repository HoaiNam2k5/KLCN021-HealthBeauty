import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../providers/auth_provider.dart';
import '../providers/service_package_provider.dart';
import '../widgets/common.dart';

class PackagePaymentScreen extends StatefulWidget {
  const PackagePaymentScreen({super.key, required this.purchaseId});
  final int purchaseId;
  @override
  State<PackagePaymentScreen> createState() => _PackagePaymentScreenState();
}

class _PackagePaymentScreenState extends State<PackagePaymentScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _pollUntil;
  int? _accountVersion;
  bool _foreground = true, _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _accountVersion = context.read<ServicePackageProvider>().accountVersion;
      _prepare();
    });
  }

  bool get _current =>
      mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      _accountVersion == context.read<ServicePackageProvider>().accountVersion;

  void _startPolling() {
    _timer?.cancel();
    _pollUntil = DateTime.now().add(const Duration(minutes: 5));
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_current || DateTime.now().isAfter(_pollUntil!)) {
        _timer?.cancel();
      } else if (_foreground) {
        _reload();
      }
    });
  }

  Future<void> _reload() async {
    if (!_current || _refreshing) return;
    _refreshing = true;
    try {
      final detail = await context.read<ServicePackageProvider>().loadDetail(
        widget.purchaseId,
      );
      if (!_current) return;
      if (detail != null && detail.package.status != 'Pending') {
        _timer?.cancel();
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _prepare() async {
    if (!_current) return;
    final provider = context.read<ServicePackageProvider>();
    await _reload();
    if (!_current) return;
    if (await provider.requestTransfer(widget.purchaseId) && _current) {
      _startPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _reload();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _copy(String label, String value, {String? copyValue}) => Row(
    children: [
      Expanded(child: SelectableText('$label: $value')),
      IconButton(
        tooltip: 'Sao chép $label',
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: copyValue ?? value));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã sao chép ${label.toLowerCase()}')),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServicePackageProvider>();
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    final current =
        loggedIn &&
        (_accountVersion == null || _accountVersion == provider.accountVersion);
    final package = current
        ? provider.details[widget.purchaseId]?.package
        : null;
    final transfer = current ? provider.transfers[widget.purchaseId] : null;
    final error = provider.transferErrors[widget.purchaseId];
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán mua gói')),
      body: !current
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Phiên đăng nhập đã thay đổi',
              subtitle: 'Vui lòng mở lại gói sau khi đăng nhập.',
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (provider.detailLoading ||
                      provider.loadingTransfers.contains(widget.purchaseId))
                    const LinearProgressIndicator(),
                  if (provider.detailError != null)
                    ErrorState(
                      message: provider.detailError!,
                      onRetry: _reload,
                    ),
                  if (package != null) ...[
                    Text(
                      package.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Gói đã mua #${package.id} · ${vnd(package.price)}'),
                    const SizedBox(height: 16),
                    if (package.status == 'Paid')
                      const AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            Text(
                              'Thanh toán thành công',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Gói đã được kích hoạt. Quay lại chi tiết gói để đặt lịch sử dụng lượt.',
                            ),
                          ],
                        ),
                      ),
                    if (package.status == 'Cancelled')
                      const Text(
                        'Đăng ký gói đã hủy. Không chuyển khoản cho đăng ký này.',
                      ),
                    if (package.status == 'Pending') ...[
                      const Text(
                        'Gói chỉ được kích hoạt khi hệ thống xác nhận đã nhận tiền. Chưa thanh toán thì chưa thể đặt lịch bằng lượt trong gói.',
                      ),
                      const SizedBox(height: 12),
                      if (error != null)
                        ErrorState(message: error, onRetry: _prepare),
                      if (transfer == null)
                        FilledButton.icon(
                          onPressed:
                              provider.detailLoading ||
                                  provider.loadingTransfers.contains(
                                    widget.purchaseId,
                                  )
                              ? null
                              : _prepare,
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Lấy mã thanh toán'),
                        ),
                      if (transfer != null)
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quét mã bằng thiết bị khác hoặc sao chép thông tin vào ứng dụng ngân hàng.',
                              ),
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Image.network(
                                      transfer.qrImageUrl,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'QR thanh toán mua gói',
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Text(
                                          'Không tải được QR. Hãy dùng thông tin chuyển khoản bên dưới.',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text('Ngân hàng: ${transfer.bankName}'),
                              Text('Chủ tài khoản: ${transfer.accountName}'),
                              _copy('Số tài khoản', transfer.accountNumber),
                              _copy(
                                'Số tiền',
                                vnd(transfer.amount),
                                copyValue: transfer.amount.toInt().toString(),
                              ),
                              _copy('Nội dung', transfer.transferContent),
                              const Text(
                                'Chuyển đúng số tiền và nội dung. Hệ thống tự xác nhận khi nhận được giao dịch; không cần đăng ký mua lại.',
                              ),
                              OutlinedButton.icon(
                                onPressed: provider.detailLoading
                                    ? null
                                    : () {
                                        _startPolling();
                                        _reload();
                                      },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Kiểm tra thanh toán'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
