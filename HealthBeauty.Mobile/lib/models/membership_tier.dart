import 'package:flutter/material.dart';

class MembershipTier {
  final String name;
  final String code;
  final int minPoints;
  final int? nextPoints;
  final Color primaryColor;
  final Color backgroundColor;
  final IconData icon;
  final List<String> benefits;

  const MembershipTier({
    required this.name,
    required this.code,
    required this.minPoints,
    required this.nextPoints,
    required this.primaryColor,
    required this.backgroundColor,
    required this.icon,
    required this.benefits,
  });

  /// Tính tiến độ đến hạng tiếp theo (0.0 -> 1.0)
  double progress(int currentPoints) {
    if (nextPoints == null) return 1.0;
    final range = nextPoints! - minPoints;
    if (range <= 0) return 1.0;
    final gained = currentPoints - minPoints;
    return (gained / range).clamp(0.0, 1.0);
  }

  /// Số điểm còn thiếu để lên hạng tiếp theo
  int? pointsNeeded(int currentPoints) {
    if (nextPoints == null) return null;
    final diff = nextPoints! - currentPoints;
    return diff > 0 ? diff : 0;
  }

  /// Tên hạng tiếp theo
  String? get nextTierName {
    if (code == 'BRONZE') return 'Hạng Bạc';
    if (code == 'SILVER') return 'Hạng Vàng';
    if (code == 'GOLD') return 'Hạng Kim Cương';
    return null;
  }

  static MembershipTier fromPoints(int points) {
    if (points >= 1000) {
      return const MembershipTier(
        name: 'Hạng Kim Cương',
        code: 'DIAMOND',
        minPoints: 1000,
        nextPoints: null,
        primaryColor: Color(0xFF007A99),
        backgroundColor: Color(0xFFE8F6FA),
        icon: Icons.diamond_outlined,
        benefits: [
          'Giảm 15% tất cả dịch vụ và gói trị liệu cao cấp',
          'Tặng gói chăm sóc da chuyên sâu vào tháng sinh nhật',
          'Ưu tiên chọn chuyên viên tay nghề cao nhất',
          'Phòng trị liệu VIP riêng biệt miễn phí',
        ],
      );
    } else if (points >= 500) {
      return const MembershipTier(
        name: 'Hạng Vàng',
        code: 'GOLD',
        minPoints: 500,
        nextPoints: 1000,
        primaryColor: Color(0xFFC28B00),
        backgroundColor: Color(0xFFFFF9E6),
        icon: Icons.workspace_premium_outlined,
        benefits: [
          'Giảm 10% tất cả dịch vụ tại Spa',
          'Voucher giảm 30% nhân dịp sinh nhật',
          'Ưu tiên giữ lịch hẹn vào khung giờ cao điểm',
          'Miễn phí đồ uống thảo mộc & dịch vụ ngâm chân thư giãn',
        ],
      );
    } else if (points >= 100) {
      return const MembershipTier(
        name: 'Hạng Bạc',
        code: 'SILVER',
        minPoints: 100,
        nextPoints: 500,
        primaryColor: Color(0xFF5A6B7C),
        backgroundColor: Color(0xFFEEF2F6),
        icon: Icons.military_tech_outlined,
        benefits: [
          'Giảm 5% cho tất cả dịch vụ từ lần thứ 2',
          'Tặng voucher 50.000đ vào ngày sinh nhật',
          'Tích lũy điểm thưởng x1.2 vào các ngày hội viên',
        ],
      );
    } else {
      return const MembershipTier(
        name: 'Thành viên Mới',
        code: 'BRONZE',
        minPoints: 0,
        nextPoints: 100,
        primaryColor: Color(0xFF8B5A2B),
        backgroundColor: Color(0xFFFBF1E6),
        icon: Icons.card_membership_outlined,
        benefits: [
          'Tích lũy điểm thưởng 5% giá trị mỗi hóa đơn',
          'Nhận thông báo ưu đãi và khuyến mãi sớm nhất',
          'Miễn phí kiểm tra và tư vấn soi da',
        ],
      );
    }
  }

  static const List<MembershipTier> allTiers = [
    MembershipTier(
      name: 'Thành viên Mới',
      code: 'BRONZE',
      minPoints: 0,
      nextPoints: 100,
      primaryColor: Color(0xFF8B5A2B),
      backgroundColor: Color(0xFFFBF1E6),
      icon: Icons.card_membership_outlined,
      benefits: [
        'Tích lũy điểm thưởng 5% giá trị mỗi hóa đơn',
        'Nhận thông báo ưu đãi và khuyến mãi sớm nhất',
        'Miễn phí kiểm tra và tư vấn soi da',
      ],
    ),
    MembershipTier(
      name: 'Hạng Bạc',
      code: 'SILVER',
      minPoints: 100,
      nextPoints: 500,
      primaryColor: Color(0xFF5A6B7C),
      backgroundColor: Color(0xFFEEF2F6),
      icon: Icons.military_tech_outlined,
      benefits: [
        'Giảm 5% cho tất cả dịch vụ từ lần thứ 2',
        'Tặng voucher 50.000đ vào ngày sinh nhật',
        'Tích lũy điểm thưởng x1.2 vào các ngày hội viên',
      ],
    ),
    MembershipTier(
      name: 'Hạng Vàng',
      code: 'GOLD',
      minPoints: 500,
      nextPoints: 1000,
      primaryColor: Color(0xFFC28B00),
      backgroundColor: Color(0xFFFFF9E6),
      icon: Icons.workspace_premium_outlined,
      benefits: [
        'Giảm 10% tất cả dịch vụ tại Spa',
        'Voucher giảm 30% nhân dịp sinh nhật',
        'Ưu tiên giữ lịch hẹn vào khung giờ cao điểm',
        'Miễn phí đồ uống thảo mộc & dịch vụ ngâm chân thư giãn',
      ],
    ),
    MembershipTier(
      name: 'Hạng Kim Cương',
      code: 'DIAMOND',
      minPoints: 1000,
      nextPoints: null,
      primaryColor: Color(0xFF007A99),
      backgroundColor: Color(0xFFE8F6FA),
      icon: Icons.diamond_outlined,
      benefits: [
        'Giảm 15% tất cả dịch vụ và gói trị liệu cao cấp',
        'Tặng gói chăm sóc da chuyên sâu vào tháng sinh nhật',
        'Ưu tiên chọn chuyên viên tay nghề cao nhất',
        'Phòng trị liệu VIP riêng biệt miễn phí',
      ],
    ),
  ];
}
