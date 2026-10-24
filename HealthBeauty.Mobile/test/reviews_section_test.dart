import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/service_detail_screen.dart';

void main() {
  testWidgets('ServiceDetailScreen displays review section', (tester) async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('/reviews')) {
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'averageRating': 4.5,
              'totalReviews': 2,
              'items': [
                {
                  'danhGiaId': 4,
                  'hoaDonId': 7,
                  'soSao': 4,
                  'binhLuan': 'tam on',
                  'ngayDanhGia': '2026-10-22T21:05:10',
                  'tenKhachHang': 'Nghia',
                },
                {
                  'danhGiaId': 3,
                  'hoaDonId': 6,
                  'soSao': 5,
                  'binhLuan': 'ok',
                  'ngayDanhGia': '2026-10-22T20:45:04',
                  'tenKhachHang': 'Nghia',
                },
              ],
            },
          ));
        }
        handler.next(options);
      },
    ));

    final catalogProvider = CatalogProvider(dio: dio);

    const service = Service(
      id: 1,
      categoryId: 1,
      name: 'Chăm sóc da chuyên sâu',
      price: 650000,
      durationMinutes: 75,
      description: 'Mô tả thử nghiệm',
      averageRating: 4.5,
      totalReviews: 2,
      bookedCount: 2,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: catalogProvider),
        ],
        child: const MaterialApp(
          home: ServiceDetailScreen(service: service),
        ),
      ),
    );

    expect(find.text('Chăm sóc da chuyên sâu'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Đánh giá & Nhận xét'), findsOneWidget);
    expect(find.text('Nghia'), findsNWidgets(2));
    expect(find.text('tam on'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
