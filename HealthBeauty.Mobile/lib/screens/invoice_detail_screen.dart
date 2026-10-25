import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/common.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final int invoiceId;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  DateTime? _pollUntil;
  int? _accountVersion;
  bool _foreground = true;
  bool _refreshing = false;
  bool _sawPaid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _accountVersion = context.read<InvoiceProvider>().accountVersion;
      _reload();
    });
  }

  bool get _current =>
      mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      _accountVersion == context.read<InvoiceProvider>().accountVersion;

  Future<void> _reload() async {
    if (!_current || _refreshing) return;
    _refreshing = true;
    try {
      final invoice = await context.read<InvoiceProvider>().loadDetail(
        widget.invoiceId,
      );
      if (!mounted || !_current) return;
      if (invoice?.isPaid == true) {
        _pollTimer?.cancel();
        if (!_sawPaid) {
          _sawPaid = true;
          unawaited(context.read<ProfileProvider>().load());
          unawaited(context.read<AppointmentProvider>().load());
        }
      } else if (invoice?.canTransfer == true &&
          context.read<InvoiceProvider>().transfers.containsKey(
            widget.invoiceId,
          ) &&
          _pollTimer?.isActive != true) {
        _startPolling();
      }
    } finally {
      _refreshing = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollUntil = DateTime.now().add(const Duration(minutes: 5));
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_current || DateTime.now().isAfter(_pollUntil!)) {
        _pollTimer?.cancel();
        return;
      }
      if (_foreground) _reload();
    });
  }

  Future<void> _prepareTransfer() async {
    if (!_current) return;
    final provider = context.read<InvoiceProvider>();
    // Refresh server totals and status before showing payment instructions.
    await _reload();
    if (!_current) return;
    final ready = await provider.requestTransfer(widget.invoiceId);
    if (_current && ready) _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _reload();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final authenticated = context.watch<AuthProvider>().isLoggedIn;
    final current =
        authenticated &&
        (_accountVersion == null || _accountVersion == provider.accountVersion);
    final invoice = current ? provider.details[widget.invoiceId] : null;
    final transfer = current ? provider.transfers[widget.invoiceId] : null;
    final error = provider.detailErrors[widget.invoiceId];
    final loading = provider.loadingDetails.contains(widget.invoiceId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết hóa đơn'),
        actions: [
          IconButton(
            onPressed: current && !loading ? _reload : null,
            tooltip: 'Cập nhật hóa đơn',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !current
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Phiên đăng nhập đã thay đổi',
              subtitle: 'Vui lòng quay lại lịch sử hóa đơn.',
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    ErrorState(message: error, onRetry: _reload),
                  if (invoice != null) ...[
                    _summary(invoice),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dịch vụ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in invoice.items) ...[
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _row(
                              '${item.quantity} × ${vnd(item.unitPrice)}',
                              vnd(item.total),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Divider(),
                          _row('Tạm tính', vnd(invoice.subtotal)),
                          _row('Giảm giá', vnd(invoice.discount)),
                          _row(
                            'Tổng thanh toán',
                            vnd(invoice.total),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (invoice.isPaid) ...[
                      const AppCard(
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Thanh toán thành công',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final payment in invoice.payments)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(payment.methodLabel),
                                const SizedBox(height: 6),
                                Text(
                                  vnd(payment.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (payment.paidAt != null)
                                  Text(
                                    '${timeStr(payment.paidAt!)} · ${dateStr(payment.paidAt!)}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (invoice.total == 0 && invoice.payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Hóa đơn không phát sinh khoản thu.'),
                        ),
                    ],
                    if (invoice.canTransfer) ...[
                      if (error == null && transfer != null)
                        _transferCard(transfer),
                      if (provider.transferErrors[widget.invoiceId] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            provider.transferErrors[widget.invoiceId]!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (transfer == null)
                        FilledButton.icon(
                          onPressed:
                              error != null ||
                                  loading ||
                                  provider.loadingTransfers.contains(
                                    widget.invoiceId,
                                  )
                              ? null
                              : _prepareTransfer,
                          icon: const Icon(Icons.qr_code_2),
                          label: Text(
                            provider.loadingTransfers.contains(widget.invoiceId)
                                ? 'Đang lấy thông tin…'
                                : 'Thanh toán chuyển khoản',
                          ),
                        ),
                    ],
                    if (!invoice.isPaid && invoice.total == 0)
                      const Text(
                        'Hóa đơn không cần chuyển khoản. Vui lòng chờ lễ tân xác nhận.',
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summary(CustomerInvoice invoice) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invoice.code,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text('Lịch hẹn #${invoice.appointmentId}'),
        Text(
          'Ngày lập: ${timeStr(invoice.createdAt)} · ${dateStr(invoice.createdAt)}',
        ),
        const SizedBox(height: 8),
        Text(
          invoice.statusLabel,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: invoice.isPaid
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _transferCard(BankTransferInstructions transfer) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chuyển khoản ngân hàng',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quét QR bằng thiết bị khác hoặc sao chép thông tin bên dưới vào ứng dụng ngân hàng.',
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                transfer.qrImageUrl,
                fit: BoxFit.contain,
                semanticLabel: 'QR thanh toán hóa đơn',
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Không tải được mã QR. Bạn có thể chuyển khoản bằng thông tin bên dưới.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
        _row('Ngân hàng', transfer.bankName),
        _row('Chủ tài khoản', transfer.accountName),
        _copyRow('Số tài khoản', transfer.accountNumber),
        _copyRow(
          'Số tiền',
          vnd(transfer.amount),
          copyValue: transfer.amount.toInt().toString(),
        ),
        _copyRow('Nội dung', transfer.transferContent),
        const SizedBox(height: 12),
        const Text(
          'Chuyển đúng số tiền và giữ nguyên nội dung để hệ thống xác nhận tự động. '
          'Bạn có thể quay lại hóa đơn sau khi chuyển khoản.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _refreshing
              ? null
              : () {
                  _startPolling();
                  _reload();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Kiểm tra thanh toán'),
        ),
        const Text(
          'Chỉ xác nhận thành công sau khi hệ thống nhận được giao dịch. '
          'Nếu chưa cập nhật, hãy kiểm tra lại hoặc liên hệ lễ tân.',
        ),
      ],
    ),
  );

  Widget _copyRow(String label, String value, {String? copyValue}) => Row(
    children: [
      Expanded(child: _row(label, value)),
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
}
