import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:app_doancunhan/core/format.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/service_detail_screen.dart';

void main() {
  testWidgets('CAT05 detail displays the selected name price and duration', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'items': [], 'totalReviews': 0}));
    }));
    final provider = CatalogProvider(dio: dio);
    const service = Service(id: 1, categoryId: 1, name: 'Dịch vụ kiểm thử CAT05', price: 300000, durationMinutes: 45);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: provider, child: const MaterialApp(home: ServiceDetailScreen(service: service))));
    await tester.pumpAndSettle();
    expect(find.text(service.name), findsOneWidget);
    expect(find.text(vnd(service.price)), findsOneWidget);
    expect(find.text(durationStr(service.durationMinutes)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
