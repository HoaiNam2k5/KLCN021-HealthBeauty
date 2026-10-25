class InvoiceLine {
  final String name;
  final int quantity;
  final double unitPrice;

  InvoiceLine.fromJson(Map<String, dynamic> json)
    : name = (json['serviceName'] ?? json['comboName'] ?? 'Dịch vụ').toString(),
      quantity = (json['quantity'] as num).toInt(),
      unitPrice = (json['unitPrice'] as num).toDouble();

  double get total => unitPrice * quantity;
}

class InvoicePayment {
  final String method;
  final double amount;
  final String status;
  final DateTime? paidAt;

  InvoicePayment.fromJson(Map<String, dynamic> json)
    : method = json['method'] as String,
      amount = (json['amount'] as num).toDouble(),
      status = json['status'] as String,
      paidAt = DateTime.tryParse(json['paidAt']?.toString() ?? '')?.toLocal();

  String get methodLabel => switch (method) {
    'ChuyenKhoan' => 'Chuyển khoản ngân hàng',
    'TienMat' => 'Tiền mặt',
    'ServicePackage' => 'Gói dịch vụ',
    _ => method,
  };
}

class CustomerInvoice {
  final int id;
  final int appointmentId;
  final DateTime createdAt;
  final double subtotal;
  final double total;
  final String status;
  final List<InvoiceLine> items;
  final List<InvoicePayment> payments;

  CustomerInvoice.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      appointmentId = (json['appointmentId'] as num).toInt(),
      createdAt = DateTime.parse(json['createdAt'] as String).toLocal(),
      subtotal = (json['subtotal'] as num).toDouble(),
      total = (json['total'] as num).toDouble(),
      status = json['status'] as String,
      items = (json['items'] as List)
          .map((x) => InvoiceLine.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList(),
      payments = (json['payments'] as List)
          .map(
            (x) => InvoicePayment.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();

  bool get isPaid => status == 'DaThanhToan';
  bool get canTransfer => status == 'ChuaThanhToan' && total > 0;
  double get discount => (subtotal - total).clamp(0, double.infinity);
  String get code => 'HD${id.toString().padLeft(6, '0')}';
  String get statusLabel => switch (status) {
    'DaThanhToan' => 'Đã thanh toán',
    'ChuaThanhToan' => 'Chờ thanh toán',
    'DaHuy' => 'Đã hủy',
    _ => 'Đang xử lý',
  };
}

class BankTransferInstructions {
  final int invoiceId;
  final double amount;
  final String bankName;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final String transferContent;
  final String qrImageUrl;

  BankTransferInstructions.fromJson(Map<String, dynamic> json)
    : invoiceId = (json['invoiceId'] as num).toInt(),
      amount = (json['amount'] as num).toDouble(),
      bankName = json['bankName'] as String,
      bankCode = json['bankCode'] as String,
      accountNumber = json['accountNumber'] as String,
      accountName = json['accountName'] as String,
      transferContent = json['transferContent'] as String,
      qrImageUrl = json['qrImageUrl'] as String;
}
