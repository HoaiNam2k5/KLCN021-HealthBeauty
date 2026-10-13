import 'package:flutter_test/flutter_test.dart';
import 'package:app_doancunhan/models/appointment.dart';
import 'package:app_doancunhan/models/catalog.dart';

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
          }
        ]
      };

      final appointment = Appointment.fromJson(json);

      expect(appointment.id, 101);
      expect(appointment.code, '#LH101');
      expect(appointment.status, 'DaDen');
      expect(appointment.statusLabel, 'Đã đến');
      expect(appointment.isCancelled, false);
      expect(appointment.isDone, false);
      expect(appointment.isUpcoming, true);
      expect(appointment.total, 250000.0);
      expect(appointment.items.length, 1);
      expect(appointment.items.first.serviceName, 'Chăm sóc da');
    });

    test('canCancel is true only for ChoXacNhan and DaXacNhan', () {
      final base = Appointment(
        id: 1,
        customerId: 1,
        appointmentAt: DateTime.now().add(const Duration(days: 1)),
        status: 'ChoXacNhan',
        items: const [],
      );

      expect(base.copyWith(status: 'ChoXacNhan').canCancel, true);
      expect(base.copyWith(status: 'DaXacNhan').canCancel, true);
      expect(base.copyWith(status: 'DaDen').canCancel, false);
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
      expect(staff.displayTitle, 'Kỹ thuật viên trưởng · Chăm sóc da chuyên sâu');
    });
  });
}
