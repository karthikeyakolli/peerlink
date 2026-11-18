import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../design_system/components/floating_audio_mini_player.dart';
import '../../design_system/components/stash_tray_dock.dart';
import 'received_vault_view.dart';

/// Primary Xiaomi-inspired Minimalist Light File Manager launch screen.
/// Keeps 100% focus on managing files and folders, surfacing P2P sharing
/// smoothly via [ContextualShareSheet] only when the user requests it.
class FileManagerHomeScreen extends StatelessWidget {
  final void Function(int targetTabIndex)? onNavigate;

  const FileManagerHomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'PeerLink',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('appbar_sync_spaces_button'),
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF334155)),
            tooltip: 'Folder Sync & Backup',
            onPressed: () {
              HapticFeedback.selectionClick();
              onNavigate?.call(3);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF334155)),
            tooltip: 'Search & Query',
            onPressed: () {
              HapticFeedback.selectionClick();
              onNavigate?.call(4);
            },
          ),
          IconButton(
            key: const Key('appbar_contextual_share_button'),
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Icon(Icons.share_rounded, size: 17, color: Color(0xFF2563EB)),
            ),
            tooltip: 'Share & Receive',
            onPressed: () {
              HapticFeedback.selectionClick();
              ContextualShareSheet.show(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF334155)),
            tooltip: 'Settings & Security',
            onPressed: () {
              HapticFeedback.selectionClick();
              onNavigate?.call(5);
            },
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(child: ReceivedVaultView()),
          StashTrayDock(),
          FloatingAudioMiniPlayer(),
        ],
      ),
    );
  }
}
