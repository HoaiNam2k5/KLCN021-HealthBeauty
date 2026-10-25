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
    if (points >= 1000) return allTiers[3];
    if (points >= 500) return allTiers[2];
    if (points >= 100) return allTiers[1];
    return allTiers[0];
  }

  static const List<String> commonBenefits = [
    'Tích điểm sau khi thanh toán thành công',
    'Dùng điểm đổi voucher tại mục Ưu đãi',
    'Theo dõi số dư và lịch sử giao dịch điểm',
    'Nhận thông báo lịch hẹn, voucher và chương trình khuyến mãi',
  ];

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
        'Bắt đầu tích lũy điểm thưởng',
        'Sử dụng điểm để đổi voucher',
        'Theo dõi ưu đãi và lịch sử điểm trên ứng dụng',
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
        'Bao gồm toàn bộ quyền lợi chung',
        'Thẻ thành viên và huy hiệu Hạng Bạc',
        'Có thể nhận voucher tri ân theo từng chương trình',
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
        'Bao gồm toàn bộ quyền lợi chung',
        'Thẻ thành viên và huy hiệu Hạng Vàng',
        'Có thể nhận ưu đãi khách hàng thân thiết theo từng chương trình',
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
        'Bao gồm toàn bộ quyền lợi chung',
        'Thẻ thành viên và huy hiệu hạng cao nhất',
        'Có thể nhận quà tặng hoặc voucher tri ân đặc biệt theo từng chương trình',
      ],
    ),
  ];
}
