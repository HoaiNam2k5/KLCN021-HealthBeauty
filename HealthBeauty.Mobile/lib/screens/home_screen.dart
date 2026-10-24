import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/common.dart';
import '../widgets/service_tile.dart';
import 'booking_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'notification_screen.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final catalog = context.watch<CatalogProvider>();
    final appts = context.watch<AppointmentProvider>();
    final notif = context.watch<NotificationProvider>();
    final cs = Theme.of(context).colorScheme;

    final name = (auth.account?.name?.trim().isNotEmpty ?? false)
        ? auth.account!.name!
        : (auth.account?.email ?? '');
    final upcoming = appts.upcoming;
    final next = upcoming.isEmpty ? null : upcoming.first;
    final featured = catalog.services.take(6).toList();
    final promos = catalog.promotions.take(2).toList();

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        catalog.load(force: true),
        appts.load(),
        if (auth.isLoggedIn) notif.fetchUnreadCount(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.isLoggedIn ? 'Xin chào,' : 'Chào mừng bạn đến với,',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      auth.isLoggedIn ? name : 'HealthBeauty',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (!auth.isLoggedIn)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Đăng nhập'),
                )
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.notifications_outlined),
                      color: AppColors.ink,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceTint,
                      ),
                    ),
                    if (notif.unreadCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            notif.unreadCount > 99 ? '99+' : notif.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Lịch hẹn sắp tới
          if (auth.isLoggedIn && next != null)
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
              onTap: () async {
                if (!auth.isLoggedIn) {
                  final loggedIn = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (loggedIn != true ||
                      !context.mounted ||
                      !context.read<AuthProvider>().isLoggedIn) {
                    return;
                  }
                }
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingScreen()),
                );
              },
              child: Row(
                children: [
                  Icon(
                    auth.isLoggedIn ? Icons.add_circle_outline : Icons.calendar_month_outlined,
                    color: AppColors.rose,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isLoggedIn
                              ? 'Bạn chưa có lịch hẹn sắp tới'
                              : 'Đặt lịch làm đẹp ngay hôm nay',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          auth.isLoggedIn
                              ? 'Chạm để đặt lịch ngay'
                              : 'Đăng nhập để đặt hẹn cùng chuyên viên',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: featured.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.60,
              ),
              itemBuilder: (context, i) {
                final s = featured[i];
                return ServiceCard(
                  service: s,
                  categoryName: catalog.categoryName(s.categoryId),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: s)),
                  ),
                );
              },
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
