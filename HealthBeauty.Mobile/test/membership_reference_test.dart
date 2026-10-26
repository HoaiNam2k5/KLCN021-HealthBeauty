import 'package:app_doancunhan/models/membership_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reference milestones and progress handle boundaries and top tier', () {
    expect(MembershipTier.fromPoints(99).code, 'BRONZE');
    expect(MembershipTier.fromPoints(100).code, 'SILVER');
    expect(MembershipTier.fromPoints(500).code, 'GOLD');
    expect(MembershipTier.fromPoints(1000).code, 'DIAMOND');
    expect(MembershipTier.fromPoints(100).progress(100), 0);
    expect(MembershipTier.fromPoints(300).progress(300), 0.5);
    expect(MembershipTier.fromPoints(1000).progress(1000), 1);
    expect(MembershipTier.fromPoints(-1).progress(-1), 0);
  });

  test('available-point milestones explain spending effects without automatic promises', () {
    expect(MembershipTier.referenceNote, contains('tham khảo'));
    expect(MembershipTier.referenceNote, contains('Đổi điểm'));
    expect(MembershipTier.referenceNote, contains('không tự động'));
    for (final tier in MembershipTier.allTiers) {
      expect(
        tier.benefits.join(' '),
        isNot(matches(RegExp(r'Giảm \d+%|Miễn phí|Tặng|Ưu tiên'))),
      );
    }
    // Spending lowers only the reference display, never a backend entitlement.
    expect(MembershipTier.fromPoints(520).code, 'GOLD');
    expect(MembershipTier.fromPoints(420).code, 'SILVER');
  });
}
