import '../core/format.dart';

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class ServiceCategory {
  final int id;
  final String name;
  final String? description;

  const ServiceCategory({required this.id, required this.name, this.description});

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
      );
}

class Service {
  final int id;
  final int categoryId;
  final String name;
  final double price;
  final int durationMinutes;
  final String? description;

  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.description,
  });

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as int,
        categoryId: j['categoryId'] as int,
        name: j['name'] as String? ?? '',
        price: _num(j['price']),
        durationMinutes: j['durationMinutes'] as int? ?? 0,
        description: j['description'] as String?,
      );
}

class ComboItem {
  final int serviceId;
  final String serviceName;
  final int quantity;

  const ComboItem({
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
  });

  factory ComboItem.fromJson(Map<String, dynamic> j) => ComboItem(
        serviceId: j['serviceId'] as int,
        serviceName: j['serviceName'] as String? ?? '',
        quantity: j['quantity'] as int? ?? 1,
      );
}

class Combo {
  final int id;
  final String name;
  final double price;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;
  final List<ComboItem> items;

  const Combo({
    required this.id,
    required this.name,
    required this.price,
    this.validFrom,
    this.validTo,
    required this.active,
    required this.items,
  });

  factory Combo.fromJson(Map<String, dynamic> j) => Combo(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        price: _num(j['price']),
        // DateOnly của .NET được serialize thành "2026-10-01"
        validFrom: DateTime.tryParse(j['validFrom']?.toString() ?? ''),
        validTo: DateTime.tryParse(j['validTo']?.toString() ?? ''),
        active: j['active'] as bool? ?? true,
        items: ((j['items'] as List?) ?? [])
            .map((e) => ComboItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Backend /combos chỉ lọc theo trạng thái, không lọc theo ngày hiệu lực
  /// -> app tự lọc.
  bool get isCurrent {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    if (validFrom != null && d.isBefore(validFrom!)) return false;
    if (validTo != null && d.isAfter(validTo!)) return false;
    return true;
  }

  int get totalServices => items.fold(0, (s, e) => s + e.quantity);
}

class Promotion {
  final int id;
  final String name;
  final String type; // vd "PhanTram" hoặc loại khác (số tiền)
  final double value;
  final String? condition;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const Promotion({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.condition,
    this.startsAt,
    this.endsAt,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
        id: j['khuyenMaiId'] as int,
        name: j['tenKhuyenMai'] as String? ?? '',
        type: j['loaiGiam'] as String? ?? '',
        value: _num(j['mucGiam']),
        condition: j['dieuKienApDung'] as String?,
        startsAt: DateTime.tryParse(j['ngayBatDauHieuLuc']?.toString() ?? ''),
        endsAt: DateTime.tryParse(j['ngayKetThucHieuLuc']?.toString() ?? ''),
      );

  bool get isPercent => type.toLowerCase().contains('phan');

  String get discountLabel {
    if (isPercent) {
      final v = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return 'Giảm $v%';
    }
    return 'Giảm ${vnd(value)}';
  }
}

/// Kết quả kiểm tra mã voucher (POST /promotions/vouchers/validate)
class VoucherCheck {
  final bool valid;
  final String? title;
  final double? value;
  final DateTime? expiresAt;
  final String? message;

  const VoucherCheck({
    required this.valid,
    this.title,
    this.value,
    this.expiresAt,
    this.message,
  });
}

/// Voucher cá nhân của khách hàng (GET /customers/me/vouchers)
class CustomerVoucher {
  final int id;
  final String code;
  final double discountValue;
  final DateTime? expiresAt;
  final String? promotionName;

  const CustomerVoucher({
    required this.id,
    required this.code,
    required this.discountValue,
    this.expiresAt,
    this.promotionName,
  });

  factory CustomerVoucher.fromJson(Map<String, dynamic> j) => CustomerVoucher(
        id: (j['voucherId'] ?? j['id']) as int? ?? 0,
        code: (j['maCode'] ?? j['code']) as String? ?? '',
        discountValue: _num(j['giaTriGiam'] ?? j['discountValue']),
        expiresAt: DateTime.tryParse(
            (j['hanSuDung'] ?? j['expiresAt'])?.toString() ?? ''),
        promotionName: (j['tenKhuyenMai'] ?? j['promotionName']) as String?,
      );
}

/// Nhân viên / Kỹ thuật viên (GET /staff)
class Staff {
  final int id;
  final String fullName;
  final String? position;
  final String? specialty;
  final String? phone;

  const Staff({
    required this.id,
    required this.fullName,
    this.position,
    this.specialty,
    this.phone,
  });

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
        id: (j['nhanVienId'] ?? j['id']) as int,
        fullName: (j['hoTen'] ?? j['fullName']) as String? ?? '',
        position: (j['chucVu'] ?? j['position']) as String?,
        specialty: (j['chuyenMon'] ?? j['specialty']) as String?,
        phone: (j['soDienThoai'] ?? j['phone']) as String?,
      );

  String get displayTitle {
    final parts = <String>[];
    if (position != null && position!.trim().isNotEmpty) {
      parts.add(position!.trim());
    }
    if (specialty != null && specialty!.trim().isNotEmpty) {
      parts.add(specialty!.trim());
    }
    return parts.isEmpty ? 'Kỹ thuật viên' : parts.join(' · ');
  }
}


