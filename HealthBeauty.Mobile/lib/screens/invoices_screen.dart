import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../widgets/common.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvoiceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final authenticated = context.watch<AuthProvider>().isLoggedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử hóa đơn')),
      body: !authenticated
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Vui lòng đăng nhập để xem hóa đơn của bạn.',
            )
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Hóa đơn dịch vụ của bạn',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Xem chi tiết và thanh toán hóa đơn sau khi hoàn thành dịch vụ.',
                  ),
                  const SizedBox(height: 20),
                  if (provider.error != null)
                    ErrorState(
                      message: provider.error!,
                      onRetry: () => provider.load(),
                    ),
                  if (provider.invoices.isEmpty &&
                      !provider.loading &&
                      provider.error == null)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Bạn chưa có hóa đơn',
                      subtitle: 'Hóa đơn sẽ hiển thị khi lễ tân chốt dịch vụ.',
                    ),
                  for (final invoice in provider.invoices) ...[
                    _InvoiceCard(invoice: invoice),
                    const SizedBox(height: 12),
                  ],
                  if (provider.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (!provider.loading &&
                      provider.hasMore &&
                      provider.invoices.isNotEmpty)
                    OutlinedButton(
                      onPressed: () => provider.load(more: true),
                      child: const Text('Xem thêm hóa đơn'),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final CustomerInvoice invoice;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invoice.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${dateStr(invoice.createdAt)} · Lịch hẹn #${invoice.appointmentId}',
        ),
        const SizedBox(height: 8),
        if (invoice.items.isNotEmpty)
          Text(
            invoice.items.map((x) => x.name).join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              vnd(invoice.total),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              invoice.statusLabel,
              style: TextStyle(
                color: invoice.isPaid
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
