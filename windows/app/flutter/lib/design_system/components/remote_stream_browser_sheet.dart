import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/lan_media_stream_service.dart';
import '../../core/received_files_service.dart';

/// Minimalist Light-Only "Stream Without Downloading" Sheet.
/// Host your PeerLink Vault over local Wi-Fi (token-authenticated HTTP 206 Range streaming)
/// OR connect to another PeerLink device's stream URL to browse & play with 0 MB stored locally.
class RemoteStreamBrowserSheet extends StatefulWidget {
  const RemoteStreamBrowserSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RemoteStreamBrowserSheet(),
    );
  }

  @override
  State<RemoteStreamBrowserSheet> createState() => _RemoteStreamBrowserSheetState();
}

class _RemoteStreamBrowserSheetState extends State<RemoteStreamBrowserSheet> {
  final LanMediaStreamService _streamService = LanMediaStreamService.instance;
  final TextEditingController _remoteUrlCtrl = TextEditingController();

  bool _startingHost = false;
  bool _loadingRemote = false;
  String? _remoteError;
  String _remoteSubPath = '';
  List<RemoteStreamItem> _remoteItems = [];

  @override
  void dispose() {
    _remoteUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleHosting() async {
    if (_streamService.currentState.isHosting) {
      await _streamService.stopHosting();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _startingHost = true);
    try {
      await _streamService.startHostingFolder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start stream server: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _startingHost = false);
    }
  }

  Future<void> _browseRemote({String subPath = ''}) async {
    final url = _remoteUrlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _remoteError = 'Paste a PeerLink Stream URL (http://ip:port/?token=...)');
      return;
    }
    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });
    try {
      final items = await _streamService.fetchRemoteDirectory(url, subPath: subPath);
      if (mounted) {
        setState(() {
          _remoteSubPath = subPath;
          _remoteItems = items;
          _loadingRemote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _remoteError = 'Could not reach peer stream: $e';
          _loadingRemote = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostState = _streamService.currentState;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Icon(Icons.cast_connected_rounded, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stream Without Downloading',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Zero-storage HTTP Range streaming over local Wi-Fi',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 22, color: Color(0xFFE5E7EB)),

              // Section 1: Host This Device's Vault for Streaming
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Host My Folder Over Wi-Fi',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                        FilledButton(
                          key: const Key('lan_stream_host_toggle_button'),
                          onPressed: _startingHost ? null : _toggleHosting,
                          style: FilledButton.styleFrom(
                            backgroundColor: hostState.isHosting ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(hostState.isHosting ? 'Stop' : 'Start Hosting', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    if (hostState.isHosting) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                hostState.shareUrl,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy Stream Link',
                              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: hostState.shareUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Stream link copied'), behavior: SnackBarBehavior.floating),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Connect & Browse Another Peer's Folder
              const Text(
                'Browse Another Device\'s Stream',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('lan_stream_url_field'),
                      controller: _remoteUrlCtrl,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.x.x:port/?token=...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('lan_stream_connect_button'),
                    onPressed: _loadingRemote ? null : () => _browseRemote(),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    child: Text(_loadingRemote ? '...' : 'Connect'),
                  ),
                ],
              ),
              if (_remoteError != null) ...[
                const SizedBox(height: 8),
                Text(_remoteError!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
              ],
              if (_remoteSubPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      final parent = _remoteSubPath.contains('/')
                          ? _remoteSubPath.substring(0, _remoteSubPath.lastIndexOf('/'))
                          : '';
                      _browseRemote(subPath: parent);
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text('Up from /$_remoteSubPath', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              if (_remoteItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _remoteItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final item = _remoteItems[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isDirectory ? Icons.folder_outlined : Icons.play_circle_outline_rounded,
                            size: 18,
                            color: item.isDirectory ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                Text(item.formattedSize, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (item.isDirectory) {
                                _browseRemote(subPath: item.relativePath);
                              } else {
                                ReceivedFilesService.instance.openFileWithDefaultApp(item.streamUrl);
                              }
                            },
                            child: Text(item.isDirectory ? 'Open' : 'Stream', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
