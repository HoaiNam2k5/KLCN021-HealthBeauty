import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import '../widgets/service_tile.dart';
import 'booking_screen.dart';
import 'main_shell.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();
    final appts = context.watch<AppointmentProvider>();
    final cs = Theme.of(context).colorScheme;

    final name = (auth.account?.name?.trim().isNotEmpty ?? false)
        ? auth.account!.name!
        : (auth.account?.email ?? '');
    final upcoming = appts.upcoming;
    final next = upcoming.isEmpty ? null : upcoming.first;
    final featured = catalog.services.take(5).toList();
    final promos = catalog.promotions.take(2).toList();

    return RefreshIndicator(
      onRefresh: () => Future.wait([catalog.load(force: true), appts.load()]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Text('Xin chào,', style: TextStyle(color: cs.onSurfaceVariant)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // Lịch hẹn sắp tới
          if (next != null)
            AppCard(
              color: AppColors.roseContainer,
              onTap: () => mainTab.value = 2,
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: AppColors.onRoseContainer, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lịch hẹn sắp tới',
                            style: TextStyle(color: AppColors.onRoseContainer, fontSize: 13)),
                        Text(
                          '${weekdayStr(next.appointmentAt)}, ${dateStr(next.appointmentAt)} · ${timeStr(next.appointmentAt)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.onRoseContainer,
                              fontSize: 16),
                        ),
                        Text(next.serviceSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.onRoseContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingScreen()),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.rose, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bạn chưa có lịch hẹn sắp tới',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('Chạm để đặt lịch ngay',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          SectionTitle(
            'Dịch vụ nổi bật',
            trailing: TextButton(
              onPressed: () => mainTab.value = 1,
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 8),
          if (catalog.loading && !catalog.loaded)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (catalog.error != null && !catalog.loaded)
            ErrorState(message: catalog.error!, onRetry: () => catalog.load(force: true))
          else if (featured.isEmpty)
            const SizedBox(
              height: 160,
              child: EmptyState(
                icon: Icons.spa_outlined,
                title: 'Chưa có dịch vụ nào',
                subtitle: 'Dữ liệu dịch vụ sẽ hiện ở đây khi spa cập nhật',
              ),
            )
          else
            for (final s in featured)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ServiceTile(
                  service: s,
                  categoryName: catalog.categoryName(s.categoryId),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: s)),
                  ),
                ),
              ),

          if (promos.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionTitle(
              'Ưu đãi',
              trailing: TextButton(
                onPressed: () => mainTab.value = 3,
                child: const Text('Xem tất cả'),
              ),
            ),
            const SizedBox(height: 8),
            for (final p in promos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => mainTab.value = 3,
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer, color: AppColors.rose),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(p.discountLabel,
                                style: const TextStyle(color: AppColors.rose)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
