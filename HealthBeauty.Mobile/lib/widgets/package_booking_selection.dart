import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/catalog.dart';
import '../models/service_package.dart';

class PackageBookingSelection extends StatelessWidget {
  final CustomerServicePackage package;
  final List<Service> services;
  final Map<int, int> quantities;
  final void Function(int serviceId, int quantity) onQuantity;
  final VoidCallback onExit, onRefresh;
  final bool loading;
  final String? error;
  const PackageBookingSelection({
    super.key,
    required this.package,
    required this.services,
    required this.quantities,
    required this.onQuantity,
    required this.onExit,
    required this.onRefresh,
    this.loading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final availableServices = {
      for (final service in services) service.id: service,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(package.name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${package.statusLabel} · Hạn dùng: ${package.expiresAt == null ? 'Chưa kích hoạt' : dateStr(package.expiresAt!)}',
        ),
        const SizedBox(height: 8),
        const Text(
          'Chọn dịch vụ và số lượt dùng trong lần hẹn này. Gói đã thanh toán, không áp dụng thêm voucher hoặc thu lại tiền dịch vụ.',
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Cập nhật số lượt'),
            ),
            TextButton(
              onPressed: loading ? null : onExit,
              child: const Text('Đặt dịch vụ thông thường'),
            ),
          ],
        ),
        for (final balance in package.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Được cấp: ${balance.granted} · Đã dùng: ${balance.used} · Đang giữ: ${balance.reserved}',
                  ),
                  Text(
                    'Còn lại: ${balance.remaining} · Có thể đặt: ${balance.available}',
                  ),
                  if (!availableServices.containsKey(balance.serviceId))
                    const Text('Dịch vụ hiện không còn khả dụng.'),
                  Row(
                    children: [
                      const Expanded(child: Text('Số lượt lần này')),
                      IconButton(
                        tooltip: 'Giảm số lượt',
                        onPressed:
                            loading || (quantities[balance.serviceId] ?? 0) <= 0
                            ? null
                            : () => onQuantity(
                                balance.serviceId,
                                (quantities[balance.serviceId] ?? 0) - 1,
                              ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${quantities[balance.serviceId] ?? 0}'),
                      IconButton(
                        tooltip: 'Tăng số lượt',
                        onPressed:
                            loading ||
                                !package.canUseAt(DateTime.now()) ||
                                !availableServices.containsKey(
                                  balance.serviceId,
                                ) ||
                                (quantities[balance.serviceId] ?? 0) >=
                                    balance.available
                            ? null
                            : () => onQuantity(
                                balance.serviceId,
                                (quantities[balance.serviceId] ?? 0) + 1,
                              ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
