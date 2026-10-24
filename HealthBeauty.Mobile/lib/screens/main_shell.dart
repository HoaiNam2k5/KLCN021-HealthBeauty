import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import 'account_screen.dart';
import 'appointments_screen.dart';
import 'booking_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'offers_screen.dart';
import 'services_screen.dart';

/// Màn nào cũng có thể đổi tab bằng cách gán: mainTab.value = 2;
final ValueNotifier<int> mainTab = ValueNotifier<int>(0);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    mainTab.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().load();
      context.read<AppointmentProvider>().load();
      context.read<ProfileProvider>().load();
      context.read<NotificationProvider>().fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mainTab,
      builder: (context, index, _) {
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: index,
              children: const [
                HomeScreen(),
                ServicesScreen(),
                AppointmentsScreen(),
                OffersScreen(),
                AccountScreen(),
              ],
            ),
          ),
          floatingActionButton: (index == 0 || index == 2)
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
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
                  icon: const Icon(Icons.add),
                  label: const Text('Đặt lịch'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            backgroundColor: Colors.white,
            indicatorColor: AppColors.roseContainer,
            selectedIndex: index,
            onDestinationSelected: (i) async {
              final auth = context.read<AuthProvider>();
              // Tab 2 (Lịch hẹn) và Tab 4 (Tài khoản) là tính năng liên quan đến tài khoản
              if (!auth.isLoggedIn && (i == 2 || i == 4)) {
                final loggedIn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (loggedIn == true &&
                    context.mounted &&
                    context.read<AuthProvider>().isLoggedIn) {
                  mainTab.value = i;
                }
                return;
              }
              mainTab.value = i;
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Trang chủ'),
              NavigationDestination(
                  icon: Icon(Icons.spa_outlined),
                  selectedIcon: Icon(Icons.spa),
                  label: 'Dịch vụ'),
              NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Lịch hẹn'),
              NavigationDestination(
                  icon: Icon(Icons.local_offer_outlined),
                  selectedIcon: Icon(Icons.local_offer),
                  label: 'Ưu đãi'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Tài khoản'),
            ],
          ),
        );
      },
    );
  }
}
