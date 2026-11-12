import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/providers/profile_provider.dart';
import 'package:app_doancunhan/screens/account_screen.dart';
import 'package:app_doancunhan/screens/service_detail_screen.dart';

Map<String, dynamic> legacyService(int id) => {
  'id': id,
  'categoryId': 1,
  'name': 'Dịch vụ $id',
  'price': 300000,
  'durationMinutes': 45,
};
Map<String, dynamic> summary([int count = 1]) => {
  'averageRating': count == 0 ? 0 : 5,
  'totalReviews': count,
  'items': count == 0
      ? []
      : [
          {
            'danhGiaId': 1,
            'hoaDonId': 1,
            'soSao': 5,
            'binhLuan': 'Dịch vụ rất tốt',
            'ngayDanhGia': '2026-10-27T10:00:00',
            'tenKhachHang': 'Khách thử nghiệm',
          },
        ],
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('old review response cannot overwrite a newer catalog', () async {
    final dio = Dio();
    final started = Completer<void>();
    final release = Completer<void>();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          if (r.path == '/reviews') {
            started.complete();
            await release.future;
            return h.resolve(Response(requestOptions: r, data: summary(1)));
          }
          h.resolve(
            Response(
              requestOptions: r,
              data: r.path == '/services'
                  ? [
                      {
                        ...legacyService(1),
                        'averageRating': 4.5,
                        'totalReviews': 8,
                        'bookedCount': 10,
                      },
                    ]
                  : [],
            ),
          );
        },
      ),
    );
    final p = CatalogProvider(dio: dio);
    addTearDown(p.dispose);
    final old = p.loadServiceReviews(1);
    await started.future;
    await p.load(force: true);
    release.complete();
    await old;
    expect(p.services.single.totalReviews, 8);
    expect(p.services.single.averageRating, 4.5);
  });

  test(
    'legacy catalog hydrates real ratings without inventing booking counts',
    () async {
      final dio = Dio();
      var reads = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            Object data = [];
            if (r.path == '/services') data = [legacyService(1)];
            if (r.path == '/reviews') {
              reads++;
              data = summary();
            }
            h.resolve(Response(requestOptions: r, statusCode: 200, data: data));
          },
        ),
      );
      final p = CatalogProvider(dio: dio);
      addTearDown(p.dispose);
      await p.load();
      expect(reads, 1);
      expect(p.services.single.averageRating, 5);
      expect(p.services.single.totalReviews, 1);
      expect(p.services.single.hasReviewStatistics, isTrue);
      expect(p.services.single.hasBookingStatistics, isFalse);
      expect(p.services.single.name, 'Dịch vụ 1');
    },
  );

  test(
    'complete catalog metadata needs no per-service fallback request',
    () async {
      final dio = Dio();
      var reads = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.path == '/reviews') reads++;
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: r.path == '/services'
                    ? [
                        {
                          ...legacyService(1),
                          'totalReviews': 2,
                          'averageRating': 4.5,
                          'bookedCount': 7,
                        },
                      ]
                    : [],
              ),
            );
          },
        ),
      );
      final p = CatalogProvider(dio: dio);
      addTearDown(p.dispose);
      await p.load();
      expect(reads, 0);
      expect(p.services.single.totalReviews, 2);
    },
  );

  test(
    'failed or malformed review requests remain unknown and can retry',
    () async {
      final dio = Dio();
      var attempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (r.path == '/services') {
              return h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: [legacyService(1)],
                ),
              );
            }
            if (r.path == '/reviews') {
              return h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: ++attempts == 1 ? <Object>[] : summary(),
                ),
              );
            }
            h.resolve(Response(requestOptions: r, statusCode: 200, data: []));
          },
        ),
      );
      final p = CatalogProvider(dio: dio);
      addTearDown(p.dispose);
      await p.load();
      expect(p.error, isNull);
      expect(p.services.single.hasReviewStatistics, isFalse);
      await p.loadServiceReviews(1);
      expect(p.services.single.totalReviews, 1);
    },
  );

  test(
    'legacy hydration limits concurrency and shares in-flight review reads',
    () async {
      final dio = Dio();
      final gate = Completer<void>();
      var active = 0, maxActive = 0, reads = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) async {
            if (r.path == '/reviews') {
              reads++;
              active++;
              if (active > maxActive) maxActive = active;
              await gate.future;
              active--;
              return h.resolve(
                Response(requestOptions: r, statusCode: 200, data: summary()),
              );
            }
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: r.path == '/services'
                    ? List.generate(7, (i) => legacyService(i + 1))
                    : [],
              ),
            );
          },
        ),
      );
      final p = CatalogProvider(dio: dio);
      addTearDown(p.dispose);
      final load = p.load();
      for (var i = 0; i < 20 && active < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(active, 3);
      final same = p.loadServiceReviews(1);
      gate.complete();
      await Future.wait([load, same]);
      expect(reads, 7);
      expect(maxActive, 3);
    },
  );

  testWidgets(
    'review failure is not an empty review list and retry loads comments',
    (tester) async {
      final dio = Dio();
      var attempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            if (++attempts == 1) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              h.resolve(
                Response(requestOptions: r, statusCode: 200, data: summary()),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(dio: dio),
          child: const MaterialApp(
            home: ServiceReviewsScreen(
              serviceId: 1,
              serviceName: 'Dịch vụ thử nghiệm',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Không tải được đánh giá. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(find.textContaining('Chưa có đánh giá'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dịch vụ rất tốt'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Dịch vụ rất tốt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('service detail exposes a direct review and comment entry', (
    tester,
  ) async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) => h.resolve(
          Response(requestOptions: r, statusCode: 200, data: summary()),
        ),
      ),
    );
    final catalog = CatalogProvider(dio: dio)
      ..services = [Service.fromJson(legacyService(1))];
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => catalog,
        child: MaterialApp(
          home: ServiceDetailScreen(service: catalog.services.single),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('service_reviews_button')),
      200,
    );
    await tester.tap(find.byKey(const Key('service_reviews_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceReviewsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('membership card fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider()
      ..account = Account.fromJson({
        'id': 1,
        'email': 'test@example.com',
        'role': 'Customer',
      });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => auth),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: AccountScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reviews fit narrow screens with double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) => h.resolve(
          Response(requestOptions: r, statusCode: 200, data: summary()),
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CatalogProvider(dio: dio),
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: ServiceReviewsScreen(
              serviceId: 1,
              serviceName: 'Dịch vụ chăm sóc da chuyên sâu',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
