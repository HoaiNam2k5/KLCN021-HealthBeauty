import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/providers/service_package_provider.dart';

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
        } catch (error) {
          handler.reject(DioException(requestOptions: request, error: error));
        }
      },
    ),
  );
  return dio;
}

Map<String, dynamic> purchase({String status = 'Pending'}) => {
  'id': 3,
  'servicePackageId': 2,
  'customerId': 9,
  'name': 'Gói',
  'price': 500000,
  'validityDays': 30,
  'status': status,
  'createdAt': '2026-10-24T10:00:00',
  'paidAt': null,
  'expiresAt': null,
  'paymentMethod': null,
  'items': [
    {
      'id': 11,
      'serviceId': 7,
      'serviceName': 'Da',
      'granted': 5,
      'reserved': 0,
      'used': 0,
      'remaining': 5,
      'available': 0,
    },
  ],
};
void main() {
  test(
    'purchase sends only catalog id and never self-confirms payment',
    () async {
      final provider = ServicePackageProvider(
        dio: transport((request) {
          expect(request.method, 'POST');
          expect(request.path, '/service-packages/purchases');
          expect(request.data, {'packageId': 2});
          expect(request.extra.containsKey('sessionGeneration'), true);
          return purchase();
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      final result = await provider.purchase(2);
      expect(result?.status, 'Pending');
      expect(provider.mine.single.id, 3);
      expect(provider.purchasing, false);
    },
  );
  test(
    'mine endpoint is own purchases and account change clears cache',
    () async {
      final provider = ServicePackageProvider(
        dio: transport((r) {
          expect(r.path, '/service-packages/mine');
          return [purchase()];
        }),
      )..bind(1);
      addTearDown(provider.dispose);
      await provider.loadMine();
      expect(provider.mine.length, 1);
      provider.bind(2);
      expect(provider.mine, isEmpty);
      expect(provider.details, isEmpty);
    },
  );
  test('late old-account purchase cannot populate new-account cache', () async {
    final started = Completer<void>();
    final finish = Completer<dynamic>();
    final provider = ServicePackageProvider(
      dio: transport((_) {
        started.complete();
        return finish.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final pending = provider.purchase(2);
    await started.future;
    provider.bind(2);
    finish.complete(purchase());
    expect(await pending, null);
    expect(provider.mine, isEmpty);
    expect(provider.purchasing, false);
  });
  test('double tap does not duplicate purchase', () async {
    final started = Completer<void>();
    final finish = Completer<dynamic>();
    var calls = 0;
    final provider = ServicePackageProvider(
      dio: transport((_) {
        calls++;
        started.complete();
        return finish.future;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final first = provider.purchase(2);
    await started.future;
    expect(await provider.purchase(2), null);
    finish.complete(purchase());
    expect(await first, isNotNull);
    expect(calls, 1);
  });
  test('detail reads package/history wrapper and snapshot balance', () async {
    final provider = ServicePackageProvider(
      dio: transport((r) {
        expect(r.path, '/service-packages/purchases/3');
        return {'package': purchase(), 'history': []};
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    final result = await provider.loadDetail(3);
    expect(result?.package.items.single.remaining, 5);
    expect(provider.details[3], same(result));
  });
  test('pending cancellation uses DELETE and removes stale detail', () async {
    final provider = ServicePackageProvider(
      dio: transport((r) {
        expect(r.method, 'DELETE');
        expect(r.path, '/service-packages/purchases/3');
        return null;
      }),
    )..bind(1);
    addTearDown(provider.dispose);
    expect(await provider.cancelPurchase(3), true);
    expect(provider.cancelling, false);
    expect(provider.details, isEmpty);
  });
  test('unauthenticated user cannot send purchases', () async {
    var calls = 0;
    final provider = ServicePackageProvider(
      dio: transport((_) {
        calls++;
        return purchase();
      }),
    );
    addTearDown(provider.dispose);
    expect(await provider.purchase(2), null);
    expect(await provider.cancelPurchase(3), false);
    expect(calls, 0);
  });
}
