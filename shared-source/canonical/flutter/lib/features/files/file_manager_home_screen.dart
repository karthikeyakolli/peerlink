import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/ransomware_canary_guard.dart';
import '../../design_system/components/ransomware_alert_modal.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../design_system/components/floating_audio_mini_player.dart';
import '../../design_system/components/stash_tray_dock.dart';
import '../converter/file_converter_flow_view.dart';
import '../media/media_hub_flow_view.dart';
import '../share/share_hub_flow_view.dart';
import 'received_vault_view.dart';

/// Primary Xiaomi-inspired Minimalist Light File Manager launch screen.
/// Surfaces 4 dedicated top-left mode symbols:
/// 1. File Manager (folder)
/// 2. Media Viewer & Player (player/gallery)
/// 3. Share & Transfer Hub (share/P2P)
/// 4. File Conversions & Studio (conversions/trimmer/checksums)
class FileManagerHomeScreen extends StatefulWidget {
  final void Function(int targetTabIndex)? onNavigate;
  final bool showBottomNav;

  const FileManagerHomeScreen({
    super.key,
    this.onNavigate,
    this.showBottomNav = true,
  });

  @override
  State<FileManagerHomeScreen> createState() => _FileManagerHomeScreenState();
}

class _FileManagerHomeScreenState extends State<FileManagerHomeScreen> {
  int _selectedMode = 0; // 0: Files, 1: Media, 2: Share, 3: Conversions
  StreamSubscription<CanaryTripEvent>? _canarySub;

  @override
  void initState() {
    super.initState();
    _canarySub = RansomwareCanaryGuard.instance.onTrip.listen((event) {
      if (mounted) RansomwareAlertModal.show(context, event);
    });
  }

  @override
  void dispose() {
    _canarySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 4 Symbol Mode Buttons
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton(0, Icons.folder_rounded, 'File Manager', 'appbar_mode_filemanager'),
                  _buildModeButton(1, Icons.smart_display_rounded, 'Media Viewer & Player', 'appbar_mode_media'),
                  _buildModeButton(2, Icons.share_rounded, 'Share & Link Hub', 'appbar_mode_share'),
                  _buildModeButton(3, Icons.transform_rounded, 'File Conversions & Studio', 'appbar_mode_conversions'),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'PeerLink',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            key: const Key('appbar_sync_spaces_button'),
            icon: const Icon(Icons.sync_rounded, size: 20, color: Color(0xFF334155)),
            tooltip: 'Folder Sync & Backup',
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onNavigate?.call(3);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF334155)),
            tooltip: 'Search & Query',
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onNavigate?.call(4);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            key: const Key('appbar_contextual_share_button'),
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF2563EB)),
            ),
            tooltip: 'Share & Receive',
            onPressed: () {
              HapticFeedback.selectionClick();
              ContextualShareSheet.show(context);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.settings_outlined, size: 20, color: Color(0xFF334155)),
            tooltip: 'Settings & Security',
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onNavigate?.call(5);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildSpaceContextHeader(),
          Expanded(child: _buildFlowContent()),
          if (_selectedMode == 0) ...[
            const StashTrayDock(),
            const FloatingAudioMiniPlayer(),
          ],
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      _buildBottomNavSpaceButton(0, Icons.folder_rounded, 'Files', 'bottom_mode_filemanager'),
                      _buildBottomNavSpaceButton(1, Icons.smart_display_rounded, 'Media', 'bottom_mode_media'),
                      _buildBottomNavSpaceButton(2, Icons.share_rounded, 'Share', 'bottom_mode_share'),
                      _buildBottomNavSpaceButton(3, Icons.transform_rounded, 'Studio', 'bottom_mode_conversions'),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBottomNavSpaceButton(int mode, IconData icon, String label, String keyName) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        key: Key(keyName),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMode = mode);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceContextHeader() {
    IconData icon;
    String title;
    String subtitle;
    Color accentColor;

    switch (_selectedMode) {
      case 1:
        icon = Icons.smart_display_rounded;
        title = 'Player Hub Space';
        subtitle = 'Universal Device Media Player, Video Theater & Lossless Jukebox';
        accentColor = const Color(0xFF10B981);
        break;
      case 2:
        icon = Icons.share_rounded;
        title = 'P2P Share & Link Space';
        subtitle = 'Decentralized Transfer Engine, WebBeam 2.0 & Wi-Fi Direct';
        accentColor = const Color(0xFF8B5CF6);
        break;
      case 3:
        icon = Icons.transform_rounded;
        title = 'Conversion Studio Space';
        subtitle = 'iLovePDF 23-Format Power Studio & Mobile Document Scanner';
        accentColor = const Color(0xFFD97706);
        break;
      case 0:
      default:
        icon = Icons.folder_copy_rounded;
        title = 'File Explorer Space';
        subtitle = 'Local System Storage & Cryptographic Secure Vault';
        accentColor = const Color(0xFF2563EB);
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(int index, IconData icon, String tooltip, String keyName) {
    final isSelected = _selectedMode == index;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: Key(keyName),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedMode = index);
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: isSelected ? Border.all(color: const Color(0xFFCBD5E1), width: 1) : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowContent() {
    switch (_selectedMode) {
      case 1:
        return const MediaHubFlowView();
      case 2:
        return const ShareHubFlowView();
      case 3:
        return const FileConverterFlowView();
      case 0:
      default:
        return const ReceivedVaultView();
    }
  }
}
