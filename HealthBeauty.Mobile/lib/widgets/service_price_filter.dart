import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../models/service_price_filter.dart';

class ServicePriceFilter extends StatelessWidget {
  const ServicePriceFilter({
    super.key,
    required this.range,
    required this.prices,
    required this.onChanged,
  });
  final ServicePriceRange range;
  final List<double> prices;
  final ValueChanged<ServicePriceRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = range.minimum != null && range.maximum != null
        ? '${vnd(range.minimum!)} – ${vnd(range.maximum!)}'
        : range.minimum != null
        ? 'Từ ${vnd(range.minimum!)}'
        : range.maximum != null
        ? 'Đến ${vnd(range.maximum!)}'
        : 'Khoảng giá';
    return FilterChip(
      key: const Key('price_filter_button'),
      avatar: const Icon(Icons.tune, size: 18),
      label: Text(label),
      selected: range.isActive,
      onDeleted: range.isActive
          ? () => onChanged(const ServicePriceRange())
          : null,
      onSelected: prices.isEmpty
          ? null
          : (_) async {
              final result = await showModalBottomSheet<ServicePriceRange>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _PriceSheet(range: range, prices: prices),
              );
              if (context.mounted && result != null) onChanged(result);
            },
    );
  }
}

class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.range, required this.prices});
  final ServicePriceRange range;
  final List<double> prices;
  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final _min = TextEditingController(
    text: widget.range.minimum?.toInt().toString() ?? '',
  );
  late final _max = TextEditingController(
    text: widget.range.maximum?.toInt().toString() ?? '',
  );
  String? _error;
  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      Navigator.pop(context, ServicePriceRange.parse(_min.text, _max.text));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = [...widget.prices]..sort();
    Widget field(String key, String label, TextEditingController controller) =>
        Expanded(
          child: TextField(
            key: Key(key),
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            decoration: InputDecoration(
              labelText: label,
              suffixText: '₫',
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
        );
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
          Text('Giá hiện có: ${vnd(prices.first)} – ${vnd(prices.last)}'),
          const Text('Để trống để không giới hạn. Có thể chọn từ 0đ.'),
          const SizedBox(height: 16),
          Row(
            children: [
              field('minimum_price_field', 'Giá tối thiểu', _min),
              const SizedBox(width: 12),
              field('maximum_price_field', 'Giá tối đa', _max),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                key: const Key('clear_price_filter'),
                onPressed: () =>
                    Navigator.pop(context, const ServicePriceRange()),
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
