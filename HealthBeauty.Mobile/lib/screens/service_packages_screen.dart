import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/service_package.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/service_package_provider.dart';
import '../widgets/catalog_image.dart';
import '../widgets/common.dart';
import 'customer_package_detail_screen.dart';
import 'login_screen.dart';

class ServicePackagesScreen extends StatefulWidget {
  final bool initialOwnedTab;
  const ServicePackagesScreen({super.key, this.initialOwnedTab = false});
  @override
  State<ServicePackagesScreen> createState() => _ServicePackagesScreenState();
}

class _ServicePackagesScreenState extends State<ServicePackagesScreen> {
  final _search = TextEditingController();
  bool _prompting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ServicePackageProvider>().loadCatalog();
      context.read<ServicePackageProvider>().loadMine();
      context.read<CatalogProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<bool> _login() async {
    if (context.read<AuthProvider>().isLoggedIn) return true;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted || ok != true || !context.read<AuthProvider>().isLoggedIn) {
      return false;
    }
    await context.read<ServicePackageProvider>().loadMine();
    return mounted && context.read<AuthProvider>().isLoggedIn;
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _purchase(ServicePackageOffer offer) async {
    if (_prompting) return;
    setState(() => _prompting = true);
    try {
      if (!await _login() || !mounted) return;
      final provider = context.read<ServicePackageProvider>();
      final version = provider.accountVersion;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Đăng ký mua gói'),
          content: Text(
            '${offer.name}\n${vnd(offer.price)} · ${offer.validityDays} ngày kể từ khi thanh toán.\n\nĐăng ký sẽ ở trạng thái chờ thanh toán. Bạn có thể chuyển khoản ngay trong app; gói chỉ được kích hoạt sau khi hệ thống nhận tiền. Giá chính thức do hệ thống xác nhận khi đăng ký.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Đăng ký mua'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      if (version != provider.accountVersion ||
          !context.read<AuthProvider>().isLoggedIn) {
        _message('Phiên đăng nhập đã thay đổi. Vui lòng thực hiện lại.');
        return;
      }
      final owned = await provider.purchase(offer.id);
      if (!mounted ||
          version != provider.accountVersion ||
          !context.read<AuthProvider>().isLoggedIn) {
        return;
      }
      if (owned == null) {
        _message(provider.actionError ?? 'Chưa đăng ký được gói.');
        return;
      }
      _message(
        'Đã đăng ký ${owned.name}. Mở thanh toán chuyển khoản để kích hoạt gói.',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CustomerPackageDetailScreen(customerPackageId: owned.id),
        ),
      );
      if (mounted && version == provider.accountVersion) {
        await provider.loadMine();
      }
    } finally {
      if (mounted) setState(() => _prompting = false);
    }
  }

  String _serviceName(int id) {
    for (final service in context.read<CatalogProvider>().services) {
      if (service.id == id) return service.name;
    }
    return 'Dịch vụ #$id';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServicePackageProvider>();
    context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final query = _search.text.trim().toLowerCase();
    final offers = provider.catalog
        .where((x) => x.name.toLowerCase().contains(query))
        .toList();
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialOwnedTab ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gói dịch vụ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gói đang bán'),
              Tab(text: 'Gói của tôi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tìm gói dịch vụ',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: provider.loadCatalog,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        if (provider.catalogLoading)
                          const LinearProgressIndicator(),
                        if (provider.catalogError != null)
                          ErrorState(
                            message: provider.catalogError!,
                            onRetry: provider.loadCatalog,
                          ),
                        if (!provider.catalogLoading &&
                            provider.catalogError == null &&
                            offers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Chưa có gói dịch vụ phù hợp. Kéo xuống để cập nhật.',
                            ),
                          ),
                        for (final offer in offers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 150,
                                    width: double.infinity,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CatalogImage(
                                        imageUrl: offer.imageUrl,
                                        semanticLabel: offer.name,
                                        icon: Icons.inventory_2_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    offer.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${vnd(offer.price)} · Hạn dùng ${offer.validityDays} ngày sau thanh toán',
                                  ),
                                  const SizedBox(height: 8),
                                  for (final item in offer.items)
                                    Text(
                                      '• ${_serviceName(item.serviceId)}: ${item.sessions} lượt',
                                    ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed:
                                          _prompting ||
                                              provider.purchasing ||
                                              provider.cancelling
                                          ? null
                                          : () => _purchase(offer),
                                      child: const Text('Đăng ký mua gói'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            !auth.isLoggedIn
                ? Center(
                    child: FilledButton(
                      onPressed: () => _login(),
                      child: const Text('Đăng nhập để xem gói của tôi'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: provider.loadMine,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (provider.mineLoading)
                          const LinearProgressIndicator(),
                        if (provider.mineError != null)
                          ErrorState(
                            message: provider.mineError!,
                            onRetry: provider.loadMine,
                          ),
                        if (!provider.mineLoading &&
                            provider.mineError == null &&
                            provider.mine.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Bạn chưa có gói dịch vụ. Chọn Gói đang bán để xem và đăng ký.',
                            ),
                          ),
                        for (final owned in provider.mine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerPackageDetailScreen(
                                      customerPackageId: owned.id,
                                    ),
                                  ),
                                );
                                if (mounted) await provider.loadMine();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    owned.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    'Mã gói đã mua #${owned.id} · ${owned.statusLabel}',
                                  ),
                                  Text(vnd(owned.price)),
                                  if (owned.expiresAt != null)
                                    Text(
                                      'Hết hạn: ${dateStr(owned.expiresAt!)} ${timeStr(owned.expiresAt!)}',
                                    ),
                                  const SizedBox(height: 8),
                                  for (final item in owned.items)
                                    Text(
                                      '${item.serviceName}: còn ${item.remaining}, có thể đặt ${item.available}, đang giữ ${item.reserved} lượt',
                                    ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Xem chi tiết và lịch sử sử dụng →',
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
