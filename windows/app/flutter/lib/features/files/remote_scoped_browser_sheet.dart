import 'package:flutter/material.dart';
import '../../core/device_trust_service.dart';
import '../../core/remote_access_service.dart';
import '../../design_system/components/glass_container.dart';

/// Interactive Remote Scoped File Explorer (ACCESS Mode UI).
/// Allows browsing and downloading files from paired peers within sandboxed shares.
class RemoteScopedBrowserSheet extends StatefulWidget {
  final PairedDevice device;

  const RemoteScopedBrowserSheet({super.key, required this.device});

  /// Displays the Remote Scoped Browser as a full-height modal bottom sheet.
  static Future<void> show(BuildContext context, PairedDevice device) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RemoteScopedBrowserSheet(device: device),
    );
  }

  @override
  State<RemoteScopedBrowserSheet> createState() => _RemoteScopedBrowserSheetState();
}

class _RemoteScopedBrowserSheetState extends State<RemoteScopedBrowserSheet> {
  final RemoteAccessService _accessService = RemoteAccessService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<RemoteShareScope> _shares = [];
  RemoteShareScope? _currentShare;
  final List<String> _pathStack = []; // Breadcrumbs: e.g. ['documents']
  List<RemoteFileItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadInitialShares();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _currentRelativePath => _pathStack.join('/');

  Future<void> _loadInitialShares() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shares = await _accessService.getSharesForPeer(widget.device.id);
      if (shares.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Peer has not published any authorized shares.';
        });
        return;
      }

      _shares = shares;
      _currentShare = shares.first;
      await _loadDirectory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadDirectory() async {
    if (_currentShare == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _accessService.browseDirectory(
        peerId: widget.device.id,
        shareId: _currentShare!.shareId,
        relativePath: _currentRelativePath,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _navigateToFolder(RemoteFileItem item) {
    final folderSegment = item.relativePath.split('/').last;
    setState(() {
      _pathStack.add(folderSegment);
      _searchController.clear();
      _searchFilter = '';
    });
    _loadDirectory();
  }

  void _navigateUpTo(int index) {
    if (index < 0) {
      // Navigate to root
      setState(() {
        _pathStack.clear();
        _searchController.clear();
        _searchFilter = '';
      });
    } else {
      setState(() {
        _pathStack.removeRange(index + 1, _pathStack.length);
        _searchController.clear();
        _searchFilter = '';
      });
    }
    _loadDirectory();
  }

  IconData _getFileIcon(RemoteFileItem item) {
    if (item.isDirectory) return Icons.folder_rounded;
    final ext = item.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'mov':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file_rounded;
      case 'zip':
      case 'tar':
      case 'gz':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'dart':
      case 'java':
      case 'kt':
      case 'py':
      case 'json':
      case 'xml':
        return Icons.code_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(RemoteFileItem item) {
    if (item.isDirectory) return const Color(0xFFF59E0B);
    final ext = item.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
      case 'doc':
      case 'docx':
        return const Color(0xFFEF4444);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return const Color(0xFF8B5CF6);
      case 'mp4':
      case 'mkv':
      case 'mov':
        return const Color(0xFFEC4899);
      case 'zip':
      case 'tar':
      case 'gz':
        return const Color(0xFFF59E0B);
      case 'dart':
      case 'java':
      case 'kt':
      case 'py':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  void _showFileDetailsModal(RemoteFileItem item) {
    double downloadProgress = 0.0;
    bool isDownloading = false;
    bool isCompleted = false;
    String? localPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getFileColor(item).withValues(alpha: 0.15),
                    child: Icon(_getFileIcon(item), color: _getFileColor(item), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.formattedSize} · ${item.mimeType}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Metadata Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildMetaRow('Remote Path', item.relativePath),
                    const Divider(height: 12),
                    _buildMetaRow('Modified Time', item.modifiedTime.toLocal().toString().split('.').first),
                    const Divider(height: 12),
                    _buildMetaRow('Integrity Digest', 'SHA-256: ${item.contentHash.substring(0, 16)}...'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Security Policy Badge (Rule 10)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Safe Staging: Downloaded into quarantine (.part) with SHA-256 integrity verification. Never auto-executed (Rule 10 Enforced).',
                        style: TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (isDownloading) ...[
                LinearProgressIndicator(value: downloadProgress),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Downloading & verifying... ${(downloadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (isCompleted) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved to: $localPath',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: isDownloading || isCompleted
                    ? null
                    : () async {
                        setModalState(() {
                          isDownloading = true;
                          downloadProgress = 0.0;
                        });

                        try {
                          final path = await _accessService.downloadFile(
                            peerId: widget.device.id,
                            shareId: _currentShare?.shareId ?? 'default',
                            item: item,
                            destinationDir: '/storage/downloads',
                            onProgress: (p) {
                              setModalState(() {
                                downloadProgress = p;
                              });
                            },
                          );

                          setModalState(() {
                            isDownloading = false;
                            isCompleted = true;
                            localPath = path;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloaded "${item.name}" safely!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            isDownloading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Download failed: $e'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                icon: Icon(isCompleted ? Icons.check_rounded : Icons.download_rounded),
                label: Text(isCompleted ? 'Download Complete' : 'Download to This Device'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredItems = _items.where((i) {
      if (_searchFilter.isEmpty) return true;
      return i.name.toLowerCase().contains(_searchFilter.toLowerCase());
    }).toList();

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Icon(
                    widget.device.deviceType.toLowerCase().contains('phone')
                        ? Icons.phone_android_rounded
                        : Icons.laptop_rounded,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browse: ${widget.device.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${widget.device.id} · Scoped Sandbox',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Folder',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadDirectory,
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Security Scoped Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Browsing authorized share: ${_currentShare?.displayName ?? "Default Share"} (Rule 2 Sandboxed)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Breadcrumbs Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _navigateUpTo(-1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.home_rounded,
                            size: 16,
                            color: _pathStack.isEmpty ? const Color(0xFF2563EB) : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentShare?.displayName ?? 'Root',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _pathStack.isEmpty ? FontWeight.bold : FontWeight.normal,
                              color: _pathStack.isEmpty ? const Color(0xFF2563EB) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (int i = 0; i < _pathStack.length; i++) ...[
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _navigateUpTo(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          _pathStack[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: i == _pathStack.length - 1 ? FontWeight.bold : FontWeight.normal,
                            color: i == _pathStack.length - 1 ? const Color(0xFF2563EB) : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Search / Filter Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter files in this directory...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) {
                setState(() => _searchFilter = val.trim());
              },
            ),
          ),

          // File List / Loading / Error
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Colors.red),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadDirectory,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchFilter.isNotEmpty ? 'No files match "$_searchFilter"' : 'This directory is empty',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                            itemBuilder: (ctx, index) {
                              final item = filteredItems[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _getFileColor(item).withValues(alpha: 0.12),
                                  child: Icon(
                                    _getFileIcon(item),
                                    color: _getFileColor(item),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item.isDirectory
                                      ? item.formattedSize
                                      : '${item.formattedSize} · ${item.modifiedTime.toLocal().toString().split(" ").first}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Icon(
                                  item.isDirectory ? Icons.chevron_right_rounded : Icons.file_download_outlined,
                                  color: item.isDirectory ? Colors.grey : const Color(0xFF2563EB),
                                ),
                                onTap: () {
                                  if (item.isDirectory) {
                                    _navigateToFolder(item);
                                  } else {
                                    _showFileDetailsModal(item);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
      ),
    );
  }
}
