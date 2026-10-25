class AppointmentItem {
  final int id;
  final int serviceId;
  final String serviceName;
  final int? comboId;
  final double expectedPrice;
  final int durationMinutes;

  const AppointmentItem({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    this.comboId,
    required this.expectedPrice,
    this.durationMinutes = 30,
  });

  factory AppointmentItem.fromJson(Map<String, dynamic> j) => AppointmentItem(
    id: j['id'] as int,
    serviceId: j['serviceId'] as int,
    serviceName: j['serviceName'] as String? ?? '',
    comboId: j['comboId'] as int?,
    expectedPrice: (j['expectedPrice'] as num?)?.toDouble() ?? 0,
    durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 30,
  );
}

class Appointment {
  final int id;
  final int customerId;
  final int? staffId;
  final DateTime appointmentAt;
  final String status;
  final String? note;
  final List<AppointmentItem> items;
  final int? invoiceId;
  final int? customerPackageId;
  final String? invoiceStatus;
  final bool hasReviewed;
  final int? reviewStars;
  final String? reviewComment;
  final DateTime? reviewedAt;
  final String? reviewReply;
  final DateTime? reviewRepliedAt;

  const Appointment({
    required this.id,
    required this.customerId,
    this.staffId,
    required this.appointmentAt,
    required this.status,
    this.note,
    required this.items,
    this.invoiceId,
    this.customerPackageId,
    this.invoiceStatus,
    this.hasReviewed = false,
    this.reviewStars,
    this.reviewComment,
    this.reviewedAt,
    this.reviewReply,
    this.reviewRepliedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'] as int,
    customerId: j['customerId'] as int,
    staffId: j['staffId'] as int?,
    // Server trả giờ địa phương không kèm múi giờ -> parse ra local
    appointmentAt: DateTime.parse(j['appointmentAt'] as String).toLocal(),
    status: j['status'] as String? ?? '',
    note: j['note'] as String?,
    items: ((j['items'] as List?) ?? [])
        .map((e) => AppointmentItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    invoiceId: (j['invoiceId'] as num?)?.toInt(),
    customerPackageId: (j['customerPackageId'] as num?)?.toInt(),
    invoiceStatus: j['invoiceStatus'] as String?,
    hasReviewed: j['hasReviewed'] as bool? ?? false,
    reviewStars: (j['reviewStars'] as num?)?.toInt(),
    reviewComment: j['reviewComment'] as String?,
    reviewedAt: j['reviewedAt'] != null
        ? DateTime.parse(j['reviewedAt'] as String).toLocal()
        : null,
    reviewReply: j['reviewReply'] as String?,
    reviewRepliedAt: j['reviewRepliedAt'] != null
        ? DateTime.parse(j['reviewRepliedAt'] as String).toLocal()
        : null,
  );

  /// Mã hiển thị, ví dụ #LH12
  String get code => '#LH$id';

  double get total => items.fold(0.0, (s, e) => s + e.expectedPrice);

  int get durationMinutes => items.isEmpty
      ? 30
      : items.fold(
          0,
          (sum, item) =>
              sum + (item.durationMinutes > 0 ? item.durationMinutes : 30),
        );

  String get serviceSummary {
    if (items.isEmpty) return 'Lịch hẹn';
    final names = items.map((e) => e.serviceName).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  bool get isCancelled => status == 'DaHuy';
  bool get isDone => status == 'HoanThanh';

  /// Khách có thể hủy nếu lịch ở trạng thái Chờ xác nhận hoặc Đã xác nhận
  bool get canCancel =>
      status == 'ChoXacNhan' || status == 'DaXacNhan' || status == 'DaDen';

  bool get canReschedule => status == 'ChoXacNhan' || status == 'DaXacNhan';

  /// "Sắp tới": chưa hủy, chưa hoàn thành
  bool get isUpcoming => !isCancelled && !isDone;

  /// Nhãn hiển thị trạng thái lịch hẹn theo backend
  String get statusLabel {
    switch (status) {
      case 'ChoXacNhan':
        return 'Chờ xác nhận';
      case 'DaXacNhan':
        return 'Đã xác nhận';
      case 'DaDen':
        return 'Đã đến';
      case 'DangThucHien':
        return 'Đang thực hiện';
      case 'HoanThanh':
        return 'Hoàn thành';
      case 'DaHuy':
        return 'Đã hủy';
      default:
        return status.isEmpty ? 'Không rõ' : status;
    }
  }

  Appointment copyWith({
    int? id,
    int? customerId,
    int? staffId,
    DateTime? appointmentAt,
    String? status,
    String? note,
    List<AppointmentItem>? items,
    int? invoiceId,
    int? customerPackageId,
    String? invoiceStatus,
    bool? hasReviewed,
    int? reviewStars,
    String? reviewComment,
    DateTime? reviewedAt,
    String? reviewReply,
    DateTime? reviewRepliedAt,
  }) => Appointment(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    staffId: staffId ?? this.staffId,
    appointmentAt: appointmentAt ?? this.appointmentAt,
    status: status ?? this.status,
    note: note ?? this.note,
    items: items ?? this.items,
    invoiceId: invoiceId ?? this.invoiceId,
    customerPackageId: customerPackageId ?? this.customerPackageId,
    invoiceStatus: invoiceStatus ?? this.invoiceStatus,
    hasReviewed: hasReviewed ?? this.hasReviewed,
    reviewStars: reviewStars ?? this.reviewStars,
    reviewComment: reviewComment ?? this.reviewComment,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    reviewReply: reviewReply ?? this.reviewReply,
    reviewRepliedAt: reviewRepliedAt ?? this.reviewRepliedAt,
  );
}
