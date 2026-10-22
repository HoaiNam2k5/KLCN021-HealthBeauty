import '../core/format.dart';

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

class ServiceCategory {
  final int id;
  final String name;
  final String? description;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.description,
  });

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
  final double? averageRating;
  final int totalReviews;
  final int bookedCount;

  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.description,
    this.averageRating,
    this.totalReviews = 0,
    this.bookedCount = 0,
  });

  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'] as int,
    categoryId: j['categoryId'] as int,
    name: j['name'] as String? ?? '',
    price: _num(j['price']),
    durationMinutes: j['durationMinutes'] as int? ?? 0,
    description: j['description'] as String?,
    averageRating: (j['averageRating'] as num?)?.toDouble(),
    totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
    bookedCount: (j['bookedCount'] as num?)?.toInt() ?? 0,
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

  /// Keep the backend DateOnly validity boundaries inclusive.
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

  bool get isPercent => type.trim().toLowerCase() == 'phantram';

  String get discountLabel {
    if (isPercent) {
      final v = value % 1 == 0
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return 'Giảm $v%';
    }
    return 'Giảm ${vnd(value)}';
  }
}

/// Kết quả kiểm tra mã voucher (POST /promotions/vouchers/validate)
class VoucherCheck {
  final bool valid;
  final String? code;
  final String? title;
  final double? value;
  final DateTime? expiresAt;
  final String? message;

  const VoucherCheck({
    required this.valid,
    this.code,
    this.title,
    this.value,
    this.expiresAt,
    this.message,
  });

  /// giaTriGiam is a maximum cap; invoice subtotal and promotion determine the actual discount.
  factory VoucherCheck.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    if (json['valid'] is! bool) {
      throw const FormatException('Missing voucher validity flag');
    }
    if (json['valid'] != true) {
      return const VoucherCheck(
        valid: false,
        message: 'Mã không hợp lệ hoặc đã hết hạn.',
      );
    }
    final code = json['maCode'] as String?;
    final value = (json['giaTriGiam'] as num?)?.toDouble();
    final expiresAt = DateTime.tryParse(json['hanSuDung']?.toString() ?? '');
    if (code == null ||
        code.isEmpty ||
        value == null ||
        !value.isFinite ||
        value < 0 ||
        expiresAt == null) {
      throw const FormatException('Incomplete voucher validation response');
    }
    if (expiresAt.isBefore(now ?? DateTime.now())) {
      return const VoucherCheck(valid: false, message: 'Voucher đã hết hạn.');
    }
    return VoucherCheck(
      valid: true,
      code: code,
      title: json['tenKhuyenMai'] as String?,
      value: value,
      expiresAt: expiresAt,
    );
  }
}

/// Voucher cá nhân của khách hàng (GET /customers/me/vouchers)
class CustomerVoucher {
  final int id;
  final String code;
  final double discountValue;
  final DateTime? expiresAt;
  final String? promotionName;
  final bool active;

  const CustomerVoucher({
    required this.id,
    required this.code,
    required this.discountValue,
    this.expiresAt,
    this.promotionName,
    this.active = true,
  });

  factory CustomerVoucher.fromJson(Map<String, dynamic> j) {
    final id = j['voucherId'] as int?;
    final code = j['maCode'] as String?;
    final discount = (j['giaTriGiam'] as num?)?.toDouble();
    final expiresAt = DateTime.tryParse(j['hanSuDung']?.toString() ?? '');
    if (id == null ||
        id <= 0 ||
        code == null ||
        code.isEmpty ||
        discount == null ||
        !discount.isFinite ||
        expiresAt == null) {
      throw const FormatException('Incomplete customer voucher response');
    }
    return CustomerVoucher(
      id: id,
      code: code,
      discountValue: discount,
      expiresAt: expiresAt,
      promotionName: j['tenKhuyenMai'] as String?,
      // The customer endpoint omits this flag because it already selects active vouchers.
      active: _voucherFlag(j['active'] ?? j['trangThai']),
    );
  }

  bool isAvailableAt(DateTime now) =>
      active &&
      code.isNotEmpty &&
      discountValue.isFinite &&
      discountValue >= 0 &&
      expiresAt != null &&
      !expiresAt!.isBefore(now);
}

bool _voucherFlag(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  if (value == 0 || value == 1) return value == 1;
  throw const FormatException('Invalid voucher activity flag');
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
