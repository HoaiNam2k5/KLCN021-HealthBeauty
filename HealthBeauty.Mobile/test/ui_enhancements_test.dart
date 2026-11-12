import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/widgets/booking_stepper_header.dart';
import 'package:app_doancunhan/widgets/booking_success_dialog.dart';
import 'package:app_doancunhan/widgets/before_after_slider.dart';
import 'package:app_doancunhan/widgets/hero_banner_carousel.dart';
import 'package:app_doancunhan/widgets/shimmer_loading.dart';
import 'package:app_doancunhan/widgets/spa_boarding_pass.dart';
import 'package:app_doancunhan/screens/splash_screen.dart';

void main() {
  group('UI Enhancements Widgets Tests', () {
    testWidgets('ShimmerLoading and ServiceGridShimmer render correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ServiceGridShimmer(itemCount: 4)),
        ),
      );

      expect(find.byType(ServiceGridShimmer), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(ShimmerBox), findsWidgets);
    });

    testWidgets('HeroBannerCarousel renders first slide and promo key', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HeroBannerCarousel())),
      );

      expect(find.byKey(const Key('home_promo_banner_card')), findsOneWidget);
      expect(find.text('ƯU ĐÃI KHÁCH HÀNG MỚI'), findsOneWidget);
      expect(find.text('Giảm 10% tất cả dịch vụ spa'), findsOneWidget);
    });

    testWidgets('BookingStepperHeader reflects active and completed steps', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BookingStepperHeader(currentStep: 1)),
        ),
      );

      expect(find.byType(BookingStepperHeader), findsOneWidget);
      expect(find.text('Dịch vụ'), findsOneWidget);
      expect(find.text('Thời gian & KTV'), findsOneWidget);
      expect(find.text('Xác nhận'), findsOneWidget);

      // Step 0 is completed (check icon)
      expect(find.byIcon(Icons.check), findsOneWidget);
      // Step 1 is active
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets(
      'BeforeAfterSlider renders labels and responds to drag gesture',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: BeforeAfterSlider()),
            ),
          ),
        );

        expect(find.text('Hiệu quả thực tế (Trước & Sau)'), findsOneWidget);
        expect(find.text('Trước liệu trình'), findsOneWidget);
        expect(find.text('Sau liệu trình'), findsOneWidget);
        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

        // Drag slider handle
        await tester.drag(find.byIcon(Icons.swap_horiz), const Offset(60, 0));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      },
    );

    testWidgets(
      'SpaBoardingPassCard renders boarding pass layout and triggers onTap',
      (tester) async {
        final sampleAppointment = Appointment.fromJson({
          'id': 9999,
          'customerId': 1,
          'staffId': 2,
          'appointmentAt': '2026-11-15T10:30:00.000',
          'status': 'DaXacNhan',
          'note': 'Chăm sóc da',
          'items': [
            {
              'id': 1,
              'serviceId': 10,
              'serviceName': 'Trẻ hóa da điện di Vitamin C',
              'comboId': null,
              'expectedPrice': 450000.0,
            },
          ],
        });

        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SpaBoardingPassCard(
                a: sampleAppointment,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify Boarding pass elements
        expect(find.text('Trẻ hóa da điện di Vitamin C'), findsOneWidget);
        expect(find.text('Vé lịch hẹn'), findsOneWidget);
        expect(find.text('Xem chi tiết vé'), findsOneWidget);
        expect(find.text('15'), findsOneWidget); // Day 15
        expect(find.text('Thg 11'), findsOneWidget); // Month 11
        expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);

        // Tap card
        await tester.tap(find.byType(SpaBoardingPassCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'BookingSuccessDialog renders confirmation details and action buttons',
      (tester) async {
        final sampleAppointment = Appointment.fromJson({
          'id': 8888,
          'customerId': 1,
          'staffId': 2,
          'appointmentAt': '2026-12-01T15:00:00.000',
          'status': 'ChoXacNhan',
          'items': [
            {
              'id': 1,
              'serviceId': 5,
              'serviceName': 'Massage body tinh dầu thảo mộc',
              'comboId': null,
              'expectedPrice': 350000.0,
            },
          ],
        });

        var viewed = false;
        var wentHome = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingSuccessDialog(
                appointment: sampleAppointment,
                staffName: 'Trần Thảo Ly',
                reminderText: '30 phút trước',
                onViewAppointment: () => viewed = true,
                onGoHome: () => wentHome = true,
              ),
            ),
          ),
        );

        expect(find.text('Đặt Lịch Thành Công!'), findsOneWidget);
        expect(find.text('#LH8888'), findsNothing);
        expect(find.text('Massage body tinh dầu thảo mộc'), findsOneWidget);
        expect(find.text('Kỹ thuật viên: Trần Thảo Ly'), findsOneWidget);
        expect(find.text('Nhắc hẹn đã chọn: 30 phút trước'), findsOneWidget);
        expect(find.text('Xem vé lịch hẹn của tôi'), findsOneWidget);
        expect(find.text('Về trang chủ'), findsOneWidget);

        await tester.tap(find.text('Xem vé lịch hẹn của tôi'));
        expect(viewed, isTrue);

        await tester.tap(find.text('Về trang chủ'));
        expect(wentHome, isTrue);
      },
    );

    testWidgets('SplashScreen renders branding and triggers onFinished', (
      tester,
    ) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onFinished: () => finished = true)),
      );

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('HealthBeauty'), findsOneWidget);
      expect(find.text('ĐÁNH THỨC VẺ ĐẸP TỰ NHIÊN'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(finished, isTrue);
    });
  });
}
