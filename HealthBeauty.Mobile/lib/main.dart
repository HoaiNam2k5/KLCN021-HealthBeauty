import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/service_package_provider.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProxyProvider<AuthProvider, CatalogProvider>(
          create: (_) => CatalogProvider(),
          update: (_, auth, previous) =>
              (previous ?? CatalogProvider())..bind(auth.account?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, AppointmentProvider>(
          create: (_) => AppointmentProvider(),
          update: (_, auth, prev) =>
              (prev ?? AppointmentProvider())..bind(auth.account?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(),
          update: (_, auth, prev) =>
              (prev ?? ProfileProvider())..bind(auth.account?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, InvoiceProvider>(
          create: (_) => InvoiceProvider(),
          update: (_, auth, previous) =>
              (previous ?? InvoiceProvider())..bind(auth.account?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ServicePackageProvider>(
          create: (_) => ServicePackageProvider(),
          update: (_, auth, previous) =>
              (previous ?? ServicePackageProvider())..bind(auth.account?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, prev) =>
              (prev ?? NotificationProvider())..bind(auth.account?.id),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthbeauty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const MainShell();
  }
}
