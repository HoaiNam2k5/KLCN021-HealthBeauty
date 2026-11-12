import 'package:app_doancunhan/core/api_client.dart';
import 'package:app_doancunhan/models/account.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/providers/appointment_provider.dart';
import 'package:app_doancunhan/providers/auth_provider.dart';
import 'package:app_doancunhan/providers/catalog_provider.dart';
import 'package:app_doancunhan/screens/appointments_screen.dart';
import 'package:app_doancunhan/widgets/booking_success_dialog.dart';
import 'package:app_doancunhan/widgets/spa_boarding_pass.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Appointment ticket({String status = 'DaXacNhan', bool long = false}) =>
    Appointment(
      id: 123,
      customerId: 1,
      staffId: 2,
      appointmentAt: DateTime.now().add(const Duration(days: 3)),
      status: status,
      invoiceId: 5,
      customerPackageId: 7,
      note:
          '[Nhắc hẹn: 30 phút trước] [Voucher: UUDAIKHACHHANG (-50.000đ)] '
          '[Thanh toán: Chuyển khoản] Ghi chú chăm sóc da nhạy cảm',
      hasReviewed: status == 'HoanThanh',
      reviewStars: 5,
      reviewComment: 'Dịch vụ rất chu đáo. ' * 10,
      reviewReply: 'Cảm ơn quý khách đã tin tưởng sử dụng dịch vụ. ' * 10,
      reviewRepliedAt: DateTime.now(),
      items: List.generate(
        long ? 8 : 1,
        (i) => AppointmentItem(
          id: i,
          serviceId: i,
          serviceName: 'Chăm sóc da chuyên sâu kết hợp massage thư giãn $i',
          expectedPrice: 550000,
        ),
      ),
    );

Future<void> smallScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 568));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget app(Widget home, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('appointment moves from upcoming to history after start time', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 6, 9, 59);
    final auth = AuthProvider(
      client: ApiClient.withDio(dio: Dio(), refreshDio: Dio()),
    )..account = Account(id: 1, email: 'test@example.com', role: 'Customer');
    final appointments = AppointmentProvider(dio: Dio(), now: () => now)
      ..bind(1)
      ..items = [ticket().copyWith(appointmentAt: DateTime(2026, 11, 6, 10))];
    final catalog = CatalogProvider(dio: Dio());
    addTearDown(auth.dispose);
    addTearDown(appointments.dispose);
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: appointments),
          ChangeNotifierProvider.value(value: catalog),
        ],
        child: app(const Scaffold(body: AppointmentsScreen())),
      ),
    );
    expect(find.text('Sắp tới (1)'), findsOneWidget);
    now = DateTime(2026, 11, 6, 10, 0, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.text('Sắp tới (0)'), findsOneWidget);
    expect(appointments.history.single.id, 123);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Xem chi tiết vé'), findsOneWidget);
    expect(appointments.items.single.status, 'DaXacNhan');
  });

  for (final destination in ['Xem vé lịch hẹn của tôi', 'Về trang chủ']) {
    testWidgets(
      'success action $destination survives disposing booking routes',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        var selectedTab = 2;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('root')),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('service detail')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => BookingSuccessDialog.showAfterBooking(
                  context,
                  appointment: ticket(),
                  onViewAppointment: () => selectedTab = 2,
                  onGoHome: () => selectedTab = 0,
                ),
                child: const Text('complete'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('complete'));
        await tester.pumpAndSettle();
        expect(find.text('complete'), findsNothing);
        expect(find.text('service detail'), findsNothing);
        await tester.ensureVisible(find.text(destination));
        await tester.tap(find.text(destination));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(selectedTab, destination == 'Về trang chủ' ? 0 : 2);
        expect(find.byType(BookingSuccessDialog), findsNothing);
        expect(find.text('root'), findsOneWidget);
        expect(navigator.currentState!.canPop(), isFalse);
      },
    );
  }

  testWidgets('success actions ignore an expired account session', (
    tester,
  ) async {
    var current = true;
    var actions = 0;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => BookingSuccessDialog.showAfterBooking(
                context,
                appointment: ticket(),
                isCurrent: () => current,
                onViewAppointment: () => actions++,
                onGoHome: () => actions++,
              ),
              child: const Text('complete'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('complete'));
    await tester.pumpAndSettle();
    current = false;
    await tester.ensureVisible(find.text('Về trang chủ'));
    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(actions, 0);
    expect(find.byType(BookingSuccessDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back dismisses success sheet and leaves the surviving root usable',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('root')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => BookingSuccessDialog.showAfterBooking(
                context,
                appointment: ticket(),
                onViewAppointment: () => actions++,
                onGoHome: () => actions++,
              ),
              child: const Text('complete'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('complete'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(actions, 0);
      expect(find.byType(BookingSuccessDialog), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(find.text('root'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('long success sheet scrolls to actions at 320px scale $scale', (
      tester,
    ) async {
      await smallScreen(tester);
      var home = false;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => BookingSuccessDialog.show(
                  context,
                  appointment: ticket(long: true),
                  staffName: 'Nguyễn Thị Kỹ Thuật Viên Chăm Sóc Da',
                  reminderText: '30 phút trước',
                  onViewAppointment: () {},
                  onGoHome: () => home = true,
                ),
                child: const Text('complete'),
              ),
            ),
          ),
          scale: scale,
        ),
      );
      await tester.tap(find.text('complete'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nhắc hẹn đã chọn: 30 phút trước'), findsOneWidget);
      await tester.ensureVisible(find.text('Về trang chủ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Về trang chủ'));
      await tester.pumpAndSettle();
      expect(home, isTrue);
      expect(tester.takeException(), isNull);
    });

    for (final status in ['ChoXacNhan', 'DaXacNhan', 'HoanThanh', 'DaHuy']) {
      testWidgets(
        'ticket $status fits 320px scale $scale without duplicate status',
        (tester) async {
          await smallScreen(tester);
          var tapped = false;
          final a = ticket(status: status, long: true);
          await tester.pumpWidget(
            app(
              Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SpaBoardingPassCard(
                      a: a,
                      onTap: () => tapped = true,
                    ),
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text(a.statusLabel), findsOneWidget);
          expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
          await tester.ensureVisible(find.text('Xem chi tiết vé'));
          await tester.tap(find.text('Xem chi tiết vé'));
          expect(tapped, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final status in ['DaXacNhan', 'HoanThanh']) {
    testWidgets(
      'actual detail sheet $status wraps and scrolls with large text',
      (tester) async {
        await smallScreen(tester);
        final auth =
            AuthProvider(
                client: ApiClient.withDio(dio: Dio(), refreshDio: Dio()),
              )
              ..account = Account(
                id: 1,
                email: 'test@example.com',
                role: 'Customer',
              );
        final appointments = AppointmentProvider(dio: Dio())..bind(1);
        appointments.items = [ticket(status: status, long: true)];
        final catalog = CatalogProvider(dio: Dio());
        addTearDown(auth.dispose);
        addTearDown(appointments.dispose);
        addTearDown(catalog.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: appointments),
              ChangeNotifierProvider.value(value: catalog),
            ],
            child: app(const Scaffold(body: AppointmentsScreen()), scale: 2),
          ),
        );
        if (status == 'HoanThanh') {
          await tester.tap(find.text('Lịch sử'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Xem chi tiết vé'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xem chi tiết vé'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
        expect(find.text('THÔNG TIN LỊCH HẸN'), findsOneWidget);
        expect(
          find.text('Xuất trình thông tin lịch hẹn để lễ tân đối chiếu'),
          findsOneWidget,
        );
        final scroll = find.descendant(
          of: find.byKey(const ValueKey('appointment-ticket-scroll')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Xem hóa đơn / Thanh toán'),
          200,
          scrollable: scroll,
        );
        expect(tester.takeException(), isNull);
        if (status == 'DaXacNhan') {
          await tester.scrollUntilVisible(
            find.text('Hủy lịch hẹn'),
            200,
            scrollable: scroll,
          );
          expect(find.text('Đổi ngày / giờ hẹn'), findsOneWidget);
        } else {
          await tester.scrollUntilVisible(
            find.text('Phản hồi từ Spa:'),
            200,
            scrollable: scroll,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
