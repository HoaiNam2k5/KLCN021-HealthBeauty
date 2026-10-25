import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/core/invoice_navigation.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/invoice_provider.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/providers/notification_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';
import 'package:app_doancunhan/providers/service_package_provider.dart';
import 'package:app_doancunhan/screens/invoice_detail_screen.dart';
import 'package:app_doancunhan/screens/invoice_notification_screen.dart';
import 'package:app_doancunhan/screens/main_shell.dart';
import 'package:app_doancunhan/widgets/pending_invoice_reminder.dart';

import 'invoice_payment_test.dart' as fixtures;

AuthProvider customer(Dio dio) =>
    AuthProvider(
        client: ApiClient.withDio(dio: dio, refreshDio: dio),
      )
      ..account = Account.fromJson({
        'id': 1,
        'email': 'test@example.com',
        'role': 'Customer',
      });

class _Appointments extends AppointmentProvider {
  int refreshes = 0;
  @override
  Future<void> load() async {
    refreshes++;
  }
}

class _Profile extends ProfileProvider {
  @override
  Future<void> load() async {}
}

class _Catalog extends CatalogProvider {
  _Catalog() {
    loaded = true;
  }
  @override
  Future<void> load({bool force = false}) async {}
}

class _Notifications extends NotificationProvider {
  @override
  Future<void> fetchUnreadCount() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    invoiceNotificationTarget.value = null;
  });

  test(
    'pending query finds unpaid invoices independently of latest history page',
    () async {
      final provider = InvoiceProvider(
        dio: fixtures.transport((r) {
          expect(r.path, '/invoices');
          expect(r.queryParameters, {
            'status': 'ChuaThanhToan',
            'offset': 0,
            'limit': 1,
          });
          return [fixtures.invoice(id: 2)];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.refreshPending();
      expect(provider.pendingInvoice?.id, 2);
      expect(provider.pendingInvoice?.statusLabel, 'Chờ thanh toán');
      expect(provider.invoices, isEmpty);
      provider.bind(null);
      expect(provider.pendingInvoice, null);
    },
  );

  test('late pending response cannot leak another account invoice', () async {
    final started = Completer<void>(), finish = Completer<dynamic>();
    final provider = InvoiceProvider(
      dio: fixtures.transport((_) {
        started.complete();
        return finish.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.refreshPending();
    await started.future;
    provider.bind(2);
    finish.complete([fixtures.invoice()]);
    await pending;
    expect(provider.pendingInvoice, null);
    expect(provider.pendingLoading, false);
  });

  test('late unpaid summary cannot restore banner after server detail confirms paid', () async {
    final started = Completer<void>(), finish = Completer<dynamic>();
    final provider = InvoiceProvider(
      dio: fixtures.transport((r) {
        if (r.path == '/invoices') {
          started.complete();
          return finish.future;
        }
        return fixtures.invoice(status: 'DaThanhToan');
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.refreshPending();
    await started.future;
    await provider.loadDetail(42);
    finish.complete([fixtures.invoice()]);
    await pending;
    expect(provider.pendingInvoice, null);
  });

  test('appointment notification lookup uses owned server filter and drops stale account response', () async {
    final started = Completer<void>(), finish = Completer<dynamic>();
    final provider = InvoiceProvider(
      dio: fixtures.transport((r) {
        expect(r.queryParameters, {
          'appointmentId': 7,
          'offset': 0,
          'limit': 1,
        });
        started.complete();
        return finish.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.findForAppointment(7);
    await started.future;
    provider.bind(2);
    finish.complete([fixtures.invoice()]);
    expect(await pending, null);
  });

  test('invoice notification target supports committed invoice and atomic appointment IDs', () {
    expect(
      InvoiceNotificationTarget.fromPayload({
        'type': 'INVOICE',
        'invoiceId': '42',
      })?.invoiceId,
      42,
    );
    final target = InvoiceNotificationTarget.fromPayload({
      'type': 'INVOICE',
      'appointmentId': '7',
      'invoiceId': '0',
    });
    expect(target?.invoiceId, null);
    expect(target?.appointmentId, 7);
    expect(
      InvoiceNotificationTarget.fromPayload({
        'type': 'APPOINTMENT',
        'appointmentId': '7',
      }),
      null,
    );
  });

  testWidgets('home reminder disappears when payment is confirmed', (
    tester,
  ) async {
    var paid = false;
    final dio = fixtures.transport(
      (r) => r.path == '/invoices'
          ? [fixtures.invoice()]
          : fixtures.invoice(status: paid ? 'DaThanhToan' : 'ChuaThanhToan'),
    );
    final provider = InvoiceProvider(dio: dio)..bind(1);
    final auth = customer(dio);
    addTearDown(() {
      provider.dispose();
      auth.dispose();
    });
    await tester.runAsync(provider.refreshPending);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PendingInvoiceReminder()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn có hóa đơn chờ thanh toán'), findsOneWidget);
    expect(find.textContaining('HD000042'), findsOneWidget);
    paid = true;
    await tester.runAsync(() => provider.loadDetail(42));
    await tester.pumpAndSettle();
    expect(find.text('Bạn có hóa đơn chờ thanh toán'), findsNothing);
  });

  testWidgets(
    'pending invoice notification resolves appointment to actual invoice detail',
    (tester) async {
      final requests = <String>[];
      final dio = fixtures.transport((r) {
        requests.add(r.path);
        if (r.path == '/invoices') {
          expect(r.queryParameters['appointmentId'], 7);
          return [fixtures.invoice(status: 'DaThanhToan')];
        }
        return fixtures.invoice(status: 'DaThanhToan');
      });
      final provider = InvoiceProvider(dio: dio)..bind(1);
      final auth = customer(dio),
          profile = _Profile(),
          appointments = _Appointments();
      addTearDown(() {
        provider.dispose();
        auth.dispose();
        profile.dispose();
        appointments.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider<ProfileProvider>.value(value: profile),
            ChangeNotifierProvider<AppointmentProvider>.value(
              value: appointments,
            ),
          ],
          child: const MaterialApp(
            home: InvoiceNotificationScreen(
              target: InvoiceNotificationTarget(appointmentId: 7),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
      expect(find.text('HD000042'), findsOneWidget);
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(requests, ['/invoices', '/invoices/42']);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'main shell refreshes pending invoices while visible and on resume, not in background',
    (tester) async {
      var pendingReads = 0;
      final dio = fixtures.transport((r) {
        pendingReads++;
        return <Object>[];
      });
      final provider = InvoiceProvider(dio: dio)..bind(1);
      final auth = customer(dio),
          profile = _Profile(),
          appointments = _Appointments();
      final catalog = _Catalog(),
          notices = _Notifications(),
          packages = ServicePackageProvider(dio: dio);
      addTearDown(() {
        provider.dispose();
        auth.dispose();
        profile.dispose();
        appointments.dispose();
        catalog.dispose();
        notices.dispose();
        packages.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider<ProfileProvider>.value(value: profile),
            ChangeNotifierProvider<AppointmentProvider>.value(
              value: appointments,
            ),
            ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
            ChangeNotifierProvider<NotificationProvider>.value(value: notices),
            ChangeNotifierProvider.value(value: packages),
          ],
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();
      expect(pendingReads, 1);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(pendingReads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(pendingReads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();
      expect(pendingReads, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), null);
    },
  );
}
