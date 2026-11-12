import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'catalog_image.dart';

/// Widget so sánh hình ảnh Trước & Sau (Before / After) liệu trình kéo chạm tương tác
class BeforeAfterSlider extends StatefulWidget {
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final double initialPosition;
  final double height;
  final String beforeLabel;
  final String afterLabel;

  const BeforeAfterSlider({
    super.key,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.initialPosition = 0.5,
    this.height = 200,
    this.beforeLabel = 'Trước liệu trình',
    this.afterLabel = 'Sau liệu trình',
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  late double _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition.clamp(0.05, 0.95);
  }

  void _updatePosition(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    setState(() {
      _position = (localX / totalWidth).clamp(0.05, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.compare_arrows, size: 20, color: AppColors.rose),
            const SizedBox(width: 6),
            const Text(
              'Hiệu quả thực tế (Trước & Sau)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              'Kéo để so sánh',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final dividerX = width * _position;

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: width,
                height: widget.height,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    _updatePosition(details.localPosition.dx, width);
                  },
                  onTapDown: (details) {
                    _updatePosition(details.localPosition.dx, width);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Ảnh "Sau" (Lớp nền đầy đủ)
                      _buildImageLayer(
                        imageUrl: widget.afterImageUrl,
                        fallbackColor: const Color(0xFFF3ECE9),
                        fallbackIcon: Icons.auto_awesome,
                        fallbackText: 'Làn da tươi sáng, đều màu sau liệu trình',
                      ),

                      // 2. Ảnh "Trước" (Lớp trên được cắt theo _position)
                      ClipRect(
                        clipper: _HorizontalClipper(position: _position),
                        child: _buildImageLayer(
                          imageUrl: widget.beforeImageUrl,
                          fallbackColor: const Color(0xFFE2D9D7),
                          fallbackIcon: Icons.face_retouching_natural,
                          fallbackText: 'Tình trạng da ban đầu trước điều trị',
                        ),
                      ),

                      // 3. Nhãn "Trước"
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _buildBadge(
                          label: widget.beforeLabel,
                          backgroundColor: Colors.black.withValues(alpha: 0.65),
                          textColor: Colors.white,
                        ),
                      ),

                      // 4. Nhãn "Sau"
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildBadge(
                          label: widget.afterLabel,
                          backgroundColor: AppColors.rose.withValues(alpha: 0.85),
                          textColor: Colors.white,
                        ),
                      ),

                      // 5. Thanh trượt phân tách (Divider line)
                      Positioned(
                        left: dividerX - 1.5,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: Colors.white,
                        ),
                      ),

                      // 6. Nút tròn tay cầm kéo (Slider Handle)
                      Positioned(
                        left: dividerX - 18,
                        top: (widget.height / 2) - 18,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.rose, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.swap_horiz,
                            size: 20,
                            color: AppColors.rose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageLayer({
    required String? imageUrl,
    required Color fallbackColor,
    required IconData fallbackIcon,
    required String fallbackText,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CatalogImage(
        imageUrl: imageUrl,
        semanticLabel: 'Hình ảnh so sánh kết quả',
      );
    }

    return Container(
      color: fallbackColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fallbackIcon, size: 36, color: AppColors.inkMuted),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                fallbackText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  final double position;
  _HorizontalClipper({required this.position});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) {
    return oldClipper.position != position;
  }
}
