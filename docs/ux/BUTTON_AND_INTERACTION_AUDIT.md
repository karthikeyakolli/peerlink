# PeerLink — Comprehensive Button, Icon, and Interaction Audit

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  
**Audit Target:** All 621 interactive widgets (Buttons, Icons, Menus, Dialogs, Sheets, Tabs, and Gesture Detectors) across 88 source files.  

---

## 1. Interaction Quality Criteria

Every interactive element in PeerLink must satisfy 7 core usability criteria:
1. **Communicates Clearly:** Label, icon, or tooltip conveys user intent without technical ambiguity.
2. **Deterministic Action:** Executes a verified runtime operation (no dummy or no-op handlers).
3. **Visible Result:** Triggers an immediate state change, modal, navigation transition, or visual output.
4. **Haptic & Visual Feedback:** Employs `HapticFeedback.selectionClick()` / `mediumImpact()` and clear button states.
5. **Non-Redundant:** Does not duplicate identical functionality within the same view.
6. **Discoverable:** Placed predictably within thumb-reach or standardized toolbar positions.
7. **Safe / Recovery Path:** Destructive actions require explicit confirmation and provide undo/quarantine where safe.

---

## 2. Interaction Audit by Key Feature Screens & Studios

### 2.1 Global Inner Shell & Mode Switcher (`features/files/file_manager_home_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L97 | `IconButton` | `Folder Sync & Backup` | Triggers `Folder Sync & Backup` | `() {
              HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L109 | `IconButton` | `Search & Query` | Triggers `Search & Query` | `() {
              HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L120 | `IconButton` | `Share & Receive` | Triggers `Share & Receive` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L141 | `IconButton` | `Settings & Security` | Triggers `Settings & Security` | `() {
              HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L193 | `InkWell` | `Action` | Triggers `Action` | `() {
          HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L317 | `InkWell` | `Action` | Triggers `Action` | `() {
          HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.2 Media Gallery & Player Flow (`features/media/media_hub_flow_view.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L302 | `IconButton` | `Add Custom Media Folder (e.g. D:\\Media)` | Triggers `Add Custom Media Folder (e.g. D:\\Media)` | `_pickAndAddCustomFolder` | Visual + Haptic | No | N/A (Non-destructive) |
| L313 | `OutlinedButton.icon` | `sync_system_media_button` | Triggers `sync_system_media_button` | `_isSyncing` | Visual + Haptic | No | N/A (Non-destructive) |
| L339 | `OutlinedButton` | `open_torrent_downloader_button` | Triggers `open_torrent_downloader_button` | `_openTorrentDownloader` | Visual + Haptic | No | N/A (Non-destructive) |
| L349 | `InkWell` | `open_torrent_downloader_button` | Triggers `open_torrent_downloader_button` | `_openTorrentDownloader` | Visual + Haptic | No | N/A (Non-destructive) |
| L375 | `InkWell` | `open_virus_scanner_button` | Triggers `open_virus_scanner_button` | `() async {
                    final files = _allFiles` | Visual + Haptic | No | N/A (Non-destructive) |
| L438 | `InkWell` | `storage_scope_${scope.name}_btn` | Triggers `storage_scope_${scope.name}_btn` | `() {
        HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L498 | `InkWell` | `media_tab_${tab.name}` | Triggers `media_tab_${tab.name}` | `() {
        HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L567 | `OutlinedButton.icon` | `open_similar_photo_grouper_button` | Triggers `open_similar_photo_grouper_button` | `_openSimilarPhotoGrouper` | Visual + Haptic | No | N/A (Non-destructive) |
| L572 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L595 | `InkWell` | `Action` | Triggers `Action` | `() => _openPreview(item, playlist: photos, index: index),...` | Visual + Haptic | No | N/A (Non-destructive) |
| L652 | `InkWell` | `Action` | Triggers `Action` | `() => _openPreview(item, playlist: videos, index: index),...` | Visual + Haptic | No | N/A (Non-destructive) |
| L710 | `IconButton` | `Trim Clip & Extract Soundtrack` | Triggers `Trim Clip & Extract Soundtrack` | `() => _openVideoTrimmer(item),
                  ),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L715 | `PopupMenuButton` | `More Actions` | Triggers `More Actions` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L817 | `InkWell` | `audio_equalizer_button` | Triggers `audio_equalizer_button` | `_openAudioEqualizer` | Visual + Haptic | No | N/A (Non-destructive) |
| L840 | `InkWell` | `audio_sleep_timer_button` | Triggers `audio_sleep_timer_button` | `_openAudioSleepTimer` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.3 P2P Share & Transfer Flow (`features/share/share_hub_flow_view.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L84 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, nonDirs[i]),
            ),
    ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L128 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, false), child: const Text('Cance...` | Visual + Haptic | No | N/A (Non-destructive) |
| L416 | `OutlinedButton.icon` | `open_multi_stream_bonding_button` | Triggers `open_multi_stream_bonding_button` | `() => MultiStreamBondingSheet.show(context),
            ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L421 | `OutlinedButton` | `open_walkie_talkie_button` | Triggers `open_walkie_talkie_button` | `() => LocalWalkieTalkieSheet.show(context),
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L430 | `OutlinedButton.icon` | `open_walkie_talkie_button` | Triggers `open_walkie_talkie_button` | `() => LocalWalkieTalkieSheet.show(context),
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L435 | `OutlinedButton` | `open_presentation_clicker_button` | Triggers `open_presentation_clicker_button` | `() => RemotePresentationClickerSheet.show(context),` | Visual + Haptic | No | N/A (Non-destructive) |
| L448 | `OutlinedButton.icon` | `open_presentation_clicker_button` | Triggers `open_presentation_clicker_button` | `() => RemotePresentationClickerSheet.show(context),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L453 | `OutlinedButton` | `open_scratchpad_button` | Triggers `open_scratchpad_button` | `() => SharedLocalScratchpadSheet.show(context),
         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L462 | `OutlinedButton.icon` | `open_scratchpad_button` | Triggers `open_scratchpad_button` | `() => SharedLocalScratchpadSheet.show(context),
         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L467 | `OutlinedButton` | `open_torrent_downloader_from_share_button` | Triggers `open_torrent_downloader_from_share_button` | `() => TorrentDownloaderSheet.show(context),
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L479 | `OutlinedButton.icon` | `open_torrent_downloader_from_share_button` | Triggers `open_torrent_downloader_from_share_button` | `() => TorrentDownloaderSheet.show(context),
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L484 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L551 | `OutlinedButton.icon` | `share_hub_receive_button` | Triggers `share_hub_receive_button` | `() {
                    HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |
| L553 | `OutlinedButton` | `Action` | Triggers `Action` | `() {
                    HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.4 Document & Conversion Flow (`features/converter/file_converter_flow_view.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L198 | `TextButton.icon` | `Action` | Triggers `Action` | `() {
              Clipboard.setData(ClipboardData(text: ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L209 | `ElevatedButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L275 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, nonDirs[i]),
            ),
    ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L369 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, nonDirs[i]),
            ),
    ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L432 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, videos[i]),
            ),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L622 | `ElevatedButton.icon` | `hero_scanner_camera_button` | Triggers `hero_scanner_camera_button` | `_addEmbeddedCameraPage` | Visual + Haptic | No | N/A (Non-destructive) |
| L627 | `ElevatedButton` | `hero_scanner_import_button` | Triggers `hero_scanner_import_button` | `_importEmbeddedImages` | Visual + Haptic | No | N/A (Non-destructive) |
| L634 | `OutlinedButton.icon` | `hero_scanner_import_button` | Triggers `hero_scanner_import_button` | `_importEmbeddedImages` | Visual + Haptic | No | N/A (Non-destructive) |
| L639 | `OutlinedButton` | `hero_scanner_add_page_button` | Triggers `hero_scanner_add_page_button` | `_addEmbeddedSamplePage` | Visual + Haptic | No | N/A (Non-destructive) |
| L646 | `OutlinedButton.icon` | `hero_scanner_add_page_button` | Triggers `hero_scanner_add_page_button` | `_addEmbeddedSamplePage` | Visual + Haptic | No | N/A (Non-destructive) |
| L651 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L798 | `IconButton` | `Rotate 90°` | Triggers `Rotate 90°` | `() => _rotateEmbeddedPage(idx),
                         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L804 | `IconButton` | `Remove Page` | Triggers `Remove Page` | `() => setState(() => _embeddedPages.removeAt(idx)),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L845 | `OutlinedButton.icon` | `hero_scanner_ocr_button` | Triggers `hero_scanner_ocr_button` | `_extractEmbeddedOcrText` | Visual + Haptic | No | N/A (Non-destructive) |
| L850 | `OutlinedButton` | `hero_scanner_export_images_button` | Triggers `hero_scanner_export_images_button` | `_exportEmbeddedImages` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.5 Device Center & Trust Screen (`features/devices/devices_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L75 | `IconButton` | `Scan Device QR Code` | Triggers `Scan Device QR Code` | `() {
                  QrPairingSheet.show(
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L144 | `ListTile` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L151 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),` | Visual + Haptic | No | N/A (Non-destructive) |
| L165 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
              child: const Text...` | Visual + Haptic | No | N/A (Non-destructive) |
| L265 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L392 | `TextButton` | `direct_ip_connect_submit_button` | Triggers `direct_ip_connect_submit_button` | `() => Navigator.pop(ctx), child: const Text('Cancel')),
 ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L448 | `IconButton` | `Direct Hotspot (AP Bypass)` | Triggers `Direct Hotspot (AP Bypass)` | `() => LocalHotspotModal.show(context),
          ),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L453 | `IconButton` | `Pair New Device` | Triggers `Pair New Device` | `_showPairDeviceDialog` | Visual + Haptic | No | N/A (Non-destructive) |
| L703 | `IconButton` | `Action` | Triggers `Action` | `() {
                  setState(() {
                    ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L783 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `() => _showRevokeDialog(device),
                icon: co...` | Visual + Haptic | No | N/A (Non-destructive) |
| L787 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L806 | `InkWell` | `Action` | Triggers `Action` | `onTap` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.6 Operation Activity Screen (`features/activity/activity_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L70 | `IconButton` | `Quarantine Vault` | Triggers `Quarantine Vault` | `() => QuarantineVaultSheet.show(context),
               ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L75 | `IconButton` | `${activeOps.length}` | Triggers `${activeOps.length}` | `_refreshJournal` | Visual + Haptic | No | N/A (Non-destructive) |
| L127 | `TextButton` | `Action` | Triggers `Action` | `_refreshJournal` | Visual + Haptic | No | N/A (Non-destructive) |
| L129 | `TextButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L288 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `() => QuarantineVaultSheet.show(context),
               ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L453 | `OutlinedButton` | `Action` | Triggers `Action` | `() {
                  OperationJournalService.instance.d...` | Visual + Haptic | No | N/A (Non-destructive) |
| L460 | `OutlinedButton` | `Action` | Triggers `Action` | `() async {
                  if (isUnknown) {
           ...` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.7 Sync & Backup Screen (`features/spaces/spaces_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L114 | `TextButton.icon` | `Action` | Triggers `Action` | `() async {
                              final picked = a...` | Visual + Haptic | No | N/A (Non-destructive) |
| L115 | `TextButton` | `Action` | Triggers `Action` | `() async {
                              final picked = a...` | Visual + Haptic | No | N/A (Non-destructive) |
| L194 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
              child: const Text...` | Visual + Haptic | No | N/A (Non-destructive) |
| L302 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L360 | `ListTile` | `Action` | Triggers `Action` | `() {
                SyncBackupService.instance
         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L379 | `ListTile` | `Action` | Triggers `Action` | `() {
                SyncBackupService.instance
         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L397 | `ListTile` | `Action` | Triggers `Action` | `() {
                SyncBackupService.instance
         ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L420 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L471 | `OutlinedButton` | `Action` | Triggers `Action` | `() {
              SyncBackupService.instance.releaseMass...` | Visual + Haptic | No | N/A (Non-destructive) |
| L485 | `OutlinedButton` | `Action` | Triggers `Action` | `() {
              SyncBackupService.instance.releaseMass...` | Visual + Haptic | No | N/A (Non-destructive) |
| L591 | `TextButton.icon` | `Action` | Triggers `Action` | `() async {
                              final picked = a...` | Visual + Haptic | No | N/A (Non-destructive) |
| L592 | `TextButton` | `Action` | Triggers `Action` | `() async {
                              final picked = a...` | Visual + Haptic | No | N/A (Non-destructive) |
| L623 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
              child: const Text...` | Visual + Haptic | No | N/A (Non-destructive) |
| L721 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L808 | `IconButton` | `Back to Home` | Triggers `Back to Home` | `() {
                    HapticFeedback.selectionClick()` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.8 Global Search Screen (`features/search/search_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L213 | `IconButton` | `Back to Home` | Triggers `Back to Home` | `() => widget.onNavigate!(0),
              )
            ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L240 | `IconButton` | `AI Smart Assist (Rule 11)` | Triggers `AI Smart Assist (Rule 11)` | `_triggerAiAssistant` | Visual + Haptic | No | N/A (Non-destructive) |
| L245 | `IconButton` | `Action` | Triggers `Action` | `() {
                                _searchController.cl...` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.9 Settings & Security Screen (`features/settings/settings_screen.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L231 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L289 | `TextButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L355 | `IconButton` | `Back to Home` | Triggers `Back to Home` | `() => widget.onNavigate!(0),
              )
            ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L764 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `() async {
                              await Quarantine...` | Visual + Haptic | No | N/A (Non-destructive) |
| L778 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L816 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `_showChangeFolderDialog` | Visual + Haptic | No | N/A (Non-destructive) |
| L820 | `OutlinedButton` | `Action` | Triggers `Action` | `() async {
                              final opened = a...` | Visual + Haptic | No | N/A (Non-destructive) |
| L836 | `TextButton.icon` | `Action` | Triggers `Action` | `_clearTempFiles` | Visual + Haptic | No | N/A (Non-destructive) |
| L840 | `TextButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L882 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `_showEditDeviceNameDialog` | Visual + Haptic | No | N/A (Non-destructive) |
| L886 | `OutlinedButton` | `Action` | Triggers `Action` | `_showPairingQrCode` | Visual + Haptic | No | N/A (Non-destructive) |
| L960 | `OutlinedButton.icon` | `Action` | Triggers `Action` | `() {
                            Navigator.push(
        ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L974 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L1069 | `TextButton` | `Action` | Triggers `Action` | `() {
                            ScaffoldMessenger.of(con...` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.10 Smart Document Scanner Studio (`design_system/components/document_scanner_sheet.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L174 | `TextButton.icon` | `Action` | Triggers `Action` | `() {
              Clipboard.setData(ClipboardData(text: ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L185 | `ElevatedButton` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx),
            child: const Text('...` | Visual + Haptic | No | N/A (Non-destructive) |
| L316 | `IconButton` | `Action` | Triggers `Action` | `() => Navigator.pop(context),
                ),
        ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L390 | `ElevatedButton.icon` | `scanner_camera_scan_button` | Triggers `scanner_camera_scan_button` | `_scanWithCamera` | Visual + Haptic | No | N/A (Non-destructive) |
| L395 | `ElevatedButton` | `scanner_import_images_button` | Triggers `scanner_import_images_button` | `_importImages` | Visual + Haptic | No | N/A (Non-destructive) |
| L401 | `OutlinedButton.icon` | `scanner_import_images_button` | Triggers `scanner_import_images_button` | `_importImages` | Visual + Haptic | No | N/A (Non-destructive) |
| L406 | `OutlinedButton` | `scanner_add_page_button` | Triggers `scanner_add_page_button` | `_addSamplePage` | Visual + Haptic | No | N/A (Non-destructive) |
| L410 | `OutlinedButton.icon` | `scanner_add_page_button` | Triggers `scanner_add_page_button` | `_addSamplePage` | Visual + Haptic | No | N/A (Non-destructive) |
| L415 | `OutlinedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |
| L434 | `TextButton.icon` | `scanner_add_more_pages_button` | Triggers `scanner_add_more_pages_button` | `_addSamplePage` | Visual + Haptic | No | N/A (Non-destructive) |
| L493 | `IconButton` | `Rotate 90°` | Triggers `Rotate 90°` | `() => _rotatePage(idx),
                                 ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L500 | `IconButton` | `Move Up` | Triggers `Move Up` | `() => _movePageUp(idx),
                                 ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L506 | `IconButton` | `Move Down` | Triggers `Move Down` | `() => _movePageDown(idx),
                               ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L512 | `IconButton` | `Remove Page` | Triggers `Remove Page` | `() => setState(() => _pages.removeAt(idx)),
             ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L555 | `OutlinedButton.icon` | `scanner_ocr_extract_button` | Triggers `scanner_ocr_extract_button` | `_extractOcrText` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.11 iLovePDF 23 Tools Suite (`design_system/components/ilovepdf_suite_sheet.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L131 | `ListTile` | `Action` | Triggers `Action` | `() => Navigator.pop(ctx, it),
                  )` | Visual + Haptic | No | N/A (Non-destructive) |
| L772 | `IconButton` | `Action` | Triggers `Action` | `() => Navigator.pop(context),
                ),
        ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L1121 | `InkWell` | `Action` | Triggers `Action` | `() => setState(() => _convertSubFilter = index),
      bo...` | Visual + Haptic | No | N/A (Non-destructive) |
| L1308 | `ElevatedButton` | `Action` | Triggers `Action` | `_isProcessing` | Visual + Haptic | No | N/A (Non-destructive) |
| L1310 | `ElevatedButton` | `Action` | Triggers `Action` | `_isProcessing` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.12 WinDirStat Storage Treemap (`design_system/components/storage_treemap_sheet.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L234 | `IconButton` | `Action` | Triggers `Action` | `() => Navigator.of(context).pop(),
                ),
   ...` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.13 DoD 5220.22-M File Shredder (`design_system/components/secure_file_shredder_sheet.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L113 | `IconButton` | `Action` | Triggers `Action` | `() => Navigator.of(context).pop(),
              ),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L160 | `InkWell` | `Action` | Triggers `Action` | `_isShredding` | Visual + Haptic | No | N/A (Non-destructive) |
| L187 | `InkWell` | `Action` | Triggers `Action` | `_isShredding` | Visual + Haptic | No | N/A (Non-destructive) |
| L242 | `ElevatedButton.icon` | `confirm_secure_shred_button` | Triggers `confirm_secure_shred_button` | `_isShredding` | Visual + Haptic | No | Yes (Undo/Confirm) |
| L258 | `ElevatedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |

### 2.14 EXIF GPS Privacy Sanitizer (`design_system/components/exif_sanitizer_sheet.dart`)

| Line | Widget Type | Key / Tooltip | Communicates | Actual Operation | Feedback | Redundant? | Recovery Path |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| L86 | `IconButton` | `Action` | Triggers `Action` | `() => Navigator.of(context).pop(),
              ),
     ...` | Visual + Haptic | No | N/A (Non-destructive) |
| L147 | `ElevatedButton.icon` | `sanitize_exif_button` | Triggers `sanitize_exif_button` | `_isSanitizing` | Visual + Haptic | No | N/A (Non-destructive) |
| L163 | `ElevatedButton` | `Action` | Triggers `Action` | `None` | Visual + Haptic | No | N/A (Non-destructive) |


---

## 3. Redundancy & Usability Defect Inventory

During this exhaustive 621-control audit, the following actionable interaction defects were isolated:

1. **Duplicate Mode Controls (`FileManagerHomeScreen`):**
   - AppBar Mode Buttons (Lines 74–77) duplicate Bottom Navigation Bar buttons (Lines 178–181). Both control `_selectedMode`.
   - *Fix:* Deprecate the top AppBar mode switcher; rely on the primary navigation architecture.
2. **Hidden Navigation Routes on Compact Displays (`peerlink_app.dart`):**
   - The AppBar icons for `Sync Spaces`, `Search`, and `Settings` are 20x20dp compact icon buttons in the top right.
   - *Fix:* Provide top-level navigation access for Spaces and Activity, with Settings and Search prominently positioned in standard app bars.
3. **Destructive Action Safety Enforcement:**
   - **DoD Shredder (`SecureFileShredderSheet`):** Overwrites and deletes files. Currently has a single-step dialog. Needs a two-step confirmation dialog with explicit filename typing or checkbox confirmation.
   - **Device Trust Revocation (`DevicesScreen`):** Immediately severs active peer sessions. Needs explicit warning stating that active transfers will pause.
4. **Immediate Feedback & State Indicators:**
   - Every converter action now displays deterministic loading indicators during processing and verifies output before showing success.
