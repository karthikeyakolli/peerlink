import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/received_files_service.dart';
import '../../core/file_staging_service.dart';
import '../../core/safe_folder_service.dart';
import '../../core/web_beam_server_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../design_system/colors/peerlink_colors.dart';
import '../../design_system/components/media_preview_modal.dart';
import '../../design_system/components/deep_clean_sheet.dart';
import '../../design_system/components/web_beam_modal.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../design_system/components/safe_folder_sheet.dart';
import '../../design_system/components/auto_sort_rules_sheet.dart';
import '../../design_system/components/batch_rename_dialog.dart';
import '../../design_system/components/storage_cleaner_sheet.dart';
import '../../design_system/components/batch_renamer_modal.dart';
import '../../design_system/components/file_hash_diff_sheet.dart';
import '../../design_system/components/remote_stream_browser_sheet.dart';
import '../../design_system/components/universal_clipboard_sheet.dart';
import '../../design_system/components/content_search_sheet.dart';
import '../../design_system/components/document_scanner_sheet.dart';
import '../../design_system/components/smart_photo_cleaner_sheet.dart';
import '../../design_system/components/file_converter_sheet.dart';
import '../../core/ephemeral_burner_share_service.dart';
import '../../core/hotspot_tether_qr_service.dart';
import '../../core/network_diagnostic_service.dart';
import '../../design_system/components/burner_viewer_modal.dart';
import '../../design_system/components/hotspot_tether_qr_sheet.dart';
import '../../design_system/components/network_diagnostic_card.dart';

class _FolderTabState {
  bool browseInternalStorage;
  String subPath;
  ReceivedFileCategory? selectedCategory;
  bool downloadsOnly;

  _FolderTabState({
    required this.browseInternalStorage,
    this.subPath = '',
    this.selectedCategory,
    this.downloadsOnly = false,
  });

  String get displayLabel {
    if (subPath.isNotEmpty) {
      final segs = subPath.split('/').where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) return segs.last;
    }
    if (downloadsOnly) return 'Downloads';
    if (selectedCategory != null) {
      final n = selectedCategory!.name;
      return '${n[0].toUpperCase()}${n.substring(1)}';
    }
    return browseInternalStorage ? 'Device' : 'Vault';
  }
}

enum VaultSortMode {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  sizeDesc,
  sizeAsc,
  type,
}

/// Xiaomi HyperOS Minimalist Light-Only File Manager & Integrated P2P Vault.
/// Features dual storage scopes (PeerLink Vault & Device Internal Storage),
/// top global search & file actions, crisp 4x2 category grid, understated
/// integrated P2P sharing strip (Send, Receive, Web Share, Hotspot),
/// Recent Files strip, folder breadcrumbs, Cut/Copy/Paste engine, ZIP
/// compression/extraction, batch multi-select, and full OS file actions.
class ReceivedVaultView extends StatefulWidget {
  final VoidCallback? onOpenShareTab;

  const ReceivedVaultView({super.key, this.onOpenShareTab});

  @override
  State<ReceivedVaultView> createState() => _ReceivedVaultViewState();
}

class _ReceivedVaultViewState extends State<ReceivedVaultView> {
  final ReceivedFilesService _service = ReceivedFilesService.instance;
  final TextEditingController _searchController = TextEditingController();

  // Storage Scope: PeerLink Vault vs Device Internal Storage (Google Files style)
  bool _browseInternalStorage = false;
  Map<String, int>? _deviceStorageInfo;
  bool _hasAllFilesAccess = true;

  ReceivedFileCategory? _selectedCategory;
  bool _downloadsOnly = false;
  VaultSortMode _sortMode = VaultSortMode.dateDesc;
  bool _isGridView = false;
  bool _showHiddenFiles = false;
  List<ReceivedFileItem> _files = [];
  int _gridDisplayLimit = 60;
  StorageBreakdown? _storageBreakdown;
  bool _isLoading = true;

  // Folder Drill-Down Hierarchy state
  String _currentSubPath = '';

  // Multi-Tab / Split-Folder Explorer state (up to 4 independent folder tabs)
  final List<_FolderTabState> _folderTabs = [
    _FolderTabState(browseInternalStorage: false),
  ];
  int _activeTabIndex = 0;

  void _syncActiveTabSnapshot() {
    if (_activeTabIndex >= 0 && _activeTabIndex < _folderTabs.length) {
      final tab = _folderTabs[_activeTabIndex];
      tab.browseInternalStorage = _browseInternalStorage;
      tab.subPath = _currentSubPath;
      tab.selectedCategory = _selectedCategory;
      tab.downloadsOnly = _downloadsOnly;
    }
  }

  void _switchFolderTab(int index) {
    if (index < 0 || index >= _folderTabs.length || index == _activeTabIndex) return;
    _syncActiveTabSnapshot();
    final target = _folderTabs[index];
    setState(() {
      _activeTabIndex = index;
      _browseInternalStorage = target.browseInternalStorage;
      _currentSubPath = target.subPath;
      _selectedCategory = target.selectedCategory;
      _downloadsOnly = target.downloadsOnly;
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    _loadData();
  }

  void _addFolderTab({bool? internalStorage}) {
    if (_folderTabs.length >= 4) return;
    _syncActiveTabSnapshot();
    final nextInternal = internalStorage ?? !_browseInternalStorage;
    setState(() {
      _folderTabs.add(_FolderTabState(browseInternalStorage: nextInternal));
      _activeTabIndex = _folderTabs.length - 1;
      _browseInternalStorage = nextInternal;
      _currentSubPath = '';
      _selectedCategory = null;
      _downloadsOnly = false;
    });
    _loadData();
  }

  void _closeFolderTab(int index) {
    if (_folderTabs.length <= 1) return;
    setState(() {
      _folderTabs.removeAt(index);
      if (_activeTabIndex >= _folderTabs.length) {
        _activeTabIndex = _folderTabs.length - 1;
      }
      final active = _folderTabs[_activeTabIndex];
      _browseInternalStorage = active.browseInternalStorage;
      _currentSubPath = active.subPath;
      _selectedCategory = active.selectedCategory;
      _downloadsOnly = active.downloadsOnly;
    });
    _loadData();
  }

  String _resolveTabDirectoryPath(_FolderTabState tab) {
    Directory baseDir;
    if (tab.browseInternalStorage) {
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0');
      } else {
        final home = Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'] ??
            Directory.current.path;
        baseDir = Directory(home);
      }
    } else {
      baseDir = _service.saveDirectory;
    }
    if (tab.subPath.isNotEmpty) {
      return '${baseDir.path}${Platform.pathSeparator}${tab.subPath.replaceAll('/', Platform.pathSeparator)}';
    }
    return baseDir.path;
  }

  Future<void> _moveSelectedToOtherTab() async {
    if (_folderTabs.length < 2 || _selectedPaths.isEmpty) return;
    _syncActiveTabSnapshot();
    final otherIdx = (_activeTabIndex + 1) % _folderTabs.length;
    final destDir = _resolveTabDirectoryPath(_folderTabs[otherIdx]);
    final paths = _selectedPaths.toList();
    for (final p in paths) {
      await _service.moveEntity(p, destDir);
    }
    if (!mounted) return;
    setState(() {
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved ${paths.length} item(s) to tab "${_folderTabs[otherIdx].displayLabel}"'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Batch Multi-Select state
  bool _isMultiSelect = false;
  final Set<String> _selectedPaths = <String>{};

  // Clipboard for Cut/Copy/Paste operations
  List<String> _clipboardPaths = [];
  bool _isCutOperation = false;

  // Live auto-refresh subscriptions so inbound P2P & Web Beam transfers appear immediately
  StreamSubscription<void>? _filesChangeSub;
  StreamSubscription<Map<dynamic, dynamic>>? _bridgeEventSub;
  StreamSubscription<WebBeamSessionState>? _webBeamSub;
  int _lastWebBeamUploadCount = 0;

  String get _currentDirectoryPath {
    Directory baseDir;
    if (_browseInternalStorage) {
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0');
      } else {
        final home = Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'] ??
            Directory.current.path;
        baseDir = Directory(home);
      }
    } else {
      baseDir = _service.saveDirectory;
    }

    if (_currentSubPath.isNotEmpty) {
      return '${baseDir.path}${Platform.pathSeparator}${_currentSubPath.replaceAll('/', Platform.pathSeparator)}';
    }
    return baseDir.path;
  }

  @override
  void initState() {
    super.initState();
    _lastWebBeamUploadCount = WebBeamServerService.instance.currentState.uploadCount;
    _loadData();
    _filesChangeSub = _service.changeStream.listen((_) {
      if (mounted) _loadData();
    });
    _bridgeEventSub = AndroidNodeBridge.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString() ?? '';
      final state = event['state']?.toString() ?? '';
      if (type == 'transferCompleted' ||
          (type == 'transferProgress' && state.toUpperCase() == 'COMPLETED')) {
        _loadData();
      }
    });
    _webBeamSub = WebBeamServerService.instance.stateStream.listen((state) {
      if (!mounted) return;
      if (state.uploadCount != _lastWebBeamUploadCount) {
        _lastWebBeamUploadCount = state.uploadCount;
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _filesChangeSub?.cancel();
    _bridgeEventSub?.cancel();
    _webBeamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _gridDisplayLimit = 60;
    });

    if (Platform.isAndroid) {
      if (_deviceStorageInfo == null) {
        try {
          _deviceStorageInfo = await AndroidNodeBridge.instance.getStorageSpaceInfo();
        } catch (_) {}
      }
      if (_browseInternalStorage) {
        try {
          _hasAllFilesAccess = await AndroidNodeBridge.instance.hasAllFilesAccess();
        } catch (_) {}
      }
    }

    Directory? baseDir;
    if (_browseInternalStorage) {
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0');
      } else {
        final home = Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'] ??
            Directory.current.path;
        baseDir = Directory(home);
      }
    }

    final files = await _service.getReceivedFiles(
      searchFilter: _searchController.text,
      categoryFilter: _downloadsOnly ? null : _selectedCategory,
      subDirectoryRelativePath: _currentSubPath.isNotEmpty ? _currentSubPath : null,
      baseDirectory: baseDir,
      showHidden: _showHiddenFiles,
      downloadsOnly: _downloadsOnly,
    );

    // Apply sorting (folders stay on top)
    switch (_sortMode) {
      case VaultSortMode.dateDesc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return b.lastModified.compareTo(a.lastModified);
        });
        break;
      case VaultSortMode.dateAsc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.lastModified.compareTo(b.lastModified);
        });
        break;
      case VaultSortMode.nameAsc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case VaultSortMode.nameDesc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        });
        break;
      case VaultSortMode.sizeDesc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return b.sizeBytes.compareTo(a.sizeBytes);
        });
        break;
      case VaultSortMode.sizeAsc:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.sizeBytes.compareTo(b.sizeBytes);
        });
        break;
      case VaultSortMode.type:
        files.sort((a, b) {
          if (a.isDirectory && !b.isDirectory) return -1;
          if (!a.isDirectory && b.isDirectory) return 1;
          return a.extension.toLowerCase().compareTo(b.extension.toLowerCase());
        });
        break;
    }

    final breakdown = await _service.getStorageBreakdown();
    if (mounted) {
      setState(() {
        _files = files;
        _storageBreakdown = breakdown;
        _isLoading = false;
        // Clean up any selected paths that no longer exist
        final existingPaths = files.map((f) => f.path).toSet();
        _selectedPaths.removeWhere((p) => !existingPaths.contains(p));
        if (_selectedPaths.isEmpty && _isMultiSelect) {
          _isMultiSelect = false;
        }
      });
    }
  }

  void _navigateToSubfolder(String folderName) {
    setState(() {
      if (_currentSubPath.isEmpty) {
        _currentSubPath = folderName;
      } else {
        _currentSubPath = '$_currentSubPath/$folderName';
      }
      _selectedPaths.clear();
      _isMultiSelect = false;
    });
    _loadData();
  }

  void _navigateToBreadcrumbIndex(int index) {
    if (index < 0) {
      setState(() {
        _currentSubPath = '';
        _selectedPaths.clear();
        _isMultiSelect = false;
      });
    } else {
      final segments = _currentSubPath.split('/').where((s) => s.isNotEmpty).toList();
      if (index < segments.length) {
        setState(() {
          _currentSubPath = segments.sublist(0, index + 1).join('/');
          _selectedPaths.clear();
          _isMultiSelect = false;
        });
      }
    }
    _loadData();
  }

  void _navigateUp() {
    if (_currentSubPath.isEmpty) return;
    final segments = _currentSubPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 1) {
      _navigateToBreadcrumbIndex(-1);
    } else {
      _navigateToBreadcrumbIndex(segments.length - 2);
    }
  }

  void _stageDirectoryFiles(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final subFiles = dir.listSync(recursive: true).whereType<File>().map((f) => f.path).toList();
        if (subFiles.isNotEmpty) {
          FileStagingService.instance.addPaths(subFiles);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staged ${subFiles.length} file(s) from folder to beam!'),
              backgroundColor: const Color(0xFF2563EB),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isMultiSelect = false;
        }
      } else {
        _selectedPaths.add(path);
        _isMultiSelect = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPaths.length == _files.length) {
        _selectedPaths.clear();
        _isMultiSelect = false;
      } else {
        _selectedPaths.clear();
        _selectedPaths.addAll(_files.map((f) => f.path));
        _isMultiSelect = true;
      }
    });
  }

  void _batchBeamSelected() {
    if (_selectedPaths.isEmpty) return;
    final allPaths = <String>[];
    for (final p in _selectedPaths) {
      if (Directory(p).existsSync()) {
        try {
          final files = Directory(p).listSync(recursive: true).whereType<File>().map((f) => f.path);
          allPaths.addAll(files);
        } catch (_) {}
      } else {
        allPaths.add(p);
      }
    }
    FileStagingService.instance.addPaths(allPaths);
    setState(() {
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    if (mounted) {
      ContextualShareSheet.show(context, initialPaths: allPaths);
    }
  }

  Future<void> _batchDeleteSelected() async {
    if (_selectedPaths.isEmpty) return;
    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count File(s)?'),
        content: Text('Are you sure you want to permanently delete $count selected file(s) from your device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PeerLinkColors.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final path in _selectedPaths) {
        await _service.deleteFile(path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count file(s).'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isMultiSelect = false;
          _selectedPaths.clear();
        });
        _loadData();
      }
    }
  }

  // --------------------------------------------------------------------------
  // Real Android File Manager: Folder Creation, Cut/Copy/Paste & ZIP Utilities
  // --------------------------------------------------------------------------

  /// Creates a new folder in the active directory
  Future<void> _showCreateFolderDialog() async {
    final folderController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('New Folder'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('create_folder_input'),
            controller: folderController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g. Documents, Projects, Photos',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a folder name';
              }
              if (RegExp(r'[\\/:*?"<>|]').hasMatch(value)) {
                return 'Name cannot contain \\ / : * ? " < > |';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('create_folder_confirm'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      final folderName = folderController.text.trim();
      final success = await _service.createFolder(_currentDirectoryPath, folderName);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "$folderName" created!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create folder "$folderName"'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Stashes file or folder paths in clipboard for Copy or Move (Cut) operation
  void _startCopyOrMove(List<String> paths, {required bool isCut}) {
    if (paths.isEmpty) return;
    setState(() {
      _clipboardPaths = List.from(paths);
      _isCutOperation = isCut;
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
    final verb = isCut ? 'move' : 'copy';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${paths.length} item(s) to $verb. Navigate to target folder and tap "Paste Here".'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Pastes clipboard files into the current active directory
  Future<void> _executePaste() async {
    if (_clipboardPaths.isEmpty) return;
    final targetDir = _currentDirectoryPath;
    int successCount = 0;

    for (final sourcePath in _clipboardPaths) {
      final success = _isCutOperation
          ? await _service.moveEntity(sourcePath, targetDir)
          : await _service.copyEntity(sourcePath, targetDir);
      if (success) successCount++;
    }

    final verb = _isCutOperation ? 'Moved' : 'Copied';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$verb $successCount item(s) to ${_currentSubPath.isEmpty ? "Vault root" : _currentSubPath}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _clipboardPaths.clear();
        _isCutOperation = false;
      });
      _loadData();
    }
  }

  /// Cancels active cut/copy operation
  void _cancelPaste() {
    setState(() {
      _clipboardPaths.clear();
      _isCutOperation = false;
    });
  }

  /// Prompts for ZIP name and compresses selected files into a ZIP archive
  Future<void> _showCompressDialog(List<String> paths) async {
    if (paths.isEmpty) return;
    final firstBaseName = File(paths.first).uri.pathSegments.where((s) => s.isNotEmpty).last;
    final defaultName = paths.length == 1
        ? '${firstBaseName.replaceAll(RegExp(r'\.[^.]+$'), '')}.zip'
        : 'archive_${DateTime.now().millisecondsSinceEpoch}.zip';

    final nameController = TextEditingController(text: defaultName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Compress to ZIP'),
          ],
        ),
        content: TextField(
          key: const Key('compress_zip_name_input'),
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ZIP Archive Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('compress_zip_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Compress'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var zipName = nameController.text.trim();
      if (!zipName.toLowerCase().endsWith('.zip')) {
        zipName = '$zipName.zip';
      }
      final outPath = '$_currentDirectoryPath${Platform.pathSeparator}$zipName';
      final res = await _service.compressToZip(paths, outPath);
      if (mounted) {
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created archive "$zipName"!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create archive.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Prompts user and extracts archive into current folder
  Future<void> _showExtractDialog(ReceivedFileItem file) async {
    final folderName = file.name.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
    final targetDir = '$_currentDirectoryPath${Platform.pathSeparator}$folderName';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.unarchive_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Extract Archive'),
          ],
        ),
        content: Text('Extract contents of "${file.name}" into folder "$folderName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('extract_zip_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Extract'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _service.extractArchive(file.path, targetDir);
      if (mounted) {
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Extracted into "$folderName"!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to extract archive.'),
              backgroundColor: Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Floating Action Pill displayed when files are stashed in clipboard to Paste
  Widget _buildPasteFloatingBar(ThemeData theme, bool isDark) {
    final verb = _isCutOperation ? 'Moving' : 'Copying';
    final count = _clipboardPaths.length;
    return Container(
      key: const Key('vault_paste_floating_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isCutOperation ? Icons.drive_file_move_rounded : Icons.copy_all_rounded,
            color: const Color(0xFF2563EB),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$verb $count item(s)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const Key('vault_paste_here_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.content_paste_rounded, size: 16),
            label: const Text('Paste Here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _executePaste,
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('vault_paste_cancel_button'),
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            onPressed: _cancelPaste,
          ),
        ],
      ),
    );
  }

  Widget _buildSha256Property(String filePath, bool isDark) {
    return FutureBuilder<String>(
      future: _service.calculateSha256(filePath),
      builder: (context, snapshot) {
        final hash = snapshot.data;
        final displayText = (hash != null && hash.isNotEmpty)
            ? hash
            : (snapshot.connectionState == ConnectionState.waiting ? 'Computing SHA-256...' : 'N/A');
        return _buildDetailProperty(
          'SHA-256',
          displayText,
          isDark,
          canCopy: hash != null && hash.isNotEmpty,
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Main Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const isDark = false; // Light mode forced unconditionally
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final animDuration = disableAnimations ? Duration.zero : const Duration(milliseconds: 200);
    final floatingBarKey = _clipboardPaths.isNotEmpty
        ? 'paste_${_clipboardPaths.length}_$_isCutOperation'
        : (_isMultiSelect && _selectedPaths.isNotEmpty ? 'batch_${_selectedPaths.length}' : 'none');

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            top: 8,
            bottom: (_clipboardPaths.isNotEmpty || (_isMultiSelect && _selectedPaths.isNotEmpty)) ? 92 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Multi-Tab Folder Strip (when 2+ tabs are open)
              if (_folderTabs.length > 1) _buildFolderTabsBar(),

              // 1. Xiaomi-style Top Search Bar & Quick File Toolbar
              _buildSearchAndFilterControls(theme, isDark),

              // 2. Interactive Breadcrumbs Bar (when drilled down into subfolders)
              AnimatedSize(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                child: _currentSubPath.isNotEmpty
                    ? _buildBreadcrumbs(theme, isDark)
                    : const SizedBox.shrink(),
              ),

              // 3. Minimalist Storage Scope Switcher & Compact Usage Bar
              if (_currentSubPath.isEmpty && _storageBreakdown != null)
                _buildXiaomiStorageHero(theme, isDark, _storageBreakdown!),

              // 3b. Android 11+ All Files Access Prompt when browsing Device Storage
              if (_browseInternalStorage && Platform.isAndroid && !_hasAllFilesAccess)
                _buildAllFilesAccessBanner(),

              // 4. Minimalist 4x2 Category Grid
              if (_currentSubPath.isEmpty)
                _buildXiaomiCategoryGrid(theme, isDark),

              // 5. Recent Files Horizontal Carousel
              if (_currentSubPath.isEmpty)
                _buildRecentFilesStrip(theme, isDark),

              // 6. Section Header for Files & Folders
              if (_currentSubPath.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _browseInternalStorage ? 'Folders & Files' : 'Files',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${_files.length} items',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

              // 7. Smoothly Animated File List / Grid
              AnimatedSwitcher(
                duration: animDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(
                    '${_browseInternalStorage}_${_currentSubPath}_${_selectedCategory}_${_isGridView}_$_isLoading',
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                        )
                      : _files.isEmpty
                          ? _buildEmptyState(theme)
                          : _isGridView
                              ? _buildFilesGrid(theme, isDark)
                              : _buildFilesList(theme, isDark),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),

        // Contextual Animated Floating Bars (Paste Bar / Multi-Select Batch Bar)
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: AnimatedSwitcher(
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              if (disableAnimations) return child;
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(floatingBarKey),
              child: _clipboardPaths.isNotEmpty
                  ? Center(child: _buildPasteFloatingBar(theme, isDark))
                  : (_isMultiSelect && _selectedPaths.isNotEmpty)
                      ? _buildBatchActionPill(theme, isDark)
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderTabsBar() {
    _syncActiveTabSnapshot();
    return Container(
      key: const Key('folder_tabs_bar'),
      height: 38,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < _folderTabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                key: Key('folder_tab_$i'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _switchFolderTab(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == _activeTabIndex ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == _activeTabIndex ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _folderTabs[i].browseInternalStorage
                            ? Icons.smartphone_outlined
                            : Icons.folder_outlined,
                        size: 14,
                        color: i == _activeTabIndex ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _folderTabs[i].displayLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == _activeTabIndex ? FontWeight.w700 : FontWeight.w500,
                          color: i == _activeTabIndex ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                        ),
                      ),
                      if (_folderTabs.length > 1) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _closeFolderTab(i),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_folderTabs.length < 4)
            IconButton(
              key: const Key('add_folder_tab_button'),
              tooltip: 'New Folder Tab',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
              onPressed: () => _addFolderTab(),
            ),
        ],
      ),
    );
  }

  Widget _buildAllFilesAccessBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Allow All Files Access to browse, copy, move, and manage Device Storage folders.',
              style: TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () async {
              await AndroidNodeBridge.instance.requestAllFilesAccess();
              await Future.delayed(const Duration(milliseconds: 400));
              if (mounted) _loadData();
            },
            child: const Text('Allow', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Recent Files & Transfers Horizontal Carousel (Google Files Hallmark)
  Widget _buildRecentFilesStrip(ThemeData theme, bool isDark) {
    final recentFiles = _files.where((f) => !f.isDirectory).take(8).toList();
    if (recentFiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF475569)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Recent Files',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${recentFiles.length} items',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: (MediaQuery.textScalerOf(context).scale(34) + 86).clamp(120.0, 170.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recentFiles.length,
              itemBuilder: (context, index) {
                final file = recentFiles[index];
                final catColor = _getCategoryColor(file.category);

                return Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131A29) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openFilePreview(file),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildFileThumbnail(
                                  file,
                                  size: 34,
                                  radius: 10,
                                  fallbackColor: catColor,
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onSelected: (action) => _handleFileAction(action, file),
                                  itemBuilder: (ctx) => _buildMenuItems(file),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${file.formattedSize} • ${_formatRelativeTime(file.lastModified)}',
                            style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.black45),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  /// Interactive Swiss-style Breadcrumbs Navigation Bar for nested subdirectories
  Widget _buildBreadcrumbs(ThemeData theme, bool isDark) {
    final segments = _currentSubPath.split('/').where((s) => s.isNotEmpty).toList();
    final rootLabel = _browseInternalStorage ? 'Device Storage' : 'Vault';
    final rootIcon = _browseInternalStorage ? Icons.phone_android_rounded : Icons.inventory_2_outlined;

    return Container(
      key: const Key('vault_breadcrumbs_bar'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A29) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              key: const Key('vault_back_up_button'),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              tooltip: 'Up one folder',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _navigateUp,
            ),
            const SizedBox(width: 4),
            InkWell(
              key: const Key('breadcrumb_root'),
              onTap: () => _navigateToBreadcrumbIndex(-1),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(rootIcon, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      rootLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: segments.isEmpty ? FontWeight.bold : FontWeight.w500,
                        color: segments.isEmpty ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < segments.length; i++) ...[
              Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
              InkWell(
                key: Key('breadcrumb_segment_$i'),
                onTap: () => _navigateToBreadcrumbIndex(i),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    segments[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (i == segments.length - 1) ? FontWeight.bold : FontWeight.w500,
                      color: (i == segments.length - 1)
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              key: const Key('breadcrumbs_new_folder_button'),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              tooltip: 'New Folder Here',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _showCreateFolderDialog,
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Action Pill for Batch Operations
  Widget _buildBatchActionPill(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedPaths.length} selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3B82F6)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('batch_copy_button'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF2563EB),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              tooltip: 'Copy Selected',
              onPressed: () => _startCopyOrMove(_selectedPaths.toList(), isCut: false),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: const Key('batch_move_button'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFF59E0B),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.drive_file_move_outlined, size: 18),
              tooltip: 'Move Selected',
              onPressed: () => _startCopyOrMove(_selectedPaths.toList(), isCut: true),
            ),
            if (_folderTabs.length > 1) ...[
              const SizedBox(width: 4),
              IconButton.filledTonal(
                key: const Key('batch_move_other_tab_button'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFECFDF5),
                  foregroundColor: const Color(0xFF059669),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.tab_rounded, size: 18),
                tooltip: 'Move to Other Tab',
                onPressed: _moveSelectedToOtherTab,
              ),
            ],
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: const Key('batch_rename_action_button'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF1D4ED8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
              tooltip: 'Batch Rename',
              onPressed: () {
                BatchRenamerModal.show(
                  context,
                  filePaths: _selectedPaths.toList(),
                  onRenamed: () {
                    setState(() {
                      _isMultiSelect = false;
                      _selectedPaths.clear();
                    });
                    _loadData();
                  },
                );
              },
            ),
            if (_selectedPaths.length == 2) ...[
              const SizedBox(width: 4),
              IconButton.filledTonal(
                key: const Key('batch_diff_action_button'),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F3FF),
                  foregroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                tooltip: 'Compare Text Diff',
                onPressed: () {
                  final list = _selectedPaths.toList();
                  final n1 = list[0].split(RegExp(r'[\\/]')).last;
                  final n2 = list[1].split(RegExp(r'[\\/]')).last;
                  FileHashDiffSheet.showTextDiff(
                    context,
                    leftPath: list[0],
                    leftName: n1,
                    rightPath: list[1],
                    rightName: n2,
                  );
                },
              ),
            ],
            const SizedBox(width: 4),
            IconButton.filledTonal(
              key: const Key('batch_compress_button'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF8B5CF6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.archive_outlined, size: 18),
              tooltip: 'Compress to ZIP',
              onPressed: () => _showCompressDialog(_selectedPaths.toList()),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              key: const Key('batch_beam_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: const Text('Beam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _batchBeamSelected,
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              key: const Key('batch_delete_button'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFEF4444),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              tooltip: 'Delete Selected',
              onPressed: _batchDeleteSelected,
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('batch_close_button'),
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Exit Selection',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _isMultiSelect = false;
                  _selectedPaths.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Google Files Style Storage Card with Storage Scope Switcher, Segmented Progress, and Deep Clean
  Widget _buildXiaomiStorageHero(ThemeData theme, bool isDark, StorageBreakdown breakdown) {
    final totalManaged = breakdown.totalManagedBytes;
    final double receivedRatio = totalManaged > 0 ? (breakdown.receivedBytes / totalManaged).clamp(0.05, 0.95) : 0.7;
    final double stagingRatio = totalManaged > 0 ? (breakdown.stagingBytes / totalManaged).clamp(0.05, 0.95) : 0.3;

    final hasDeviceInfo = _deviceStorageInfo != null && (_deviceStorageInfo!['totalBytes'] ?? 0) > 0;
    final devTotal = hasDeviceInfo ? _deviceStorageInfo!['totalBytes']! : 0;
    final devUsed = hasDeviceInfo ? _deviceStorageInfo!['usedBytes']! : 0;
    final devFree = hasDeviceInfo ? _deviceStorageInfo!['freeBytes']! : 0;
    final double devUsedRatio = devTotal > 0 ? (devUsed / devTotal).clamp(0.05, 0.95) : 0.5;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimalist Xiaomi Storage Scope Switcher
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('vault_storage_scope_vault'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (_browseInternalStorage) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _browseInternalStorage = false;
                          _currentSubPath = '';
                          _selectedCategory = null;
                          _selectedPaths.clear();
                          _isMultiSelect = false;
                        });
                        _loadData();
                      }
                    },
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      decoration: BoxDecoration(
                        color: !_browseInternalStorage ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: !_browseInternalStorage
                            ? Border.all(color: const Color(0xFFE5E7EB), width: 1.0)
                            : Border.all(color: Colors.transparent, width: 1.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_special_outlined,
                            size: 15,
                            color: !_browseInternalStorage ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'PeerLink Vault',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !_browseInternalStorage ? FontWeight.w700 : FontWeight.w500,
                                color: !_browseInternalStorage ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('vault_storage_scope_device'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (!_browseInternalStorage) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _browseInternalStorage = true;
                          _currentSubPath = '';
                          _selectedCategory = null;
                          _selectedPaths.clear();
                          _isMultiSelect = false;
                        });
                        _loadData();
                      }
                    },
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                      decoration: BoxDecoration(
                        color: _browseInternalStorage ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _browseInternalStorage
                            ? Border.all(color: const Color(0xFFE5E7EB), width: 1.0)
                            : Border.all(color: Colors.transparent, width: 1.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_android_rounded,
                            size: 15,
                            color: _browseInternalStorage ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Device Storage',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _browseInternalStorage ? FontWeight.w700 : FontWeight.w500,
                                color: _browseInternalStorage ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header Row with Storage Status & Clean Action
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final stackHeader = constraints.maxWidth < 460 || textScale >= 1.2;

              final titleCluster = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _browseInternalStorage ? Icons.sd_storage_outlined : Icons.inventory_2_outlined,
                      color: const Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _browseInternalStorage ? 'Device Storage' : 'Storage Overview',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _browseInternalStorage
                              ? (hasDeviceInfo
                                  ? '${_formatStorageBytes(devFree)} free of ${_formatStorageBytes(devTotal)}'
                                  : '${_files.length} items visible')
                              : '${breakdown.formattedReceivedSize} used • ${breakdown.fileCount} files',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actionWidget = !_browseInternalStorage
                  ? Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          key: const Key('vault_content_search_button'),
                          tooltip: 'Full-Text Content Search',
                          icon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF475569)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ContentSearchSheet.show(context),
                        ),
                        IconButton(
                          key: const Key('vault_scanner_button'),
                          tooltip: 'Scan Documents to PDF',
                          icon: const Icon(Icons.document_scanner_outlined, size: 18, color: Color(0xFF475569)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => DocumentScannerSheet.show(context, onScanComplete: _loadData),
                        ),
                        TextButton.icon(
                          key: const Key('deep_clean_button'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.cleaning_services_outlined, size: 14),
                          label: const Text(
                            'Deep Clean',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => DeepCleanSheet.show(context),
                        ),
                      ],
                    )
                  : IconButton(
                      tooltip: 'Refresh Storage',
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
                      onPressed: _loadData,
                    );

              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleCluster,
                    const SizedBox(height: 8),
                    actionWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleCluster),
                  const SizedBox(width: 8),
                  actionWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // Multi-color segmented storage progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: _browseInternalStorage
                  ? Row(
                      children: [
                        Expanded(
                          flex: (devUsedRatio * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFF10B981)), // Device used green
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: ((1.0 - devUsedRatio) * 100).toInt().clamp(1, 100),
                          child: Container(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)), // Device free
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: (receivedRatio * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFF3B82F6)), // Primary blue
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: (stagingRatio * 100).toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFFF59E0B)), // Staging amber
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: 40,
                          child: Container(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)), // Free space
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          if (!_browseInternalStorage)
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _buildLegendDot(const Color(0xFF3B82F6), 'Received (${breakdown.formattedReceivedSize})', isDark),
                _buildLegendDot(const Color(0xFFF59E0B), 'Cache (${breakdown.formattedStagingSize})', isDark),
              ],
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _buildLegendDot(
                  const Color(0xFF10B981),
                  hasDeviceInfo ? 'Used (${_formatStorageBytes(devUsed)})' : 'Used Space',
                  isDark,
                ),
                _buildLegendDot(
                  const Color(0xFF94A3B8),
                  hasDeviceInfo ? 'Free (${_formatStorageBytes(devFree)})' : 'Available',
                  isDark,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  /// Google Files-style 4x2 Category Squircle Grid
  Widget _buildXiaomiCategoryGrid(ThemeData theme, bool isDark) {
    final categories = [
      _CategoryMeta('Photos', ReceivedFileCategory.photos, Icons.image_rounded, const Color(0xFF8B5CF6)),
      _CategoryMeta('Videos', ReceivedFileCategory.videos, Icons.play_circle_fill_rounded, const Color(0xFFEF4444)),
      _CategoryMeta('Audio', ReceivedFileCategory.audio, Icons.headphones_rounded, const Color(0xFFF59E0B)),
      _CategoryMeta('Docs', ReceivedFileCategory.documents, Icons.description_rounded, const Color(0xFF3B82F6)),
      _CategoryMeta('Apps', ReceivedFileCategory.apps, Icons.android_rounded, const Color(0xFF10B981)),
      _CategoryMeta('Archives', ReceivedFileCategory.archives, Icons.inventory_2_rounded, const Color(0xFFEC4899)),
      _CategoryMeta('Downloads', ReceivedFileCategory.other, Icons.download_rounded, const Color(0xFF0D9488)),
      _CategoryMeta('All', null, Icons.grid_view_rounded, const Color(0xFF64748B)),
    ];

    final tileHeight = (MediaQuery.textScalerOf(context).scale(16) + 58).clamp(76.0, 126.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: tileHeight,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isDownloadsTile = cat.label == 'Downloads';
          final isAllTile = cat.label == 'All';
          final isSelected = isDownloadsTile
              ? _downloadsOnly
              : (isAllTile
                  ? (!_downloadsOnly && _selectedCategory == null)
                  : (!_downloadsOnly && _selectedCategory == cat.category));

          return InkWell(
            key: Key('vault_category_${cat.label.toLowerCase()}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isAllTile) {
                  _downloadsOnly = false;
                  _selectedCategory = null;
                } else if (isDownloadsTile) {
                  _downloadsOnly = !_downloadsOnly;
                  _selectedCategory = null;
                } else {
                  _downloadsOnly = false;
                  _selectedCategory = isSelected ? null : cat.category;
                  if (_selectedCategory == ReceivedFileCategory.photos) {
                    _isGridView = true;
                  }
                }
              });
              _loadData();
            },
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? cat.color : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 19),
                  ),
                  const SizedBox(height: 5),
                  Flexible(
                    child: Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? cat.color : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  /// Search Bar, Sort Toggle, Grid/List Mode Switcher, and Batch Selection Toggle
  Widget _buildSearchAndFilterControls(ThemeData theme, bool isDark) {
    if (_isMultiSelect) {
      final allSelected = _selectedPaths.length == _files.length && _files.isNotEmpty;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A29) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  key: const Key('select_all_checkbox'),
                  value: allSelected,
                  onChanged: (_) => _selectAll(),
                  activeColor: const Color(0xFF2563EB),
                ),
                Text(
                  allSelected ? 'Deselect All' : 'Select All (${_files.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancel'),
              onPressed: () {
                setState(() {
                  _isMultiSelect = false;
                  _selectedPaths.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _browseInternalStorage ? 'Search device files...' : 'Search received files...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF131A29) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => _loadData(),
            ),
          ),
          const SizedBox(width: 4),
          // New Folder Button
          IconButton(
            key: const Key('vault_new_folder_button'),
            icon: Icon(Icons.create_new_folder_outlined, color: isDark ? Colors.white70 : Colors.black87, size: 20),
            tooltip: 'New Folder',
            onPressed: _showCreateFolderDialog,
          ),
          // Batch select toggle button
          IconButton(
            key: const Key('toggle_multi_select_button'),
            icon: Icon(Icons.checklist_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
            tooltip: 'Select Files',
            onPressed: () {
              setState(() {
                _isMultiSelect = true;
              });
            },
          ),
          // Sort & Display Options Menu
          PopupMenuButton<String>(
            key: const Key('vault_sort_menu_button'),
            icon: Icon(Icons.sort_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 20),
            tooltip: 'Sort By',
            onSelected: (val) {
              if (val == 'toggle_hidden') {
                setState(() => _showHiddenFiles = !_showHiddenFiles);
                _loadData();
              } else if (val == 'new_tab') {
                _addFolderTab();
              } else if (val == 'new_note') {
                _showCreateNoteDialog();
              } else if (val == 'open_auto_sort') {
                AutoSortRulesSheet.show(context, onSorted: _loadData);
              } else if (val == 'open_stream_folder') {
                RemoteStreamBrowserSheet.show(context);
              } else if (val == 'open_universal_clipboard') {
                UniversalClipboardSheet.show(context);
              } else if (val == 'open_safe_folder') {
                SafeFolderSheet.show(context, onVaultChanged: _loadData);
              } else if (val == 'open_storage_cleaner') {
                StorageCleanerSheet.show(context, onCleaned: _loadData);
              } else if (val == 'open_hotspot_tether') {
                HotspotTetherQrSheet.show(context);
              } else if (val == 'open_network_diagnostic') {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: const NetworkDiagnosticCard(),
                    ),
                  ),
                );
              } else if (val == 'open_trash') {
                _showTrashSheet(context);
              } else {
                final mode = VaultSortMode.values.firstWhere((m) => m.name == val, orElse: () => VaultSortMode.dateDesc);
                setState(() => _sortMode = mode);
                _loadData();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'dateDesc', child: Text('Newest First')),
              const PopupMenuItem(value: 'dateAsc', child: Text('Oldest First')),
              const PopupMenuItem(value: 'nameAsc', child: Text('Name (A to Z)')),
              const PopupMenuItem(value: 'nameDesc', child: Text('Name (Z to A)')),
              const PopupMenuItem(value: 'sizeDesc', child: Text('Largest First')),
              const PopupMenuItem(value: 'sizeAsc', child: Text('Smallest First')),
              const PopupMenuItem(value: 'type', child: Text('File Type')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'new_tab',
                child: Row(
                  children: [
                    Icon(Icons.tab_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('New Folder Tab (Dual-Pane)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_note',
                child: Row(
                  children: [
                    Icon(Icons.note_add_outlined, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('New Note (.txt / .md)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_auto_sort',
                child: Row(
                  children: [
                    Icon(Icons.rule_folder_outlined, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Auto-Sort Inbox Rules', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_stream_folder',
                child: Row(
                  children: [
                    Icon(Icons.cast_connected_rounded, size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Stream Without Downloading', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_universal_clipboard',
                child: Row(
                  children: [
                    Icon(Icons.content_paste_go_rounded, size: 16, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Universal Clipboard Sync', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_safe_folder',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF15803D)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Safe Folder (PIN Locked)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_hidden',
                child: Row(
                  children: [
                    Icon(
                      _showHiddenFiles ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Show Hidden Files', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_storage_cleaner',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Deep Storage Cleaner', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_hotspot_tether',
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Hotspot Auto-Tether QR', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_network_diagnostic',
                child: Row(
                  children: [
                    Icon(Icons.network_check_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Wi-Fi 6 Link Diagnostic', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_trash',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Recycle Bin / Trash', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Grid / List Toggle
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  /// List View for Received Files & Folders with Comprehensive File Actions
  Widget _buildFilesList(ThemeData theme, bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isDir = file.isDirectory;
        final folderColor = const Color(0xFFF59E0B);
        final catColor = isDir ? folderColor : _getCategoryColor(file.category);
        final isSelected = _selectedPaths.contains(file.path);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1)
                : (isDark ? const Color(0xFF131A29) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isMultiSelect)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelect(file.path),
                      activeColor: const Color(0xFF2563EB),
                    ),
                  _buildFileThumbnail(
                    file,
                    size: 44,
                    radius: 12,
                    fallbackColor: catColor,
                  ),
                ],
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: Text(
                isDir
                    ? '${file.childCount} item(s) • ${_formatDate(file.lastModified)}'
                    : '${file.formattedSize} • ${_formatDate(file.lastModified)}',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
              ),
              trailing: _isMultiSelect
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDir)
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                            tooltip: 'Preview',
                            onPressed: () => _openFilePreview(file),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                        PopupMenuButton<String>(
                          key: Key('menu_${file.name}'),
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (action) => _handleFileAction(action, file),
                          itemBuilder: (ctx) => _buildMenuItems(file),
                        ),
                      ],
                    ),
              onTap: () {
                if (_isMultiSelect) {
                  _toggleSelect(file.path);
                } else if (isDir) {
                  _navigateToSubfolder(file.name);
                } else {
                  _openFilePreview(file);
                }
              },
              onLongPress: () => _toggleSelect(file.path),
            ),
          ),
        );
      },
    );
  }

  /// Grid View for Received Files & Folders with Card Action Menu
  Widget _buildFilesGrid(ThemeData theme, bool isDark) {
    final displayItems = _files.length > _gridDisplayLimit
        ? _files.sublist(0, _gridDisplayLimit)
        : _files;
    final hasMore = _files.length > _gridDisplayLimit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: MediaQuery.textScalerOf(context).scale(1.0) > 1.3 ? 0.70 : 0.85,
            ),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final file = displayItems[index];
              final isDir = file.isDirectory;
              final folderColor = const Color(0xFFF59E0B);
              final catColor = isDir ? folderColor : _getCategoryColor(file.category);
              final isSelected = _selectedPaths.contains(file.path);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (_isMultiSelect) {
                    _toggleSelect(file.path);
                  } else if (isDir) {
                    _navigateToSubfolder(file.name);
                  } else {
                    _openFilePreview(file);
                  }
                },
                onLongPress: () => _toggleSelect(file.path),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1)
                            : (isDark ? const Color(0xFF131A29) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _buildFileThumbnail(
                              file,
                              size: file.isImage ? 56 : 42,
                              radius: 12,
                              fallbackColor: catColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDir ? '${file.childCount} items' : file.formattedSize,
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isMultiSelect)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : Colors.black38,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                      )
                    else
                      Positioned(
                        top: 2,
                        right: 2,
                        child: PopupMenuButton<String>(
                          key: Key('grid_menu_${file.name}'),
                          icon: Icon(Icons.more_vert_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onSelected: (action) => _handleFileAction(action, file),
                          itemBuilder: (ctx) => _buildMenuItems(file),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (hasMore) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                key: const Key('load_more_grid_items_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                label: Text(
                  'Show more items (${_files.length - _gridDisplayLimit} remaining)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  setState(() {
                    _gridDisplayLimit += 60;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Unified Action Menu Items for both List and Grid Views
  List<PopupMenuEntry<String>> _buildMenuItems(ReceivedFileItem file) {
    final isDir = file.isDirectory;
    return [
      if (isDir) ...[
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Open Folder')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'stage_all',
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Stage Folder to Beam')),
            ],
          ),
        ),
      ] else ...[
        const PopupMenuItem(
          value: 'open_app',
          child: Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Open with App')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Share...')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'peerlink_share',
          child: Row(
            children: [
              Icon(Icons.ios_share_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Expanded(child: Text('Share via PeerLink')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'stage',
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Stage to Beam')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'web_beam',
          child: Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Web Beam (Browser)')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'preview',
          child: Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Preview / Inspect')),
            ],
          ),
        ),
      ],
      const PopupMenuItem(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.drive_file_rename_outline_rounded, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Rename')),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.copy_all_rounded, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Copy to...')),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'move',
        child: Row(
          children: [
            Icon(Icons.drive_file_move_outlined, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Move to...')),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'compress',
        child: Row(
          children: [
            Icon(Icons.archive_outlined, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Compress to ZIP')),
          ],
        ),
      ),
      if (file.name.toLowerCase().endsWith('.zip'))
        const PopupMenuItem(
          value: 'extract',
          child: Row(
            children: [
              Icon(Icons.unarchive_rounded, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Extract Archive')),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'details',
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('File Details')),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'reveal',
        child: Row(
          children: [
            Icon(Icons.folder_open_rounded, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Reveal in System')),
          ],
        ),
      ),
      if (!isDir) ...[
        const PopupMenuItem(
          value: 'burner_share',
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Expanded(child: Text('One-Time Burner Share')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'move_safe_folder',
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF15803D)),
              SizedBox(width: 8),
              Expanded(child: Text('Move to Safe Folder')),
            ],
          ),
        ),
      ],
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDir ? 'Delete Folder' : 'Delete File',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Unified File Action Dispatcher
  void _handleFileAction(String action, ReceivedFileItem file) async {
    switch (action) {
      case 'open_app':
        await _service.openFileWithDefaultApp(file.path);
        break;
      case 'share':
        await _service.shareFile(file.path);
        break;
      case 'peerlink_share':
        if (mounted) {
          ContextualShareSheet.show(
            context,
            initialPaths: [file.path],
          );
        }
        break;
      case 'stage':
        FileStagingService.instance.addPaths([file.path]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staged "${file.name}" to beam!'),
              backgroundColor: const Color(0xFF2563EB),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'web_beam':
        if (mounted) {
          WebBeamModal.showLive(
            context,
            initialPaths: [file.path],
          );
        }
        break;
      case 'copy':
        _startCopyOrMove([file.path], isCut: false);
        break;
      case 'move':
        _startCopyOrMove([file.path], isCut: true);
        break;
      case 'compress':
        _showCompressDialog([file.path]);
        break;
      case 'extract':
        _showExtractDialog(file);
        break;
      case 'open':
        _navigateToSubfolder(file.name);
        break;
      case 'stage_all':
        _stageDirectoryFiles(file.path);
        break;
      case 'preview':
        _openFilePreview(file);
        break;
      case 'move_safe_folder':
        if (!SafeFolderService.instance.isUnlocked) {
          await SafeFolderSheet.show(context, onVaultChanged: _loadData);
        }
        if (SafeFolderService.instance.isUnlocked && mounted) {
          try {
            await SafeFolderService.instance.lockFile(file.path);
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Encrypted "${file.name}" into Safe Folder'),
                  backgroundColor: const Color(0xFF15803D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not lock file: $e'), behavior: SnackBarBehavior.floating),
              );
            }
          }
        }
        break;
      case 'burner_share':
        _showCreateBurnerShareDialog(file);
        break;
      case 'rename':
        _showRenameDialog(file);
        break;
      case 'details':
        _showFileDetailsDialog(file);
        break;
      case 'reveal':
        _service.revealInFolder(file.path);
        break;
      case 'delete':
        _confirmDelete(file);
        break;
    }
  }

  /// Opens MediaPreviewModal with the current folder's non-directory playlist so users
  /// can swipe or tap Next/Prev seamlessly across photos, videos, audio, and documents.
  void _openFilePreview(ReceivedFileItem file, {bool openInEditMode = false}) {
    final playlist = _files.where((f) => !f.isDirectory).toList();
    final idx = playlist.indexWhere((f) => f.path == file.path);
    MediaPreviewModal.show(
      context,
      file,
      onDeleted: _loadData,
      playlist: playlist.length > 1 ? playlist : null,
      initialIndex: idx >= 0 ? idx : 0,
      openInEditMode: openInEditMode,
    );
  }

  /// Creates a one-time ephemeral burner share token and launches the self-destructing viewer modal.
  Future<void> _showCreateBurnerShareDialog(ReceivedFileItem file) async {
    final pinController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.local_fire_department_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Create Burner Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One-time self-destructing file share for "${file.name}". Permanently wipes from memory upon modal dismissal or after single view.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Optional 4-digit PIN (leave empty for none)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create & Launch Burner'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final pin = pinController.text.trim();
      final token = EphemeralBurnerShareService.instance.createBurnerShare(
        filePath: file.path,
        pin: pin.isNotEmpty ? pin : null,
      );
      pinController.dispose();
      await BurnerViewerModal.show(context, token: token);
    } else {
      pinController.dispose();
    }
  }

  /// Creates a new .txt or .md note in the current directory and opens the in-app editor.
  Future<void> _showCreateNoteDialog() async {
    final nameController = TextEditingController(text: 'note.txt');
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('New Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name (.txt or .md)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Create & Edit'),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (created == null || created.isEmpty || !mounted) return;
    final cleanName = created.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final finalName = cleanName.contains('.') ? cleanName : '$cleanName.txt';
    final dir = Directory(_currentDirectoryPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final filePath = '${dir.path}${Platform.pathSeparator}$finalName';
    final file = File(filePath);
    if (!file.existsSync()) {
      await file.writeAsString('', flush: true);
    }
    await _loadData();
    if (!mounted) return;
    final stat = file.statSync();
    final ext = finalName.contains('.') ? finalName.split('.').last : 'txt';
    final item = ReceivedFileItem(
      path: file.path,
      name: finalName,
      sizeBytes: stat.size,
      lastModified: stat.modified,
      category: _service.classifyExtension(ext),
      extension: ext,
    );
    _openFilePreview(item, openInEditMode: true);
  }

  /// Safe In-Place Renaming Dialog
  Future<void> _showRenameDialog(ReceivedFileItem item) async {
    final controller = TextEditingController(text: item.name);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('rename_dialog'),
        title: Row(
          children: [
            Icon(Icons.drive_file_rename_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(item.isDirectory ? 'Rename Folder' : 'Rename File', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a new name for "${item.name}":',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('rename_text_field'),
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name cannot be empty';
                  }
                  if (val.contains('/') ||
                      val.contains('\\') ||
                      val.contains(':') ||
                      val.contains('*') ||
                      val.contains('?') ||
                      val.contains('"') ||
                      val.contains('<') ||
                      val.contains('>') ||
                      val.contains('|')) {
                    return 'Name contains invalid characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('rename_confirm_button'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newName = controller.text.trim();
      if (newName != item.name) {
        final success = await _service.renameFile(item.path, newName);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Renamed to "$newName"'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to rename. Name might already exist.'),
                backgroundColor: Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  /// Google Files-Style Detailed Properties Bottom Sheet
  void _showFileDetailsDialog(ReceivedFileItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131A29) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (item.isDirectory ? const Color(0xFFF59E0B) : _getCategoryColor(item.category)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.isDirectory ? Icons.folder_rounded : _getCategoryIcon(item.category),
                      color: item.isDirectory ? const Color(0xFFF59E0B) : _getCategoryColor(item.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.isDirectory
                              ? 'Directory Folder'
                              : (item.extension.isNotEmpty ? '${item.extension.toUpperCase()} File' : 'Generic File'),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _buildDetailProperty('File Location', item.path, isDark, canCopy: true),
              _buildDetailProperty('Size', '${item.formattedSize} (${item.sizeBytes} bytes)', isDark),
              if (item.isDirectory)
                _buildDetailProperty('Contains', '${item.childCount} item(s)', isDark),
              _buildDetailProperty('Last Modified', _formatDetailedDate(item.lastModified), isDark),
              if (!item.isDirectory)
                _buildSha256Property(item.path, isDark),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!item.isDirectory) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _service.openFileWithDefaultApp(item.path);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _service.shareFile(item.path);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text('Stage'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (item.isDirectory) {
                          _stageDirectoryFiles(item.path);
                        } else {
                          FileStagingService.instance.addPaths([item.path]);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Staged "${item.name}" to beam!'),
                              backgroundColor: const Color(0xFF2563EB),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailProperty(String label, String value, bool isDark, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (canCopy)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Path copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF3B82F6)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDetailedDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  String _formatStorageBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Renders a real cached thumbnail for image files, falling back cleanly to a flat tint icon.
  Widget _buildFileThumbnail(
    ReceivedFileItem file, {
    required double size,
    required double radius,
    required Color fallbackColor,
  }) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        file.isDirectory ? Icons.folder_rounded : _getCategoryIcon(file.category),
        color: fallbackColor,
        size: (size * 0.52).clamp(18.0, 28.0),
      ),
    );

    if (!file.isDirectory && file.isImage && !file.path.startsWith('content://')) {
      final f = File(file.path);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 120,
          cacheHeight: 120,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    return fallback;
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isEmptyFolder = _currentSubPath.isNotEmpty;
    final hasCategory = _selectedCategory != null || _downloadsOnly;
    final catLabel = _downloadsOnly
        ? 'Downloads'
        : (_selectedCategory != null
            ? '${_selectedCategory!.name[0].toUpperCase()}${_selectedCategory!.name.substring(1)}'
            : '');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                hasCategory ? Icons.photo_library_outlined : Icons.folder_open_rounded,
                size: 32,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isEmptyFolder
                  ? 'Empty Folder'
                  : (hasCategory
                      ? 'No $catLabel in ${_browseInternalStorage ? "Device Storage" : "PeerLink Vault"}'
                      : (_browseInternalStorage ? 'No Files in Storage' : 'No Received Files')),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              isEmptyFolder
                  ? 'This folder does not contain any files.'
                  : (hasCategory && !_browseInternalStorage
                      ? 'Your phone or PC $catLabel live in Device Storage.'
                      : (_browseInternalStorage
                          ? 'Files located in your device storage will appear here.'
                          : 'Transferred photos, videos, and documents will appear here.')),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (hasCategory && !_browseInternalStorage) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('empty_switch_to_device_category'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _browseInternalStorage = true;
                    _currentSubPath = '';
                  });
                  _loadData();
                },
                icon: const Icon(Icons.phone_android_rounded, size: 16),
                label: Text('Browse Device $catLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ReceivedFileItem item) async {
    final isDir = item.isDirectory;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDir ? 'Move Folder to Trash?' : 'Move File to Trash?'),
        content: Text(
          isDir
              ? 'Move folder "${item.name}" to PeerLink Recycle Bin? You can restore it anytime.'
              : 'Move "${item.name}" to PeerLink Recycle Bin? You can undo or restore it anytime.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PeerLinkColors.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final trashPath = await _service.moveToTrash(item.path);
      if (trashPath == null) {
        await _service.deleteFile(item.path);
      }
      _loadData();
      if (mounted && trashPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${item.name}" to Recycle Bin'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _service.restoreFromTrash(trashPath);
                if (mounted) _loadData();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _showTrashSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return FutureBuilder<List<TrashItem>>(
            future: _service.listTrashItems(),
            builder: (_, snap) {
              final items = snap.data ?? const <TrashItem>[];
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFDC2626), size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recycle Bin (${items.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                const Text(
                                  'Restore accidentally deleted files safely',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (items.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await _service.emptyTrash();
                                setSheetState(() {});
                                if (mounted) _loadData();
                              },
                              child: const Text('Empty', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Recycle Bin is empty.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            itemBuilder: (_, idx) {
                              final t = items[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  t.isDirectory ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                                title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(t.formattedSize, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFFDBEAFE)),
                                  ),
                                  onPressed: () async {
                                    await _service.restoreFromTrash(t.trashPath);
                                    setSheetState(() {});
                                    if (mounted) _loadData();
                                  },
                                  child: const Text('Restore', style: TextStyle(fontSize: 12)),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIcon(ReceivedFileCategory category) {
    switch (category) {
      case ReceivedFileCategory.photos:
        return Icons.photo_library_outlined;
      case ReceivedFileCategory.videos:
        return Icons.video_library_outlined;
      case ReceivedFileCategory.audio:
        return Icons.music_note_outlined;
      case ReceivedFileCategory.documents:
        return Icons.description_outlined;
      case ReceivedFileCategory.apps:
        return Icons.apps_rounded;
      case ReceivedFileCategory.archives:
        return Icons.archive_outlined;
      case ReceivedFileCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getCategoryColor(ReceivedFileCategory category) {
    switch (category) {
      case ReceivedFileCategory.photos:
        return const Color(0xFF8B5CF6);
      case ReceivedFileCategory.videos:
        return const Color(0xFFEF4444);
      case ReceivedFileCategory.audio:
        return const Color(0xFFF59E0B);
      case ReceivedFileCategory.documents:
        return const Color(0xFF3B82F6);
      case ReceivedFileCategory.apps:
        return const Color(0xFF10B981);
      case ReceivedFileCategory.archives:
        return const Color(0xFFEC4899);
      case ReceivedFileCategory.other:
        return Colors.white70;
    }
  }
}

class _CategoryMeta {
  final String label;
  final ReceivedFileCategory? category;
  final IconData icon;
  final Color color;

  const _CategoryMeta(this.label, this.category, this.icon, this.color);
}
