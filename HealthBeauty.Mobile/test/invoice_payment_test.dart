import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/models/invoice.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/invoice_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/screens/invoice_detail_screen.dart';
import 'package:app_doancunhan/screens/invoices_screen.dart';

Map<String, dynamic> invoice({
  int id = 42,
  String status = 'ChuaThanhToan',
  num total = 250000,
}) => {
  'id': id,
  'appointmentId': 7,
  'customerId': 1,
  'createdAt': '2026-10-25T10:00:00',
  'subtotal': 300000,
  'total': total,
  'status': status,
  'items': [
    {
      'serviceId': 3,
      'serviceName': 'Chăm sóc da',
      'comboName': null,
      'quantity': 1,
      'unitPrice': 300000,
    },
  ],
  'payments': status == 'DaThanhToan' && total > 0
      ? [
          {
            'method': 'ChuyenKhoan',
            'amount': total,
            'paidAt': '2026-10-25T10:05:00',
            'status': 'ThanhCong',
          },
        ]
      : [],
};

Map<String, dynamic> instructions({
  num amount = 250000,
  String url = 'https://vietqr.app/img',
}) => {
  'invoiceId': 42,
  'amount': amount,
  'status': 'ChuaThanhToan',
  'bankName': 'Test bank',
  'bankCode': 'TEST',
  'accountNumber': '12345678',
  'accountName': 'Test spa',
  'transferContent': 'HB42',
  'qrImageUrl': url,
};

Dio transport(FutureOr<dynamic> Function(RequestOptions) reply) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        try {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: await reply(request),
            ),
          );
        } on DioException catch (error) {
          handler.reject(error);
        } catch (error) {
          handler.reject(DioException(requestOptions: request, error: error));
        }
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'history paginates own endpoint without supplying customer identity',
    () async {
      final offsets = <int>[];
      final provider = InvoiceProvider(
        dio: transport((request) {
          expect(request.path, '/invoices');
          expect(
            request.queryParameters.keys,
            unorderedEquals(['offset', 'limit']),
          );
          expect(request.extra, contains('sessionGeneration'));
          final offset = request.queryParameters['offset'] as int;
          offsets.add(offset);
          return offset == 0
              ? List.generate(50, (index) => invoice(id: 100 - index))
              : [invoice(id: 50)];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.invoices.length, 50);
      expect(provider.hasMore, true);
      await provider.load(more: true);
      expect(offsets, [0, 50]);
      expect(provider.invoices.length, 51);
      expect(provider.hasMore, false);
    },
  );

  test(
    'late old-account invoice detail is discarded and caches reset',
    () async {
      final started = Completer<void>(), finish = Completer<dynamic>();
      final provider = InvoiceProvider(
        dio: transport((_) {
          started.complete();
          return finish.future;
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      final pending = provider.loadDetail(42);
      await started.future;
      provider.bind(2);
      finish.complete(invoice());
      expect(await pending, null);
      expect(provider.details, isEmpty);
      expect(provider.transfers, isEmpty);
      expect(provider.loadingDetails, isEmpty);
    },
  );

  test(
    'QR creation never self-confirms payment and server status removes QR',
    () async {
      var paid = false;
      final requests = <String>[];
      final provider = InvoiceProvider(
        dio: transport((request) {
          requests.add('${request.method} ${request.path}');
          return request.method == 'POST'
              ? instructions()
              : invoice(status: paid ? 'DaThanhToan' : 'ChuaThanhToan');
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.loadDetail(42);
      expect(await provider.requestTransfer(42), true);
      expect(provider.details[42]!.isPaid, false);
      expect(provider.transfers[42]!.transferContent, 'HB42');
      paid = true;
      await provider.loadDetail(42);
      expect(provider.details[42]!.isPaid, true);
      expect(provider.transfers, isEmpty);
      expect(await provider.requestTransfer(42), false);
      expect(requests, [
        'GET /invoices/42',
        'POST /invoices/42/bank-transfer',
        'GET /invoices/42',
      ]);
    },
  );

  test(
    'disabled integration displays actionable message and no bank details',
    () async {
      final provider = InvoiceProvider(
        dio: transport((request) {
          if (request.method == 'POST') {
            throw DioException(
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 503),
            );
          }
          return invoice();
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.loadDetail(42);
      expect(await provider.requestTransfer(42), false);
      expect(provider.transfers, isEmpty);
      expect(provider.transferErrors[42], contains('liên hệ lễ tân'));
    },
  );

  test('amount mismatch or insecure QR is rejected', () async {
    for (final bad in [
      instructions(amount: 1),
      instructions(url: 'http://unsafe.test/qr'),
    ]) {
      final provider = InvoiceProvider(
        dio: transport((request) => request.method == 'POST' ? bad : invoice()),
      )..bind(1);
      await provider.loadDetail(42);
      expect(await provider.requestTransfer(42), false);
      expect(provider.transfers, isEmpty);
      provider.dispose();
    }
  });

  test(
    'zero-value invoice and anonymous access cannot create bank transfer',
    () async {
      var calls = 0;
      final provider = InvoiceProvider(
        dio: transport((_) {
          calls++;
          return invoice(total: 0);
        }),
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(await provider.loadDetail(42), null);
      expect(await provider.requestTransfer(42), false);
      expect(calls, 0);
      provider.bind(1);
      await provider.loadDetail(42);
      expect(await provider.requestTransfer(42), false);
      expect(calls, 1);
      expect(CustomerInvoice.fromJson(invoice(total: 0)).canTransfer, false);
    },
  );

  test(
    'late QR response cannot leak bank instructions to a different account',
    () async {
      final started = Completer<void>(), finish = Completer<dynamic>();
      final provider = InvoiceProvider(
        dio: transport((request) {
          if (request.method == 'GET') return invoice();
          started.complete();
          return finish.future;
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.loadDetail(42);
      final pending = provider.requestTransfer(42);
      await started.future;
      provider.bind(null);
      finish.complete(instructions());
      expect(await pending, false);
      expect(provider.transfers, isEmpty);
      expect(provider.loadingTransfers, isEmpty);
    },
  );

  testWidgets('reopening pending QR polls until the server confirms payment', (
    tester,
  ) async {
    var paid = false;
    var detailReads = 0;
    final dio = transport((request) {
      if (request.method == 'POST') return instructions();
      detailReads++;
      return invoice(status: paid ? 'DaThanhToan' : 'ChuaThanhToan');
    });
    final provider = InvoiceProvider(dio: dio)..bind(1);
    await tester.runAsync(() async {
      await provider.loadDetail(42);
      await provider.requestTransfer(42);
    });
    final auth =
        AuthProvider(
            client: ApiClient.withDio(dio: dio, refreshDio: dio),
          )
          ..account = Account.fromJson({
            'id': 1,
            'email': 'test@example.com',
            'role': 'Customer',
          });
    final profile = ProfileProvider(dio: dio);
    final appointments = AppointmentProvider(dio: dio);
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
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: appointments),
        ],
        child: const MaterialApp(home: InvoiceDetailScreen(invoiceId: 42)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán thành công'), findsNothing);
    expect(detailReads, 2);
    paid = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(detailReads, 3);
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(provider.transfers, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), null);
  });

  testWidgets(
    'history opens invoice detail and paid receipt has no transfer action',
    (tester) async {
      final dio = transport(
        (request) => request.path == '/invoices'
            ? [invoice(status: 'DaThanhToan')]
            : invoice(status: 'DaThanhToan'),
      );
      final provider = InvoiceProvider(dio: dio)..bind(1);
      final auth =
          AuthProvider(
              client: ApiClient.withDio(dio: dio, refreshDio: dio),
            )
            ..account = Account.fromJson({
              'id': 1,
              'email': 'test@example.com',
              'role': 'Customer',
            });
      final profile = ProfileProvider(dio: dio);
      final appointments = AppointmentProvider(dio: dio);
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
            ChangeNotifierProvider.value(value: profile),
            ChangeNotifierProvider.value(value: appointments),
          ],
          child: const MaterialApp(home: InvoicesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HD000042'), findsOneWidget);
      await tester.tap(find.text('HD000042'));
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceDetailScreen), findsOneWidget);
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(find.text('Thanh toán chuyển khoản'), findsNothing);
      expect(find.text('Chăm sóc da'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
