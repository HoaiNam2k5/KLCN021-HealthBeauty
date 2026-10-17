class Customer {
  final int id;
  final String fullName;
  final String? phone;
  final String? gender;
  final int rewardPoints;

  const Customer({
    required this.id,
    required this.fullName,
    this.phone,
    this.gender,
    required this.rewardPoints,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String?,
        gender: j['gender'] as String?,
        rewardPoints: j['rewardPoints'] as int? ?? 0,
      );
}

class PointTransaction {
  final int id;
  final int points; // dương: cộng, âm: trừ
  final String type;
  final DateTime? date;
  final String? note;

  const PointTransaction({
    required this.id,
    required this.points,
    required this.type,
    this.date,
    this.note,
  });

  /// GET /customers/me/points trả object ẩn danh nên tên trường là
  /// giaoDichId, soDiem, loaiGiaoDich, ngayGiaoDich, ghiChu
  factory PointTransaction.fromJson(Map<String, dynamic> j) => PointTransaction(
        id: j['giaoDichId'] as int? ?? 0,
        points: (j['soDiem'] as num?)?.toInt() ?? 0,
        type: j['loaiGiaoDich']?.toString() ?? '',
        date: DateTime.tryParse(j['ngayGiaoDich']?.toString() ?? ''),
        note: j['ghiChu'] as String?,
      );
}
