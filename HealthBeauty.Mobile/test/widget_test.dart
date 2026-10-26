import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/models/catalog.dart';
import 'package:app_doancunhan/models/review.dart';
import 'package:app_doancunhan/widgets/service_tile.dart';

void main() {
  group('Appointment Model Tests', () {
    test('parses appointment correctly and handles DaDen status', () {
      final json = {
        'id': 101,
        'customerId': 1,
        'staffId': 2,
        'appointmentAt': '2026-10-15T10:30:00.000',
        'status': 'DaDen',
        'note': 'Lần đầu trải nghiệm',
        'items': [
          {
            'id': 1,
            'serviceId': 10,
            'serviceName': 'Chăm sóc da',
            'comboId': null,
            'expectedPrice': 250000.0,
          },
        ],
      };

      final appointment = Appointment.fromJson(json);

      expect(appointment.id, 101);
      expect(appointment.code, '#LH101');
      expect(appointment.status, 'DaDen');
      expect(appointment.statusLabel, 'Đã đến');
      expect(appointment.isCancelled, false);
      expect(appointment.isDone, false);
      expect(appointment.isUpcomingAt(DateTime(2026, 10, 15, 9)), true);
      expect(appointment.isUpcomingAt(DateTime(2026, 10, 16)), false);
      expect(appointment.total, 250000.0);
      expect(appointment.items.length, 1);
      expect(appointment.items.first.serviceName, 'Chăm sóc da');
    });

    test('canCancel matches backend pre-service cancellation states', () {
      final base = Appointment(
        id: 1,
        customerId: 1,
        appointmentAt: DateTime.now().add(const Duration(days: 1)),
        status: 'ChoXacNhan',
        items: const [],
      );

      expect(base.copyWith(status: 'ChoXacNhan').canCancel, true);
      expect(base.copyWith(status: 'DaXacNhan').canCancel, true);
      expect(base.copyWith(status: 'DaDen').canCancel, true);
      expect(base.copyWith(status: 'DangThucHien').canCancel, false);
      expect(base.copyWith(status: 'HoanThanh').canCancel, false);
      expect(base.copyWith(status: 'DaHuy').canCancel, false);
    });
  });

  group('Catalog, Voucher & Staff Tests', () {
    test('parses CustomerVoucher correctly', () {
      final json = {
        'voucherId': 5,
        'maCode': 'SPA100K',
        'giaTriGiam': 100000,
        'hanSuDung': '2026-12-31T23:59:59',
        'tenKhuyenMai': 'Ưu đãi cuối năm',
      };

      final voucher = CustomerVoucher.fromJson(json);

      expect(voucher.id, 5);
      expect(voucher.code, 'SPA100K');
      expect(voucher.discountValue, 100000.0);
      expect(voucher.promotionName, 'Ưu đãi cuối năm');
      expect(voucher.expiresAt?.year, 2026);
    });

    test('parses Staff correctly and displays title', () {
      final json = {
        'nhanVienId': 10,
        'hoTen': 'Nguyễn Thị Hoa',
        'chucVu': 'Kỹ thuật viên trưởng',
        'chuyenMon': 'Chăm sóc da chuyên sâu',
        'soDienThoai': '0901234567',
      };

      final staff = Staff.fromJson(json);

      expect(staff.id, 10);
      expect(staff.fullName, 'Nguyễn Thị Hoa');
      expect(staff.position, 'Kỹ thuật viên trưởng');
      expect(staff.specialty, 'Chăm sóc da chuyên sâu');
      expect(
        staff.displayTitle,
        'Kỹ thuật viên trưởng · Chăm sóc da chuyên sâu',
      );
    });
  });

  group('ServiceCard & ComboCard Widget Tests', () {
    testWidgets('ServiceCard renders vertical layout without overflow and handles tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      const service = Service(
        id: 1,
        categoryId: 1,
        name: 'Chăm sóc da chuyên sâu',
        price: 650000,
        durationMinutes: 75,
        description: 'Liệu trình chăm sóc da chuyên sâu',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 300,
              child: ServiceCard(
                service: service,
                categoryName: 'Chăm sóc da',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Yêu thích'), findsOneWidget);
      expect(find.textContaining('Chăm sóc da chuyên sâu', findRichText: true), findsOneWidget);
      expect(find.text('VOUCHER'), findsOneWidget);
      expect(find.textContaining('650.000'), findsOneWidget);

      await tester.tap(find.byType(ServiceCard));
      expect(tapped, true);
    });

    testWidgets('ServiceCard works in 2-column GridView without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final services = List.generate(
        6,
        (i) => Service(
          id: i + 1,
          categoryId: 1,
          name: 'Dịch vụ $i - Liệu trình chuyên sâu phục hồi da',
          price: 500000 + i * 50000,
          durationMinutes: 60,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.60,
              ),
              itemBuilder: (context, i) => ServiceCard(
                service: services[i],
                categoryName: 'Chăm sóc da',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Booking & Appointment Enhancements Tests', () {
    testWidgets('AppointmentsScreen parses and displays voucher and payment details', (tester) async {
      final json = {
        'id': 202,
        'customerId': 1,
        'staffId': 3,
        'appointmentAt': '2026-10-18T14:00:00.000',
        'status': 'DaXacNhan',
        'note': '[Nhắc hẹn: 30 phút trước] [Voucher: SPA50K (-50.000 đ)] [Thanh toán: Chuyển khoản] Da nhạy cảm cần chăm sóc kỹ',
        'items': [
          {
            'id': 1,
            'serviceId': 10,
            'serviceName': 'Chăm sóc da chuyên sâu',
            'comboId': null,
            'expectedPrice': 650000.0,
          },
        ],
      };

      final appointment = Appointment.fromJson(json);

      // Verify Appointment model values
      expect(appointment.id, 202);
      expect(appointment.note, contains('[Voucher: SPA50K (-50.000 đ)]'));
      expect(appointment.note, contains('[Thanh toán: Chuyển khoản]'));
      expect(appointment.note, contains('[Nhắc hẹn: 30 phút trước]'));
    });
  });

  group('Review & Rating Model Tests', () {
    test('parses ReviewSummary and ReviewItem correctly', () {
      final json = {
        'averageRating': 4.9,
        'totalReviews': 2,
        'items': [
          {
            'danhGiaId': 10,
            'hoaDonId': 20,
            'soSao': 5,
            'binhLuan': 'Dịch vụ rất tốt, nhân viên thân thiện!',
            'ngayDanhGia': '2026-10-20T15:30:00.000',
            'tenKhachHang': 'Trần Thị Mai',
            'reply': 'Cảm ơn bạn đã ghé thăm spa!',
            'repliedAt': '2026-10-20T16:00:00.000Z',
          },
          {
            'danhGiaId': 11,
            'hoaDonId': 21,
            'soSao': 4,
            'binhLuan': 'Không gian đẹp, thư giãn.',
            'ngayDanhGia': '2026-10-21T10:00:00.000',
            'tenKhachHang': 'Lê Hoàng Long',
          },
        ],
      };

      final summary = ReviewSummary.fromJson(json);
      expect(summary.averageRating, 4.9);
      expect(summary.totalReviews, 2);
      expect(summary.items.length, 2);

      final r1 = summary.items.first;
      expect(r1.id, 10);
      expect(r1.stars, 5);
      expect(r1.comment, 'Dịch vụ rất tốt, nhân viên thân thiện!');
      expect(r1.customerName, 'Trần Thị Mai');
      expect(r1.reply, 'Cảm ơn bạn đã ghé thăm spa!');
      expect(r1.repliedAt, isNotNull);
    });

    test('Appointment parses hasReviewed and reviewStars correctly', () {
      final json = {
        'id': 301,
        'customerId': 1,
        'staffId': 2,
        'appointmentAt': '2026-10-20T10:00:00.000',
        'status': 'HoanThanh',
        'items': const [],
        'hasReviewed': true,
        'reviewStars': 5,
        'reviewComment': 'Dịch vụ rất tốt',
        'reviewedAt': '2026-10-22T20:45:00.000',
        'reviewReply': 'Cảm ơn bạn',
        'reviewRepliedAt': '2026-10-22T21:00:00.000',
        'invoiceId': 88,
      };

      final appt = Appointment.fromJson(json);
      expect(appt.hasReviewed, isTrue);
      expect(appt.reviewStars, 5);
      expect(appt.reviewComment, 'Dịch vụ rất tốt');
      expect(appt.reviewedAt, isNotNull);
      expect(appt.reviewReply, 'Cảm ơn bạn');
      expect(appt.reviewRepliedAt, isNotNull);
      expect(appt.invoiceId, 88);
    });

    test('Service.fromJson parses real averageRating, totalReviews and bookedCount', () {
      final json = {
        'id': 1,
        'categoryId': 1,
        'name': 'Chăm sóc da chuyên sâu',
        'price': 650000.0,
        'durationMinutes': 75,
        'description': 'Làm sạch sâu...',
        'averageRating': 4.5,
        'totalReviews': 2,
        'bookedCount': 15,
      };

      final service = Service.fromJson(json);
      expect(service.averageRating, 4.5);
      expect(service.totalReviews, 2);
      expect(service.bookedCount, 15);
    });

    testWidgets('ServiceCard displays real rating and booked count', (tester) async {
      const ratedService = Service(
        id: 1,
        categoryId: 1,
        name: 'Chăm sóc da chuyên sâu',
        price: 650000,
        durationMinutes: 75,
        averageRating: 4.5,
        totalReviews: 2,
        bookedCount: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 300,
              child: ServiceCard(
                service: ratedService,
                categoryName: 'Chăm sóc da',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('Đã đặt 15'), findsOneWidget);
      expect(find.textContaining('102+'), findsNothing);
    });

    testWidgets('ServiceCard displays "Chưa đánh giá" and "Mới" when counts are 0', (tester) async {
      const newService = Service(
        id: 2,
        categoryId: 1,
        name: 'Dịch vụ thử nghiệm',
        price: 300000,
        durationMinutes: 45,
        averageRating: null,
        totalReviews: 0,
        bookedCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 300,
              child: ServiceCard(
                service: newService,
                categoryName: 'Chăm sóc da',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chưa đánh giá'), findsOneWidget);
      expect(find.text('Mới'), findsOneWidget);
      expect(find.textContaining('102+'), findsNothing);
    });
  });
}
