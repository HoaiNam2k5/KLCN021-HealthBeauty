import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/spa_location.dart';

class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});
  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  bool _tileError = false;

  Future<void> _open(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the address accessible if the device has no URL handler.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được bản đồ. Bạn có thể sao chép địa chỉ bên dưới.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cơ sở HealthBeauty')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Hẹn gặp bạn tại spa',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tìm vị trí và chỉ đường đến cơ sở.',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 340,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: SpaLocation.point,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.healthbeauty.mobile',
                  maxNativeZoom: 19,
                  errorTileCallback: (_, _, _) {
                    if (!_tileError && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _tileError = true);
                      });
                    }
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: SpaLocation.point,
                      width: 160,
                      height:
                          80 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14)
                                  .clamp(0, 60) *
                              2,
                      alignment: Alignment.bottomCenter,
                      child: Semantics(
                        label: 'Vị trí HealthBeauty, ${SpaLocation.address}',
                        child: Column(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  SpaLocation.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: AppColors.rose,
                              size: 42,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _open(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_tileError)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Chưa tải được bản đồ. Kiểm tra kết nối hoặc mở Google Maps để xem vị trí.',
            ),
          ),
        const SizedBox(height: 20),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.place_outlined, color: AppColors.rose),
          title: Text(
            SpaLocation.name,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(SpaLocation.address),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _open(SpaLocation.directionsUrl),
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Chỉ đường'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _open(SpaLocation.mapUrl),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Mở Google Maps'),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: SpaLocation.address),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép địa chỉ')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Sao chép địa chỉ'),
        ),
      ],
    ),
  );
}
