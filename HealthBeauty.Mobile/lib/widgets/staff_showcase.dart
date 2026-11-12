import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/staff_gallery_screen.dart';
import 'common.dart';

const staffPosters = <({String name, String asset})>[
  (name: 'Trinh', asset: 'assets/images/ktv_1.webp'),
  (name: 'Puu', asset: 'assets/images/ktv_2.webp'),
  (name: 'Changg', asset: 'assets/images/ktv_3.webp'),
  (name: 'Kiwi', asset: 'assets/images/ktv_4.webp'),
  (name: 'Quỳnh', asset: 'assets/images/ktv_5.webp'),
];

/// Introductory posters, intentionally independent of appointment staff IDs.
class StaffShowcase extends StatelessWidget {
  const StaffShowcase({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(
        'Đội ngũ kỹ thuật viên',
        trailing: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffGalleryScreen()),
          ),
          child: const Text('Xem tất cả'),
        ),
      ),
      const Text(
        'Làm quen cùng đội ngũ HealthBeauty',
        style: TextStyle(color: AppColors.inkMuted),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 320 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 2,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: staffPosters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final poster = staffPosters[index];
            return SizedBox(
              width: 210,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => openStaffPoster(context, index),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Image.asset(
                            poster.asset,
                            fit: BoxFit.contain,
                            cacheWidth: 630,
                            semanticLabel:
                                'Giới thiệu kỹ thuật viên ${poster.name}',
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.person_outline,
                                size: 48,
                                color: AppColors.rose,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'KTV ${poster.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

void openStaffPoster(BuildContext context, int initialIndex) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => StaffPosterViewer(initialIndex: initialIndex),
  ),
);

class StaffPosterViewer extends StatefulWidget {
  const StaffPosterViewer({super.key, required this.initialIndex});
  final int initialIndex;
  @override
  State<StaffPosterViewer> createState() => _StaffPosterViewerState();
}

class _StaffPosterViewerState extends State<StaffPosterViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      title: Text(
        'KTV ${staffPosters[_index].name} · ${_index + 1}/${staffPosters.length}',
      ),
    ),
    body: SafeArea(
      child: PageView.builder(
        controller: _pages,
        itemCount: staffPosters.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.asset(
              staffPosters[index].asset,
              fit: BoxFit.contain,
              semanticLabel: 'Poster KTV ${staffPosters[index].name}',
              errorBuilder: (_, _, _) => const Text(
                'Không tải được ảnh kỹ thuật viên',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
