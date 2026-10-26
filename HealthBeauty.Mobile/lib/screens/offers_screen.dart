import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/format.dart';
import '../core/token_storage.dart';
import '../models/catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _code = TextEditingController();
  bool _checking = false;
  VoucherCheck? _result;
  int _visibleAccountVersion = -1;
  int _checkVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = context.watch<CatalogProvider>().accountVersion;
    if (version != _visibleAccountVersion) {
      _visibleAccountVersion = version;
      _checkVersion++;
      _code.clear();
      _result = null;
      _checking = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isLoggedIn) return;
        final profile = context.read<ProfileProvider>();
        if (profile.customer == null && !profile.loading) profile.load();
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim();
    if (code.isEmpty || _checking) return;
    final catalog = context.read<CatalogProvider>();
    final accountVersion = catalog.accountVersion;
    final request = ++_checkVersion;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _result = null;
    });
    final r = await catalog.validateVoucher(code);
    if (!mounted ||
        request != _checkVersion ||
        catalog.accountVersion != accountVersion) {
      return;
    }
    setState(() {
      _checking = false;
      _result = r;
    });
  }

  Future<void> _refresh() async {
    final catalog = context.read<CatalogProvider>();
    final profile = context.read<ProfileProvider>();
    final id = catalog.accountId;
    await Future.wait([
      catalog.load(force: true),
      catalog.loadMyVouchers(force: true),
      catalog.loadVoucherOffers(force: true),
      if (id != null)
        profile.refreshAfterVoucherRedemption(
          expectedAccountId: id,
          expectedSession: TokenStorage.sessionGeneration,
        ),
    ]);
  }

  Future<void> _confirmRedeem(VoucherOffer offer, int points) async {
    if (points < offer.pointsCost) return;
    final catalog = context.read<CatalogProvider>();
    final profile = context.read<ProfileProvider>();
    final accountVersion = catalog.accountVersion;
    final accountId = catalog.accountId;
    final session = TokenStorage.sessionGeneration;
    bool current() =>
        mounted &&
        accountId != null &&
        catalog.accountVersion == accountVersion &&
        catalog.accountId == accountId &&
        TokenStorage.sessionGeneration == session;
    if (!mounted || !current()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận đổi voucher'),
        content: Text(
          'Bạn sẽ dùng ${offer.pointsCost} điểm để đổi voucher "${offer.promotionName}". '
          'Sau khi đổi, voucher sẽ được thêm vào ví của bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận đổi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !current()) return;
    final result = await catalog.redeemVoucher(
      offer.id,
      expectedPointsCost: offer.pointsCost,
      expectedAccountVersion: accountVersion,
    );
    if (!mounted || !current()) return;
    await profile.refreshAfterVoucherRedemption(
      expectedAccountId: accountId!,
      expectedSession: session,
      confirmedRemainingPoints: result?.remainingPoints,
    );
    if (!mounted || !current()) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(catalog.offerError ?? 'Đổi voucher thất bại.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đổi voucher ${result.code} thành công. Còn ${result.remainingPoints} điểm.',
        ),
        backgroundColor: AppColors.ok,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;
    final points = profile.customer?.rewardPoints ?? 0;
    final availableVouchers = catalog.myVouchers
        .where((voucher) => voucher.isAvailableAt(DateTime.now()))
        .toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'Ưu đãi',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Nhập mã voucher'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    hintText: 'VD: RANGRO100',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _checking ? null : _check,
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kiểm tra'),
              ),
            ],
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            _resultCard(_result!),
          ],
          const SizedBox(height: 8),
          Text(
            'Voucher được áp dụng khi xuất hóa đơn. Mức giảm thực tế phụ thuộc tổng tiền và chương trình khuyến mãi.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Đổi điểm lấy voucher'),
          const SizedBox(height: 8),
          if (!auth.isLoggedIn)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đăng nhập để đổi điểm thưởng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Điểm thưởng và voucher sau khi đổi sẽ được lưu vào tài khoản của bạn.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    icon: const Icon(Icons.login),
                    label: const Text('Đăng nhập'),
                  ),
                ],
              ),
            )
          else ...[
            AppCard(
              color: AppColors.roseContainer.withValues(alpha: 0.35),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.rose),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Điểm thưởng hiện có',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (profile.loading && profile.customer == null)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '$points điểm',
                      style: const TextStyle(
                        color: AppColors.rose,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (catalog.offersLoading && catalog.voucherOffers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (catalog.offerError != null &&
                catalog.voucherOffers.isEmpty)
              ErrorState(
                message: catalog.offerError!,
                onRetry: catalog.loadVoucherOffers,
              )
            else if (catalog.voucherOffers.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.redeem_outlined,
                  title: 'Chưa có voucher để đổi điểm',
                  subtitle: 'Các ưu đãi mới sẽ xuất hiện tại đây',
                ),
              )
            else
              for (final offer in catalog.voucherOffers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VoucherOfferCard(
                    offer: offer,
                    points: points,
                    redeeming: catalog.redeemingVoucherId == offer.id,
                    anotherRedemptionRunning:
                        catalog.redeemingVoucherId != null &&
                        catalog.redeemingVoucherId != offer.id,
                    onRedeem: () => _confirmRedeem(offer, points),
                  ),
                ),
          ],
          if (catalog.vouchersLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (catalog.voucherError != null)
            ErrorState(
              message: catalog.voucherError!,
              onRetry: () => catalog.loadMyVouchers(),
            ),
          if (availableVouchers.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionTitle('Voucher của bạn'),
            const SizedBox(height: 8),
            for (final v in availableVouchers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.roseContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.confirmation_number,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                            if (v.promotionName != null &&
                                v.promotionName!.isNotEmpty)
                              Text(
                                v.promotionName!,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            Text(
                              'Giảm tối đa ${vnd(v.discountValue)}${v.expiresAt != null ? ' · HSD: ${dateStr(v.expiresAt!)}' : ''}',
                              style: const TextStyle(
                                color: AppColors.rose,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _code.text = v.code;
                          _check();
                        },
                        child: const Text('Kiểm tra'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('Chương trình khuyến mãi'),
          const SizedBox(height: 8),
          if (catalog.loading && !catalog.loaded)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (catalog.error != null)
            ErrorState(
              message: catalog.error!,
              onRetry: () => catalog.load(force: true),
            )
          else if (catalog.promotions.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'Hiện chưa có chương trình khuyến mãi',
              ),
            )
          else
            for (final p in catalog.promotions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PromoCard(p: p, cs: cs),
              ),
        ],
      ),
    );
  }

  Widget _resultCard(VoucherCheck r) {
    final color = r.valid ? AppColors.ok : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            r.valid ? Icons.check_circle : Icons.error_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.valid
                  ? '${r.title ?? 'Voucher hợp lệ'}'
                        '${r.value != null ? ' · giảm tối đa ${vnd(r.value!)}' : ''}'
                        '${r.expiresAt != null ? ' · HSD ${dateStr(r.expiresAt!)}' : ''}'
                  : (r.message ?? 'Mã không hợp lệ'),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherOfferCard extends StatelessWidget {
  final VoucherOffer offer;
  final int points;
  final bool redeeming;
  final bool anotherRedemptionRunning;
  final VoidCallback onRedeem;

  const _VoucherOfferCard({
    required this.offer,
    required this.points,
    required this.redeeming,
    required this.anotherRedemptionRunning,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enoughPoints = points >= offer.pointsCost;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.roseContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.redeem, color: AppColors.rose),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.promotionName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Giảm tối đa ${vnd(offer.discountValue)}',
                      style: const TextStyle(
                        color: AppColors.rose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Hạn sử dụng: ${dateStr(offer.expiresAt)}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                size: 18,
                color: enoughPoints ? AppColors.warn : cs.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${offer.pointsCost} điểm',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton(
                onPressed:
                    enoughPoints && !redeeming && !anotherRedemptionRunning
                    ? onRedeem
                    : null,
                child: redeeming
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(enoughPoints ? 'Đổi ngay' : 'Chưa đủ điểm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Promotion p;
  final ColorScheme cs;
  const _PromoCard({required this.p, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  p.discountLabel,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          if (p.condition != null && p.condition!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(p.condition!, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          if (p.endsAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'HSD: ${dateStr(p.endsAt!)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
