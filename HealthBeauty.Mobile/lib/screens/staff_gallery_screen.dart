import 'package:flutter/material.dart';

import '../widgets/staff_showcase.dart';

class StaffGalleryScreen extends StatelessWidget {
  const StaffGalleryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đội ngũ kỹ thuật viên')),
    body: ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: staffPosters.length,
      separatorBuilder: (_, _) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final poster = staffPosters[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => openStaffPoster(context, index),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.asset(
                    poster.asset,
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                    semanticLabel: 'Giới thiệu kỹ thuật viên ${poster.name}',
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 180,
                      child: Center(
                        child: Icon(Icons.person_outline, size: 48),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'KTV ${poster.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
