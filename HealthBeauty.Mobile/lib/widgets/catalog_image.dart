import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class CatalogImage extends StatelessWidget {
  final String? imageUrl;
  final String? semanticLabel;
  final IconData icon;

  const CatalogImage({
    super.key,
    required this.imageUrl,
    this.semanticLabel,
    this.icon = Icons.spa_outlined,
  });

  Widget _placeholder(String message) => Container(
    color: AppColors.roseContainer,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: AppColors.rose),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(color: AppColors.rose, fontSize: 12),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return _placeholder('Chưa có ảnh');
    }
    return Image.network(
      url,
      key: ValueKey(url),
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder('Đang tải ảnh'),
      errorBuilder: (_, _, _) => _placeholder('Không tải được ảnh'),
    );
  }
}
