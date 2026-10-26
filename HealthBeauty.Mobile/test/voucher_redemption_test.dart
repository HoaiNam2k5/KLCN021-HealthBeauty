import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/core/token_storage.dart';
import 'package:app_doancunhan/models/customer.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/screens/offers_screen.dart';

import 'invoice_payment_test.dart' show transport;

Map<String, dynamic> offer() => {
  'id': 1,
  'promotionId': 1,
  'promotionName': 'Care',
  'discountValue': 50000,
  'pointsCost': 100,
  'expiresAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
};
Map<String, dynamic> wallet() => {
  'voucherId': 1,
  'maCode': 'NEW',
  'giaTriGiam': 50000,
  'hanSuDung': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'trangThai': true,
};
Map<String, dynamic> redemption() => {
  'voucherId': 1,
  'code': 'NEW',
  'pointsSpent': 100,
  'remainingPoints': 400,
};
Map<String, dynamic> profileJson(int balance) => {
  'id': 1,
  'fullName': 'Owner',
  'rewardPoints': balance,
};

class _Auth extends AuthProvider {
  @override
  bool get isLoggedIn => true;
}

void main() {
  test('redemption sends the exact confirmed cost and rejects stale account consent', () async {
    var posts = 0;
    final catalog = CatalogProvider(
      dio: transport((request) {
        if (request.method == 'POST') {
          posts++;
          expect(request.data, {'expectedPointsCost': 100});
          expect(
            request.extra['sessionGeneration'],
            TokenStorage.sessionGeneration,
          );
          return redemption();
        }
        return [];
      }),
    );
    addTearDown(catalog.dispose);
    catalog.bind(1);
    final version = catalog.accountVersion;
    final result = await catalog.redeemVoucher(
      1,
      expectedPointsCost: 100,
      expectedAccountVersion: version,
    );
    expect(result?.remainingPoints, 400);
    catalog.bind(2);
    expect(
      await catalog.redeemVoucher(
        1,
        expectedPointsCost: 100,
        expectedAccountVersion: version,
      ),
      isNull,
    );
    expect(posts, 1);
  });

  test(
    'wallet request from before redemption cannot overwrite fresh wallet',
    () async {
      var slow = false, redeemed = false;
      final old = Completer<dynamic>(), started = Completer<void>();
      final catalog = CatalogProvider(
        dio: transport((request) {
          if (request.method == 'POST') {
            redeemed = true;
            return redemption();
          }
          if (request.path == '/customers/me/vouchers') {
            if (slow && !redeemed) {
              if (!started.isCompleted) started.complete();
              return old.future;
            }
            return redeemed ? [wallet()] : [];
          }
          return [];
        }),
      );
      addTearDown(catalog.dispose);
      catalog.bind(1);
      await Future<void>.delayed(Duration.zero);
      slow = true;
      final oldRead = catalog.loadMyVouchers(force: true);
      await started.future;
      await catalog.redeemVoucher(
        1,
        expectedPointsCost: 100,
        expectedAccountVersion: catalog.accountVersion,
      );
      expect(catalog.myVouchers.single.code, 'NEW');
      old.complete([]);
      await oldRead;
      expect(catalog.myVouchers.single.code, 'NEW');
    },
  );

  for (final status in [400, 404, 409]) {
    test(
      'redemption failure$status reconciles wallet without repeating POST',
      () async {
        var posts = 0, walletReads = 0;
        final catalog = CatalogProvider(
          dio: transport((request) {
            if (request.method == 'POST') {
              posts++;
              throw DioException(
                requestOptions: request,
                response: Response(requestOptions: request, statusCode: status),
              );
            }
            if (request.path == '/customers/me/vouchers') walletReads++;
            return [];
          }),
        );
        addTearDown(catalog.dispose);
        catalog.bind(1);
        expect(
          await catalog.redeemVoucher(
            1,
            expectedPointsCost: 100,
            expectedAccountVersion: catalog.accountVersion,
          ),
          isNull,
        );
        expect(posts, 1);
        expect(walletReads, greaterThan(0));
        expect(catalog.offerError, isNotEmpty);
      },
    );
  }

  test(
    'confirmed point balance survives a late pre-redemption profile response',
    () async {
      final old = Completer<dynamic>(), started = Completer<void>();
      var reads = 0;
      final profile = ProfileProvider(
        dio: transport((request) {
          if (request.path == '/customers/me') {
            if (++reads == 1) {
              started.complete();
              return old.future;
            }
            return profileJson(400);
          }
          return {'transactions': []};
        }),
      );
      addTearDown(profile.dispose);
      profile.bind(1);
      profile.customer = const Customer(
        id: 1,
        fullName: 'Owner',
        rewardPoints: 500,
      );
      final oldRead = profile.load();
      await started.future;
      await profile.refreshAfterVoucherRedemption(
        expectedAccountId: 1,
        expectedSession: TokenStorage.sessionGeneration,
        confirmedRemainingPoints: 400,
      );
      expect(profile.customer?.rewardPoints, 400);
      old.complete(profileJson(500));
      await oldRead;
      expect(profile.customer?.rewardPoints, 400);
      expect(profile.loading, false);
    },
  );

  test('lost redemption response reconciles the claimed voucher without a second POST', () async {
    var posts = 0, committed = false;
    final catalog = CatalogProvider(
      dio: transport((request) {
        if (request.method == 'POST') {
          posts++;
          committed = true;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        if (request.path == '/customers/me/vouchers') {
          return committed ? [wallet()] : [];
        }
        return [];
      }),
    );
    addTearDown(catalog.dispose);
    catalog.bind(1);
    expect(
      await catalog.redeemVoucher(
        1,
        expectedPointsCost: 100,
        expectedAccountVersion: catalog.accountVersion,
      ),
      isNull,
    );
    expect(posts, 1);
    expect(catalog.myVouchers.single.code, 'NEW');
    expect(catalog.offerError, contains('Chưa xác nhận'));
  });

  testWidgets('switching accounts while confirmation is open never redeems', (
    tester,
  ) async {
    var posts = 0;
    final catalog = CatalogProvider(
      dio: transport((request) {
        if (request.method == 'POST') {
          posts++;
          return redemption();
        }
        return request.path.endsWith('voucher-offers') ? [offer()] : [];
      }),
    );
    final profile = ProfileProvider(
      dio: transport(
        (request) => request.path == '/customers/me'
            ? profileJson(500)
            : {'transactions': []},
      ),
    );
    final auth = _Auth();
    catalog.bind(1);
    profile.bind(1);
    profile.customer = const Customer(
      id: 1,
      fullName: 'Owner',
      rewardPoints: 500,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: Scaffold(body: OffersScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đổi ngay'));
    await tester.tap(find.text('Đổi ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận đổi voucher'), findsOneWidget);
    catalog.bind(2);
    profile.bind(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận đổi'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.pumpWidget(const SizedBox());
    catalog.dispose();
    profile.dispose();
    auth.dispose();
  });
}
