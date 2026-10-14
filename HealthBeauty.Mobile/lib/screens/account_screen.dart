import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;
    final c = profile.customer;

    final displayName = (c?.fullName.trim().isNotEmpty ?? false)
        ? c!.fullName
        : (auth.account?.name ?? auth.account?.email ?? '');
    final initial = displayName.isEmpty ? '?' : displayName.trim()[0].toUpperCase();

    return RefreshIndicator(
      onRefresh: profile.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text('Tài khoản',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.primaryContainer,
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(auth.account?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      if (c?.phone != null && c!.phone!.isNotEmpty)
                        Text(c.phone!, style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (profile.error != null && c == null)
            ErrorState(message: profile.error!, onRetry: profile.load)
          else
            AppCard(
              color: AppColors.sageContainer,
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.onSageContainer, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Điểm thưởng',
                            style: TextStyle(color: AppColors.onSageContainer)),
                        profile.loading && c == null
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text('${c?.rewardPoints ?? 0} điểm',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSageContainer)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPoints(context, profile),
                    child: const Text('Lịch sử'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _action(Icons.edit_outlined, 'Chỉnh sửa hồ sơ',
              c == null ? null : () => _editProfile(context, c)),
          _action(Icons.logout, 'Đăng xuất', () => _confirmLogout(context),
              color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color ?? AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ),
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
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lịch sử điểm thưởng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                      itemBuilder: (_, i) => _pointRow(profile.transactions[i], cs),
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

  Future<void> _editProfile(BuildContext context, Customer c) async {
    final name = TextEditingController(text: c.fullName);
    final phone = TextEditingController(text: c.phone ?? '');
    String gender = c.gender ?? '';
    String? error;
    final profile = context.read<ProfileProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Chỉnh sửa hồ sơ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 12),
                const Text('Giới tính'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in const ['Nữ', 'Nam', 'Khác'])
                      ChoiceChip(
                        label: Text(g),
                        selected: gender == g,
                        onSelected: (_) => setState(() => gender = g),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  setState(() => error = 'Họ tên không được để trống');
                  return;
                }
                final ok = await profile.update(
                  fullName: name.text.trim(),
                  phone: phone.text.trim(),
                  gender: gender,
                );
                if (!dialogContext.mounted) return;
                if (ok) {
                  Navigator.pop(dialogContext);
                } else {
                  setState(() => error = profile.error);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    phone.dispose();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (ok == true) await auth.logout();
  }
}
