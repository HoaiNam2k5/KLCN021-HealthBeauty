import 'package:flutter/material.dart';

class CustomerAvatar extends StatelessWidget {
  final String? url;
  final String initial;
  final double radius;

  const CustomerAvatar({
    super.key,
    this.url,
    required this.initial,
    this.radius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
    final uri = Uri.tryParse(url?.trim() ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: Image.network(
          uri.toString(),
          key: ValueKey(uri.toString()),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}
