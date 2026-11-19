import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for inspecting modern split-APK bundles (.apks, .xapk) and APK ABIs.
class SplitApkInspectorSheet extends StatelessWidget {
  final String bundleName;
  final bool isPage;

  const SplitApkInspectorSheet({
    super.key,
    this.bundleName = 'com.example.app_release.apks',
    this.isPage = false,
  });

  static Future<void> show(BuildContext context, {String bundleName = 'com.example.app_release.apks'}) {
    return DedicatedToolPage.open(
      context,
      title: 'Split-APK & Bundle Inspector',
      subtitle: 'Inspection of .apks, .xapk & Native ABI Architectures',
      icon: Icons.android_rounded,
      child: SplitApkInspectorSheet(bundleName: bundleName, isPage: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subApks = [
      {'name': 'base.apk', 'type': 'Core Manifest & Dex', 'size': '42.8 MB', 'color': const Color(0xFF2563EB)},
      {'name': 'config.arm64_v8a.apk', 'type': 'Native ABI (64-bit ARM)', 'size': '18.4 MB', 'color': const Color(0xFF16A34A)},
      {'name': 'config.xxhdpi.apk', 'type': 'Display Density (480dpi)', 'size': '8.2 MB', 'color': const Color(0xFFD97706)},
      {'name': 'config.en.apk', 'type': 'Locale Resources (English)', 'size': '1.2 MB', 'color': const Color(0xFF9333EA)},
    ];

    return Container(
      constraints: isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(Icons.android_rounded, size: 20, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Split-APK & Bundle Inspector', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text(bundleName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // App Manifest Quick Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('TARGET SDK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('35 (Android 15)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                Column(
                  children: [
                    Text('PRIMARY ARCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('arm64-v8a', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
                Column(
                  children: [
                    Text('TOTAL SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('70.6 MB', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Constituent Split Modules (4)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: subApks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final apk = subApks[idx];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: apk['color'] as Color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(apk['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                            Text(apk['type'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Text(apk['size'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unpacked split modules to Vault / APKs'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.folder_zip_outlined, size: 18, color: Colors.white),
              label: const Text('Unpack Split Modules', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
