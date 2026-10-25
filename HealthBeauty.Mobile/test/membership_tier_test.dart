import 'package:app_doancunhan/models/membership_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps reward-point boundaries to the expected membership tier', () {
    expect(MembershipTier.fromPoints(0).code, 'BRONZE');
    expect(MembershipTier.fromPoints(99).code, 'BRONZE');
    expect(MembershipTier.fromPoints(100).code, 'SILVER');
    expect(MembershipTier.fromPoints(499).code, 'SILVER');
    expect(MembershipTier.fromPoints(500).code, 'GOLD');
    expect(MembershipTier.fromPoints(999).code, 'GOLD');
    expect(MembershipTier.fromPoints(1000).code, 'DIAMOND');
  });

  test('membership copy does not promise unsupported automatic benefits', () {
    final copy = MembershipTier.allTiers
        .expand((tier) => tier.benefits)
        .join(' ')
        .toLowerCase();

    expect(copy, isNot(contains('giảm 5%')));
    expect(copy, isNot(contains('giảm 10%')));
    expect(copy, isNot(contains('giảm 15%')));
    expect(copy, isNot(contains('x1.2')));
    expect(copy, isNot(contains('sinh nhật')));
    expect(MembershipTier.commonBenefits, hasLength(4));
  });
}
