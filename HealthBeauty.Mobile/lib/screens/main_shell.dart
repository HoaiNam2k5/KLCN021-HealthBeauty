import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/invoice_navigation.dart';
import '../core/notification_service.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/service_package_provider.dart';
import 'account_screen.dart';
import 'appointments_screen.dart';
import 'booking_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'offers_screen.dart';
import 'services_screen.dart';
import 'invoice_notification_screen.dart';
import '../widgets/promo_banner_dialog.dart';
import '../widgets/spa_bottom_navigation.dart';
import '../widgets/home_support_buttons.dart';

/// Màn nào cũng có thể đổi tab bằng cách gán: mainTab.value = 2;
final ValueNotifier<int> mainTab = ValueNotifier<int>(0);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  Timer? _refreshTimer;
  StreamSubscription? _messageSubscription;
  int? _accountId;
  int _accountEpoch = 0;
  bool _foreground = true, _refreshing = false, _openingInvoice = false;
  bool _homeSupportVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mainTab.value = 0;
    invoiceNotificationTarget.addListener(_requestInvoiceOpen);
    _messageSubscription = NotificationService().onMessageReceived.listen((
      message,
    ) {
      final type = message.data['type']?.toString().toUpperCase();
      if (type == 'PACKAGE' &&
          mounted &&
          _foreground &&
          context.read<AuthProvider>().isLoggedIn) {
        _refreshAccountData();
        final provider = context.read<ServicePackageProvider>();
        provider.loadMine();
        final id = int.tryParse(message.data['purchaseId']?.toString() ?? '');
        if (id != null && id > 0) provider.loadDetail(id);
      }
      if (type == 'INVOICE' ||
          type == 'HOADON' ||
          type == 'APPOINTMENT' ||
          type == 'LICHHEN') {
        _refreshAccountData();
        final id = int.tryParse(message.data['invoiceId']?.toString() ?? '');
        if (mounted &&
            _foreground &&
            context.read<AuthProvider>().isLoggedIn &&
            id != null &&
            id > 0) {
          context.read<InvoiceProvider>().loadDetail(id);
        }
      }
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshAccountData(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogProvider>().load();
      context.read<ServicePackageProvider>().loadCatalog();
      _requestInvoiceOpen();
      PromoBannerDialog.showIfFirstTime(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountId = context.watch<AuthProvider>().account?.id;
    if (accountId == _accountId) return;
    if (accountId == null && _accountId != null) {
      invoiceNotificationTarget.value = null;
    }
    _accountId = accountId;
    _accountEpoch++;
    _refreshing = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAccountData();
      _requestInvoiceOpen();
    });
  }

  Future<void> _refreshAccountData() async {
    if (!mounted ||
        !_foreground ||
        _refreshing ||
        !context.read<AuthProvider>().isLoggedIn) {
      return;
    }
    final epoch = _accountEpoch;
    _refreshing = true;
    try {
      await Future.wait([
        context.read<AppointmentProvider>().load(),
        context.read<ProfileProvider>().load(),
        context.read<NotificationProvider>().fetchUnreadCount(),
        context.read<InvoiceProvider>().refreshPending(),
      ]);
    } finally {
      if (epoch == _accountEpoch) _refreshing = false;
    }
  }

  void _requestInvoiceOpen() {
    if (!mounted || invoiceNotificationTarget.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          _openingInvoice ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
      final target = invoiceNotificationTarget.value;
      if (target == null) return;
      invoiceNotificationTarget.value = null;
      _openingInvoice = true;
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceNotificationScreen(target: target),
          ),
        );
      } finally {
        if (mounted) {
          _openingInvoice = false;
          _requestInvoiceOpen();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _refreshAccountData();
      _requestInvoiceOpen();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageSubscription?.cancel();
    invoiceNotificationTarget.removeListener(_requestInvoiceOpen);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mainTab,
      builder: (context, index, _) {
        return Scaffold(
          extendBody: true,
          floatingActionButton:
              index == 0 &&
                  _homeSupportVisible &&
                  MediaQuery.viewInsetsOf(context).bottom == 0
              ? const HomeSupportButtons()
              : null,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: index,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0 &&
                        notification.metrics.axis == Axis.vertical) {
                      final visible = notification.metrics.pixels <= 12;
                      if (visible != _homeSupportVisible) {
                        setState(() => _homeSupportVisible = visible);
                      }
                    }
                    return false;
                  },
                  child: const HomeScreen(),
                ),
                const ServicesScreen(),
                const AppointmentsScreen(),
                const OffersScreen(),
                const AccountScreen(),
              ],
            ),
          ),
          bottomNavigationBar: SpaBottomNavigation(
            tab: index,
            onBook: () async {
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
            onTab: (i) async {
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
          ),
        );
      },
    );
  }
}
