import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/customer.dart';
import '../models/membership_tier.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/common.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'service_packages_screen.dart';
import '../widgets/customer_avatar.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'notification_screen.dart';
import 'invoices_screen.dart';
import 'register_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _storage = FlutterSecureStorage();
  static const _notifKey = 'pref_appointment_notifications';
  bool _appointmentReminder = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final val = await _storage.read(key: _notifKey);
    if (val != null && mounted) {
      setState(() {
        _appointmentReminder = val == 'true';
      });
    }
  }

  Future<void> _setAppointmentReminder(bool value) async {
    setState(() => _appointmentReminder = value);
    await _storage.write(key: _notifKey, value: value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;
    final c = profile.customer;

    if (!auth.isLoggedIn) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chào mừng bạn đến với HealthBeauty',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để theo dõi lịch hẹn, tích lũy điểm thưởng thành viên và nhận các ưu đãi độc quyền.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Đăng ký tài khoản'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final displayName = (c?.fullName.trim().isNotEmpty ?? false)
        ? c!.fullName
        : (auth.account?.name ?? auth.account?.email ?? '');
    final initial = displayName.isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    final points = c?.rewardPoints ?? 0;
    final tier = MembershipTier.fromPoints(points);

    return RefreshIndicator(
      onRefresh: profile.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),

          // Header thông tin người dùng
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tier.primaryColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: CustomerAvatar(
                    radius: 30,
                    url: c?.avatarUrl,
                    initial: initial,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tier.backgroundColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: tier.primaryColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tier.icon,
                                  size: 13,
                                  color: tier.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tier.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: tier.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.account?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (c?.phone != null && c!.phone!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          c.phone!,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lỗi tải dữ liệu nếu có
          if (profile.error != null && c == null)
            ErrorState(message: profile.error!, onRetry: profile.load)
          else ...[
            // Thẻ thành viên kỹ thuật số (Digital Membership Card)
            _buildMembershipCard(context, c, tier, points, profile),
            const SizedBox(height: 20),

            // Nhóm 1: Quản lý cá nhân & Hội viên
            _buildSectionHeader('Hồ sơ & Hội viên'),
            _buildMenuCard([
              _MenuItem(
                icon: Icons.edit_outlined,
                title: 'Chỉnh sửa thông tin hồ sơ',
                subtitle: 'Ảnh đại diện, họ tên, số điện thoại, giới tính',
                onTap: c == null
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(customer: c),
                          ),
                        );
                      },
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                subtitle: 'Xác nhận bằng mật khẩu hiện tại',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
              _MenuItem(
                icon: Icons.military_tech_outlined,
                title: 'Đặc quyền hạng thành viên',
                subtitle: 'Xem quyền lợi các hạng thẻ VIP',
                onTap: () => _showTierBenefits(context, tier),
              ),
              _MenuItem(
                icon: Icons.card_membership_outlined,
                title: 'Gói dịch vụ của tôi',
                subtitle: 'Gói đã mua, lượt còn lại và lịch sử sử dụng',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ServicePackagesScreen(initialOwnedTab: true),
                  ),
                ),
              ),
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Lịch sử hóa đơn',
                subtitle: 'Chi tiết dịch vụ và thanh toán chuyển khoản',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvoicesScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.local_offer_outlined,
                title: 'Ưu đãi & Voucher của bạn',
                subtitle: 'Khám phá mã giảm giá độc quyền',
                onTap: () {
                  mainTab.value = 3; // Chuyển sang Tab Ưu đãi
                },
              ),
            ]),
            const SizedBox(height: 18),

            // Nhóm 2: Cài đặt & Tiện ích
            _buildSectionHeader('Cài đặt ứng dụng'),
            _buildMenuCard([
              _MenuItem(
                icon: Icons.notifications_none_outlined,
                title: 'Hộp thư thông báo',
                subtitle: 'Xem lịch sử thông báo và tin tức',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.notifications_active_outlined,
                title: 'Nhắc nhở lịch hẹn',
                subtitle: 'Nhận thông báo nhắc trước giờ hẹn',
                trailing: Switch(
                  value: _appointmentReminder,
                  activeThumbColor: AppColors.rose,
                  onChanged: _setAppointmentReminder,
                ),
                onTap: () => _setAppointmentReminder(!_appointmentReminder),
              ),
              const _MenuItem(
                icon: Icons.language_outlined,
                title: 'Ngôn ngữ hiển thị',
                trailingText: 'Tiếng Việt',
              ),
            ]),
            const SizedBox(height: 18),

            // Nhóm 3: Trợ giúp & Thông tin
            _buildSectionHeader('Hỗ trợ & Thông tin'),
            _buildMenuCard([
              _MenuItem(
                icon: Icons.headset_mic_outlined,
                title: 'Tổng đài chăm sóc khách hàng',
                subtitle: '1900 8888 (8h00 - 21h00 hàng ngày)',
                onTap: () => _showHotlineDialog(context),
              ),
              _MenuItem(
                icon: Icons.help_outline,
                title: 'Câu hỏi thường gặp (FAQ)',
                subtitle: 'Quy định đặt hẹn, tích điểm, hủy lịch',
                onTap: () => _showFaqDialog(context),
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Chính sách & Điều khoản dịch vụ',
                onTap: () => _showTermsDialog(context),
              ),
            ]),
            const SizedBox(height: 20),

            // Nút đăng xuất
            AppCard(
              onTap: () => _confirmLogout(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Đăng xuất tài khoản',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Footer phiên bản
            Center(
              child: Text(
                'HealthBeauty Spa & Clinic • Phiên bản 1.0.0',
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Thẻ VIP Card phong cách sang trọng mô phỏng thẻ thành viên Spa
  Widget _buildMembershipCard(
    BuildContext context,
    Customer? c,
    MembershipTier tier,
    int points,
    ProfileProvider profile,
  ) {
    final progress = tier.progress(points);
    final pointsNeeded = tier.pointsNeeded(points);
    final cardId = c != null
        ? '#HB-${c.id.toString().padLeft(6, '0')}'
        : '#HB-000000';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2C2427),
            tier.code == 'DIAMOND'
                ? const Color(0xFF16323B)
                : tier.code == 'GOLD'
                ? const Color(0xFF3D2E14)
                : const Color(0xFF3B272D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng trên: Logo thương hiệu & Tên hạng thẻ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.spa, color: Colors.white70, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'HEALTHBEAUTY VIP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tier.primaryColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tier.primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tier.icon, size: 14, color: tier.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        tier.name.toUpperCase(),
                        style: TextStyle(
                          color: tier.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Dòng giữa: Điểm tích lũy và Mã thẻ
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐIỂM TÍCH LŨY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  cardId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Thanh tiến trình lên hạng
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(tier.primaryColor),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tier.nextPoints == null
                      ? 'Đã đạt hạng cao nhất'
                      : 'Còn thiếu ${pointsNeeded ?? 0} điểm để lên ${tier.nextTierName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Nút Check-in QR & Lịch sử tích điểm
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text(
                      'QR Check-in',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () =>
                        _showQrCheckIn(context, cardId, c?.fullName ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text(
                      'Lịch sử điểm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _showPoints(context, profile),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: AppColors.outline.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }

  void _showQrCheckIn(BuildContext context, String code, String name) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mã thẻ thành viên',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đưa mã này cho nhân viên lễ tân khi đến cơ sở để check-in và tích lũy điểm dịch vụ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: AppColors.ink),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showTierBenefits(BuildContext context, MembershipTier currentTier) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đặc quyền hạng thành viên',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tích lũy điểm khi sử dụng dịch vụ để nâng hạng và nhận nhiều ưu đãi độc quyền.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: MembershipTier.allTiers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final t = MembershipTier.allTiers[i];
                      final isCurrent = t.code == currentTier.code;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCurrent ? t.backgroundColor : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent
                                ? t.primaryColor
                                : AppColors.outline,
                            width: isCurrent ? 1.6 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(t.icon, color: t.primaryColor, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  t.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: t.primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Hạng hiện tại',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    t.nextPoints == null
                                        ? 'Từ ${t.minPoints} điểm'
                                        : '${t.minPoints} - ${t.nextPoints! - 1} điểm',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (final b in t.benefits)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        b,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHotlineDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic, color: AppColors.rose),
            SizedBox(width: 10),
            Text('Hỗ trợ khách hàng'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn cần hỗ trợ về dịch vụ hoặc thay đổi lịch hẹn?'),
            SizedBox(height: 12),
            Text(
              '• Hotline miễn phí: 1900 8888',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '• Thời gian hỗ trợ: 08:00 - 21:00 (Tất cả các ngày)',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '• Email tiếp nhận: hotro@healthbeauty.vn',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Câu hỏi thường gặp (FAQ)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: const [
                      _FaqItem(
                        question: '1. Làm thế nào để tích lũy điểm thưởng?',
                        answer: 'Điểm thưởng được tự động cộng vào tài khoản sau khi bạn hoàn thành và thanh toán các liệu trình dịch vụ tại spa (tỷ lệ 5% giá trị hóa đơn).',
                      ),
                      _FaqItem(
                        question: '2. Tôi có thể hủy hoặc đổi lịch hẹn không?',
                        answer: 'Bạn có thể bấm vào tab "Lịch hẹn" để hủy hoặc chọn giờ hẹn mới trước tối thiểu 2 giờ trước giờ hẹn dự kiến.',
                      ),
                      _FaqItem(
                        question: '3. Điểm thưởng có thời hạn sử dụng không?',
                        answer: 'Điểm thưởng của thành viên có hiệu lực trong vòng 12 tháng kể từ ngày giao dịch gần nhất.',
                      ),
                      _FaqItem(
                        question: '4. Check-in tại quầy lễ tân như thế nào?',
                        answer: 'Khi đến cơ sở, bạn chỉ cần mở mục "QR Check-in" trên thẻ VIP để nhân viên quét xác nhận tiếp đón nhanh chóng.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Chính sách & Bảo mật'),
        content: const SingleChildScrollView(
          child: Text(
            'HealthBeauty cam kết bảo mật tuyệt đối thông tin cá nhân của quý khách hàng theo tiêu chuẩn an toàn dữ liệu.\n\n'
            '1. Thông tin họ tên và số điện thoại chỉ được dùng cho mục đích xác nhận lịch hẹn và liên hệ tư vấn liệu trình.\n\n'
            '2. Điểm thưởng và voucher gắn liền với tài khoản định danh duy nhất và không có giá trị quy đổi thành tiền mặt.\n\n'
            '3. Mọi thắc mắc và khiếu nại về chất lượng phục vụ xin vui lòng gửi qua hotline 1900 8888.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showPoints(BuildContext context, ProfileProvider profile) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lịch sử điểm thưởng',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (profile.transactions.isEmpty)
                  const SizedBox(
                    height: 160,
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'Chưa có giao dịch điểm',
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: profile.transactions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          _pointRow(profile.transactions[i], cs),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pointRow(PointTransaction t, ColorScheme cs) {
    final plus = t.points >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(t.note?.isNotEmpty == true ? t.note! : t.type),
      subtitle: t.date == null ? null : Text(dateStr(t.date!)),
      trailing: Text(
        '${plus ? '+' : ''}${t.points}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: plus ? AppColors.ok : AppColors.danger,
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) {
      mainTab.value = 0;
      await auth.logout();
    }
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingText;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
