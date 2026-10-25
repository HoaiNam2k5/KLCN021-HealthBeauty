import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../screens/invoice_detail_screen.dart';
import 'common.dart';

class PendingInvoiceReminder extends StatelessWidget {
  const PendingInvoiceReminder({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final auth = context.watch<AuthProvider>();
    final invoice = provider.pendingInvoice;
    if (!auth.isLoggedIn ||
        provider.accountId != auth.account?.id ||
        invoice == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        color: Theme.of(context).colorScheme.secondaryContainer,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn có hóa đơn chờ thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('${invoice.code} · ${vnd(invoice.total)}'),
                  const SizedBox(height: 6),
                  Text(
                    provider.pendingError != null
                        ? 'Chưa cập nhật được trạng thái. Chạm để kiểm tra hóa đơn.'
                        : invoice.canTransfer
                        ? 'Chạm để xem hóa đơn và thanh toán chuyển khoản.'
                        : 'Chạm để xem hóa đơn và liên hệ lễ tân.',
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
