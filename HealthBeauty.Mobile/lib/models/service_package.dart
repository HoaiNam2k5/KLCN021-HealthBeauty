int _integer(dynamic value, String field, {bool positive = false}) {
  if (value is! num || value != value.toInt() || value < (positive ? 1 : 0)) {
    throw FormatException('Invalid package $field.');
  }
  return value.toInt();
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

class ServicePackageOfferItem {
  final int serviceId;
  final int sessions;
  const ServicePackageOfferItem({
    required this.serviceId,
    required this.sessions,
  });
  factory ServicePackageOfferItem.fromJson(Map<String, dynamic> json) =>
      ServicePackageOfferItem(
        serviceId: _integer(json['serviceId'], 'serviceId', positive: true),
        sessions: _integer(json['sessions'], 'sessions', positive: true),
      );
}

class ServicePackageOffer {
  final int id;
  final String name;
  final double price;
  final int validityDays;
  final bool active;
  final String? imageUrl;
  final List<ServicePackageOfferItem> items;
  const ServicePackageOffer({
    required this.id,
    required this.name,
    required this.price,
    required this.validityDays,
    required this.active,
    this.imageUrl,
    required this.items,
  });
  factory ServicePackageOffer.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num).toDouble();
    if (!price.isFinite || price < 0) {
      throw const FormatException('Invalid package price.');
    }
    final items = (json['items'] as List)
        .map(
          (x) => ServicePackageOfferItem.fromJson(
            Map<String, dynamic>.from(x as Map),
          ),
        )
        .toList();
    if (items.isEmpty ||
        items.map((x) => x.serviceId).toSet().length != items.length) {
      throw const FormatException('Invalid package services.');
    }
    return ServicePackageOffer(
      id: _integer(json['id'], 'id', positive: true),
      name: json['name'] as String,
      price: price,
      validityDays: _integer(
        json['validityDays'],
        'validityDays',
        positive: true,
      ),
      active: json['active'] as bool,
      imageUrl: (json['imageUrl'] as String?)?.trim(),
      items: items,
    );
  }
}

class PackageSessionBalance {
  final int id, serviceId, granted, reserved, used, remaining, available;
  final String serviceName;
  const PackageSessionBalance({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.granted,
    required this.reserved,
    required this.used,
    required this.remaining,
    required this.available,
  });
  factory PackageSessionBalance.fromJson(Map<String, dynamic> json) {
    final granted = _integer(json['granted'], 'granted');
    final reserved = _integer(json['reserved'], 'reserved');
    final used = _integer(json['used'], 'used');
    final remaining = _integer(json['remaining'], 'remaining');
    final available = _integer(json['available'], 'available');
    if (remaining != granted - used ||
        reserved + used > granted ||
        available > remaining - reserved) {
      throw const FormatException('Inconsistent package session balance.');
    }
    return PackageSessionBalance(
      id: _integer(json['id'], 'itemId', positive: true),
      serviceId: _integer(json['serviceId'], 'serviceId', positive: true),
      serviceName: json['serviceName'] as String,
      granted: granted,
      reserved: reserved,
      used: used,
      remaining: remaining,
      available: available,
    );
  }
}

class CustomerServicePackage {
  final int id, servicePackageId, customerId, validityDays;
  final String name, status;
  final double price;
  final DateTime createdAt;
  final DateTime? paidAt, expiresAt;
  final String? paymentMethod;
  final List<PackageSessionBalance> items;
  const CustomerServicePackage({
    required this.id,
    required this.servicePackageId,
    required this.customerId,
    required this.name,
    required this.price,
    required this.validityDays,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.expiresAt,
    this.paymentMethod,
    required this.items,
  });
  factory CustomerServicePackage.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num).toDouble();
    if (!price.isFinite || price < 0) {
      throw const FormatException('Invalid purchase price.');
    }
    final items = (json['items'] as List)
        .map(
          (x) => PackageSessionBalance.fromJson(
            Map<String, dynamic>.from(x as Map),
          ),
        )
        .toList();
    if (items.map((x) => x.serviceId).toSet().length != items.length) {
      throw const FormatException('Duplicate package service.');
    }
    return CustomerServicePackage(
      id: _integer(json['id'], 'id', positive: true),
      servicePackageId: _integer(
        json['servicePackageId'],
        'servicePackageId',
        positive: true,
      ),
      customerId: _integer(json['customerId'], 'customerId', positive: true),
      name: json['name'] as String,
      price: price,
      validityDays: _integer(
        json['validityDays'],
        'validityDays',
        positive: true,
      ),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: _date(json['paidAt']),
      expiresAt: _date(json['expiresAt']),
      paymentMethod: json['paymentMethod'] as String?,
      items: items,
    );
  }
  bool canUseAt(DateTime at) =>
      status == 'Paid' &&
      expiresAt != null &&
      !DateTime.now().isAfter(expiresAt!) &&
      !at.isAfter(expiresAt!) &&
      items.any((x) => x.available > 0);
  PackageSessionBalance? service(int id) {
    for (final item in items) {
      if (item.serviceId == id) return item;
    }
    return null;
  }

  String get statusLabel {
    if (status == 'Pending') return 'Chờ thanh toán';
    if (status == 'Cancelled') return 'Đã hủy';
    if (status != 'Paid') return 'Chưa xác định';
    if (expiresAt == null || DateTime.now().isAfter(expiresAt!)) {
      return 'Đã hết hạn';
    }
    if (items.every((x) => x.remaining == 0)) return 'Đã dùng hết lượt';
    if (items.every((x) => x.available == 0)) {
      return 'Các lượt còn lại đang được giữ';
    }
    return 'Có thể sử dụng';
  }
}

class PackageUsageHistory {
  final int id, customerPackageItemId, appointmentId, quantity;
  final String status;
  final DateTime createdAt;
  final DateTime? settledAt;
  const PackageUsageHistory({
    required this.id,
    required this.customerPackageItemId,
    required this.appointmentId,
    required this.quantity,
    required this.status,
    required this.createdAt,
    this.settledAt,
  });
  factory PackageUsageHistory.fromJson(Map<String, dynamic> j) =>
      PackageUsageHistory(
        id: _integer(j['id'], 'usageId', positive: true),
        customerPackageItemId: _integer(
          j['customerPackageItemId'],
          'itemId',
          positive: true,
        ),
        appointmentId: _integer(
          j['appointmentId'],
          'appointmentId',
          positive: true,
        ),
        quantity: _integer(j['quantity'], 'quantity', positive: true),
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        settledAt: _date(j['settledAt']),
      );
  String get statusLabel => switch (status) {
    'Reserved' => 'Đang giữ lượt',
    'Consumed' => 'Đã sử dụng',
    'Released' => 'Đã trả lượt',
    _ => 'Chưa xác định',
  };
}

class CustomerPackageDetail {
  final CustomerServicePackage package;
  final List<PackageUsageHistory> history;
  const CustomerPackageDetail({required this.package, required this.history});
  factory CustomerPackageDetail.fromJson(Map<String, dynamic> j) =>
      CustomerPackageDetail(
        package: CustomerServicePackage.fromJson(
          Map<String, dynamic>.from(j['package'] as Map),
        ),
        history: (j['history'] as List)
            .map(
              (x) => PackageUsageHistory.fromJson(
                Map<String, dynamic>.from(x as Map),
              ),
            )
            .toList(),
      );
}
