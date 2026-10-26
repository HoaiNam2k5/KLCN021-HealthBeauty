import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/service_package_provider.dart';
import 'package:app_doancunhan/screens/package_payment_screen.dart';

import 'service_packages_test.dart' as fixtures;
import 'invoice_lifecycle_test.dart' show customer;

Map<String, dynamic> instructions({
  int id = 3,
  int amount = 500000,
  String url = 'https://vietqr.app/img',
}) => {
  'purchaseId': id,
  'amount': amount,
  'status': 'Pending',
  'bankName': 'MBBank',
  'bankCode': 'MBBank',
  'accountNumber': '12345678',
  'accountName': 'TEST',
  'transferContent': 'HP3',
  'qrImageUrl': url,
};
Map<String, dynamic> detail({String status = 'Pending'}) {
  final package = fixtures.purchase(status: status);
  if (status == 'Paid') {
    package['paidAt'] = DateTime.now().toIso8601String();
    package['expiresAt'] = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String();
    (package['items'] as List)[0]['available'] = 5;
  }
  return {'package': package, 'history': []};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'QR request is purchase-scoped and cannot activate an unpaid package',
    () async {
      final provider = ServicePackageProvider(
        dio: fixtures.transport((r) {
          if (r.method == 'GET') return detail();
          expect(r.path, '/service-packages/purchases/3/bank-transfer');
          expect(r.extra.containsKey('sessionGeneration'), true);
          expect(r.data, null);
          return instructions();
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.loadDetail(3);
      expect(await provider.requestTransfer(3), true);
      expect(provider.transfers[3]?.transferContent, 'HP3');
      expect(provider.mine.single.status, 'Pending');
      expect(provider.mine.single.canUseAt(DateTime.now()), false);
    },
  );

  test('invalid purchase, amount and insecure QR are rejected', () async {
    for (final response in [
      instructions(id: 99),
      instructions(amount: 1),
      instructions(url: 'http://example.com/qr'),
      instructions(url: 'https://untrusted.example/qr'),
      {...instructions(), 'transferContent': 'HB3'},
      {...instructions(), 'transferContent': 'HP99'},
    ]) {
      final provider = ServicePackageProvider(
        dio: fixtures.transport((r) => r.method == 'GET' ? detail() : response),
      )..bind(1);
      await provider.loadDetail(3);
      expect(await provider.requestTransfer(3), false);
      expect(provider.transfers, isEmpty);
      expect(provider.transferErrors[3], isNotNull);
      provider.dispose();
    }
  });

  test('late QR is discarded after account switch', () async {
    final started = Completer<void>(), result = Completer<dynamic>();
    final provider = ServicePackageProvider(
      dio: fixtures.transport((r) {
        if (r.method == 'GET') return detail();
        started.complete();
        return result.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    await provider.loadDetail(3);
    final request = provider.requestTransfer(3);
    await started.future;
    provider.bind(2);
    result.complete(instructions());
    expect(await request, false);
    expect(provider.transfers, isEmpty);
    expect(provider.loadingTransfers, isEmpty);
    expect(provider.mine, isEmpty);
  });

  test('server payment confirmation alone activates purchase and removes instructions', () async {
    var paid = false;
    final provider = ServicePackageProvider(
      dio: fixtures.transport(
        (r) => r.method == 'GET'
            ? detail(status: paid ? 'Paid' : 'Pending')
            : instructions(),
      ),
    )..bind(1);
    addTearDown(provider.dispose);
    await provider.loadDetail(3);
    await provider.requestTransfer(3);
    paid = true;
    await provider.loadDetail(3);
    expect(provider.transfers, isEmpty);
    expect(provider.mine.single.canUseAt(DateTime.now()), true);
    expect(await provider.requestTransfer(3), false);
  });

  testWidgets(
    'foreground QR polling observes activation and stops with paid UI',
    (tester) async {
      var paid = false, reads = 0;
      final dio = fixtures.transport((r) {
        if (r.method == 'GET') {
          reads++;
          return detail(status: paid ? 'Paid' : 'Pending');
        }
        return instructions();
      });
      final provider = ServicePackageProvider(dio: dio)..bind(1);
      final auth = customer(dio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ServicePackageProvider>.value(
              value: provider,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: PackagePaymentScreen(purchaseId: 3)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra thanh toán'), findsOneWidget);
      expect(find.text('Thanh toán thành công'), findsNothing);
      paid = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(find.text('Kiểm tra thanh toán'), findsNothing);
      final after = reads;
      await tester.pump(const Duration(seconds: 20));
      expect(reads, after);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      auth.dispose();
    },
  );
}
