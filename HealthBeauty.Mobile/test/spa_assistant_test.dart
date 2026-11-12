import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/spa_assistant_screen.dart';
import 'package:app_doancunhan/widgets/home_support_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'assistant uses real catalog links, sends context and retries failures',
    (tester) async {
      final dio = Dio();
      final requests = <Map<String, dynamic>>[];
      var fail = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(Map<String, dynamic>.from(request.data as Map));
            if (fail) {
              return handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionError,
                ),
              );
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'reply': 'Dịch vụ phù hợp',
                  'serviceIds': [1, 999],
                  'comboIds': [],
                },
              ),
            );
          },
        ),
      );
      final catalog = CatalogProvider(dio: dio);
      catalog.services = [
        const Service(
          id: 1,
          categoryId: 1,
          name: 'Chăm sóc da',
          price: 300000,
          durationMinutes: 60,
        ),
      ];
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: catalog,
          child: MaterialApp(home: SpaAssistantScreen(dio: dio)),
        ),
      );
      await tester.tap(find.text('Tư vấn chăm sóc da khô'));
      await tester.pumpAndSettle();
      expect(find.text('Chăm sóc da'), findsOneWidget);
      expect(find.text('Đặt lịch dịch vụ này'), findsOneWidget);
      expect(requests.single['history'], isEmpty);
      fail = true;
      await tester.enterText(find.byType(TextField), 'Tiếp theo');
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect((requests.last['history'] as List).length, 2);
      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(requests.last['message'], 'Tiếp theo');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hotline sheet shows confirmed number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeSupportButtons())),
    );
    await tester.tap(find.byIcon(Icons.phone_in_talk));
    await tester.pumpAndSettle();
    expect(find.text('Hotline 1900 8888'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('Sao chép số'), findsOneWidget);
  });
}
