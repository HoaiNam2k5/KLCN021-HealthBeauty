import 'package:flutter/material.dart';

/// The supplied brand artwork, displayed whole rather than cropped to a circle.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo HealthBeauty',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
