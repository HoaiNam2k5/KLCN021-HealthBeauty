import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog.dart';
import '../models/service_price_filter.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import '../widgets/service_tile.dart';
import '../widgets/service_price_filter.dart';
import 'service_detail_screen.dart';
import 'service_packages_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();
  int? _categoryId;
  ServicePriceRange _priceRange = const ServicePriceRange();
  int _tab = 0; // 0 = dịch vụ, 1 = combo

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final q = _search.text.trim().toLowerCase();

    final services = catalog.services.where((s) {
      if (_categoryId != null && s.categoryId != _categoryId) return false;
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      if (!_priceRange.includes(s.price)) return false;
      return true;
    }).toList();

    final combos = catalog.combos
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Dịch vụ',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ServicePackagesScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.card_membership_outlined),
                  label: const Text('Gói dịch vụ'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm dịch vụ, combo...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Dịch vụ')),
              ButtonSegment(value: 1, label: Text('Combo')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        if (_tab == 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48 + (textScale - 1).clamp(0, 2) * 20,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ServicePriceFilter(
                    range: _priceRange,
                    prices: catalog.services.map((s) => s.price).toList(),
                    onChanged: (range) => setState(() => _priceRange = range),
                  ),
                ),
                _chip(
                  'Tất cả',
                  _categoryId == null,
                  () => setState(() => _categoryId = null),
                ),
                for (final c in catalog.categories)
                  _chip(
                    c.name,
                    _categoryId == c.id,
                    () => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Expanded(child: _body(catalog, services, combos)),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _body(
    CatalogProvider catalog,
    List<Service> services,
    List<Combo> combos,
  ) {
    if (catalog.loading && !catalog.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.error != null && !catalog.loaded) {
      return ErrorState(
        message: catalog.error!,
        onRetry: () => catalog.load(force: true),
      );
    }

    final isServiceTab = _tab == 0;
    final count = isServiceTab ? services.length : combos.length;

    return RefreshIndicator(
      onRefresh: () => catalog.load(force: true),
      child: count == 0
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.spa_outlined,
                    title: isServiceTab
                        ? 'Chưa có dịch vụ phù hợp'
                        : 'Chưa có combo nào đang áp dụng',
                    subtitle:
                        isServiceTab &&
                            (_priceRange.isActive ||
                                _categoryId != null ||
                                _search.text.trim().isNotEmpty)
                        ? 'Hãy thử thay đổi hoặc xóa bớt bộ lọc'
                        : 'Kéo xuống để tải lại',
                  ),
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final columns = constraints.maxWidth < 350 || scale > 1.3
                    ? 1
                    : constraints.maxWidth >= 700
                    ? 3
                    : 2;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  itemCount: count,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 320 + (scale - 1).clamp(0, 2) * 160,
                  ),
                  itemBuilder: (context, i) {
                    if (isServiceTab) {
                      final s = services[i];
                      return ServiceCard(
                        service: s,
                        categoryName: catalog.categoryName(s.categoryId),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ServiceDetailScreen(service: s),
                          ),
                        ),
                      );
                    }
                    final c = combos[i];
                    return ComboCard(
                      combo: c,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComboDetailScreen(combo: c),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
