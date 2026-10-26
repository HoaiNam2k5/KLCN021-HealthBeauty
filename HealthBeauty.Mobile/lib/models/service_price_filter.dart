class ServicePriceRange {
  final double? minimum, maximum;
  const ServicePriceRange({this.minimum, this.maximum});

  bool get isActive => minimum != null || maximum != null;
  bool includes(double price) =>
      (minimum == null || price >= minimum!) &&
      (maximum == null || price <= maximum!);

  factory ServicePriceRange.parse(String minimum, String maximum) {
    double? parse(String text) {
      if (text.trim().isEmpty) return null;
      final value = double.tryParse(text.trim());
      if (value == null || !value.isFinite || value < 0) {
        throw const FormatException('Giá phải là số không âm hợp lệ.');
      }
      return value;
    }

    final min = parse(minimum), max = parse(maximum);
    if (min != null && max != null && min > max) {
      throw const FormatException(
        'Giá tối thiểu không được lớn hơn giá tối đa.',
      );
    }
    return ServicePriceRange(minimum: min, maximum: max);
  }
}
