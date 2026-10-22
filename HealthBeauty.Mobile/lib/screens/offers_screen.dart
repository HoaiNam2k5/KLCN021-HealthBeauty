import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/format.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';

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

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final cs = Theme.of(context).colorScheme;
    final availableVouchers = catalog.myVouchers
        .where((voucher) => voucher.isAvailableAt(DateTime.now()))
        .toList();

    return RefreshIndicator(
      onRefresh: () => catalog.load(force: true),
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
