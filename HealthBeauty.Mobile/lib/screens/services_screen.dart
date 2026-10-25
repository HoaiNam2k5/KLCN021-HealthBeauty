import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/catalog.dart';
import '../providers/catalog_provider.dart';
import '../widgets/common.dart';
import '../widgets/service_tile.dart';
import 'service_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();
  int? _categoryId;
  double? _minimumPrice;
  double? _maximumPrice;
  int _tab = 0; // 0 = dịch vụ, 1 = combo

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final q = _search.text.trim().toLowerCase();

    final services = catalog.services.where((s) {
      if (_categoryId != null && s.categoryId != _categoryId) return false;
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      if (_minimumPrice != null && s.price < _minimumPrice!) return false;
      if (_maximumPrice != null && s.price > _maximumPrice!) return false;
      return true;
    }).toList();

    final combos = catalog.combos
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Dịch vụ',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
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
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _priceChip(catalog.services),
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

  Widget _priceChip(List<Service> services) {
    final active = _minimumPrice != null || _maximumPrice != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        key: const Key('price_filter_button'),
        avatar: const Icon(Icons.tune, size: 18),
        label: Text(_priceFilterLabel),
        selected: active,
        onSelected: services.isEmpty ? null : (_) => _showPriceFilter(services),
        onDeleted: active
            ? () => setState(() {
                _minimumPrice = null;
                _maximumPrice = null;
              })
            : null,
        deleteIcon: const Icon(Icons.close, size: 18),
      ),
    );
  }

  String get _priceFilterLabel {
    if (_minimumPrice != null && _maximumPrice != null) {
      return '${vnd(_minimumPrice!)} – ${vnd(_maximumPrice!)}';
    }
    if (_minimumPrice != null) return 'Từ ${vnd(_minimumPrice!)}';
    if (_maximumPrice != null) return 'Đến ${vnd(_maximumPrice!)}';
    return 'Khoảng giá';
  }

  Future<void> _showPriceFilter(List<Service> services) async {
    final prices = services.map((service) => service.price);
    final availableMinimum = prices.reduce((a, b) => a < b ? a : b);
    final availableMaximum = prices.reduce((a, b) => a > b ? a : b);

    final result = await showModalBottomSheet<_PriceFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PriceFilterSheet(
        initialMinimum: _minimumPrice,
        initialMaximum: _maximumPrice,
        availableMinimum: availableMinimum,
        availableMaximum: availableMaximum,
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _minimumPrice = result.minimum;
      _maximumPrice = result.maximum;
    });
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
    final hasServiceFilters =
        _categoryId != null ||
        _search.text.trim().isNotEmpty ||
        _minimumPrice != null ||
        _maximumPrice != null;

    return RefreshIndicator(
      onRefresh: () => catalog.load(force: true),
      child: count == 0
          ? ListView(
              children: [
                SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.spa_outlined,
                    title: isServiceTab
                        ? 'Chưa có dịch vụ phù hợp'
                        : 'Chưa có combo nào đang áp dụng',
                    subtitle: isServiceTab && hasServiceFilters
                        ? 'Hãy thử thay đổi hoặc xóa bớt bộ lọc'
                        : 'Kéo xuống để tải lại',
                  ),
                ),
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.60,
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
            ),
    );
  }
}

class _PriceFilterResult {
  final double? minimum;
  final double? maximum;

  const _PriceFilterResult({this.minimum, this.maximum});
}

class _PriceFilterSheet extends StatefulWidget {
  final double? initialMinimum;
  final double? initialMaximum;
  final double availableMinimum;
  final double availableMaximum;

  const _PriceFilterSheet({
    required this.initialMinimum,
    required this.initialMaximum,
    required this.availableMinimum,
    required this.availableMaximum,
  });

  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _minimumController = TextEditingController(
      text: widget.initialMinimum?.round().toString() ?? '',
    );
    _maximumController = TextEditingController(
      text: widget.initialMaximum?.round().toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  double? _parsePrice(String value) {
    final digits = value.replaceAll(RegExp('[^0-9]'), '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  void _apply() {
    final minimum = _parsePrice(_minimumController.text);
    final maximum = _parsePrice(_maximumController.text);
    if ((minimum != null && minimum < widget.availableMinimum) ||
        (maximum != null && maximum < widget.availableMinimum)) {
      setState(() {
        _validationMessage =
            'Mức giá không được thấp hơn ${vnd(widget.availableMinimum)}.';
      });
      return;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      setState(() {
        _validationMessage = 'Giá tối thiểu không được lớn hơn giá tối đa.';
      });
      return;
    }
    Navigator.pop(
      context,
      _PriceFilterResult(minimum: minimum, maximum: maximum),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Lọc theo khoảng giá',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Giá dịch vụ hiện có: ${vnd(widget.availableMinimum)} – ${vnd(widget.availableMaximum)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('minimum_price_field'),
                  controller: _minimumController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Giá tối thiểu',
                    suffixText: '₫',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                child: Text('–'),
              ),
              Expanded(
                child: TextField(
                  key: const Key('maximum_price_field'),
                  controller: _maximumController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Giá tối đa',
                    suffixText: '₫',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _validationMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                key: const Key('clear_price_filter'),
                onPressed: () =>
                    Navigator.pop(context, const _PriceFilterResult()),
                child: const Text('Xóa bộ lọc'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('apply_price_filter'),
                onPressed: _apply,
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
