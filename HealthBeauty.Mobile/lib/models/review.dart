class ReviewItem {
  final int id;
  final int invoiceId;
  final int stars;
  final String? comment;
  final DateTime createdAt;
  final String customerName;
  final String? reply;
  final DateTime? repliedAt;

  const ReviewItem({
    required this.id,
    required this.invoiceId,
    required this.stars,
    this.comment,
    required this.createdAt,
    required this.customerName,
    this.reply,
    this.repliedAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
    id: (j['danhGiaId'] ?? j['id'] as num?)?.toInt() ?? 0,
    invoiceId: (j['hoaDonId'] ?? j['invoiceId'] as num?)?.toInt() ?? 0,
    stars: (j['soSao'] ?? j['stars'] as num?)?.toInt() ?? 5,
    comment: (j['binhLuan'] ?? j['comment']) as String?,
    createdAt: j['ngayDanhGia'] != null
        ? DateTime.parse(j['ngayDanhGia'] as String).toLocal()
        : DateTime.now(),
    customerName:
        (j['tenKhachHang'] ?? j['customerName']) as String? ?? 'Khách hàng',
    reply: j['reply'] as String?,
    repliedAt: j['repliedAt'] != null
        ? DateTime.parse(j['repliedAt'] as String).toLocal()
        : null,
  );
}

class ReviewSummary {
  final double averageRating;
  final int totalReviews;
  final List<ReviewItem> items;

  const ReviewSummary({
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.items = const [],
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
    averageRating: (j['averageRating'] as num?)?.toDouble() ?? 0.0,
    totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
    items: ((j['items'] as List?) ?? [])
        .map(
          (e) => ReviewItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
  );
}
