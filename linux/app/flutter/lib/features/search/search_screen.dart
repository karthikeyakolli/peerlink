import 'package:flutter/material.dart';
import '../../core/device_trust_service.dart';
import '../../core/operation_journal_service.dart';
import '../../core/sync_backup_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

enum ResultAvailability {
  localRetrievable,
  remoteRetrievable,
  remoteOfflineDiscovered,
}

class SearchResultItem {
  final String filename;
  final String path;
  final String deviceName;
  final String deviceId;
  final String size;
  final String category;
  final ResultAvailability availability;
  final IconData icon;
  final Color iconColor;

  SearchResultItem({
    required this.filename,
    required this.path,
    required this.deviceName,
    required this.deviceId,
    required this.size,
    required this.category,
    required this.availability,
    required this.icon,
    this.iconColor = const Color(0xFF6366F1),
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0;

  final List<String> _filters = [
    'All',
    'Local Spaces',
    'Peer Indexes',
    'Backups',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SearchResultItem> _generateResults(String query) {
    final results = <SearchResultItem>[];
    final q = query.toLowerCase();

    // 1. Search configured Sync Spaces
    for (final space in SyncBackupService.instance.spaces) {
      if (q.isEmpty || space.name.toLowerCase().contains(q) || space.localPath.toLowerCase().contains(q)) {
        results.add(SearchResultItem(
          filename: space.name,
          path: space.localPath,
          deviceName: 'This Device (Sync Space)',
          deviceId: 'local',
          size: '${space.fileCount} files',
          category: 'Sync Space',
          availability: ResultAvailability.localRetrievable,
          icon: Icons.folder_shared_rounded,
          iconColor: const Color(0xFF2563EB),
        ));
      }
    }

    // 2. Search Backup Snapshots
    for (final snap in SyncBackupService.instance.snapshots) {
      if (q.isEmpty || snap.name.toLowerCase().contains(q) || snap.sourcePath.toLowerCase().contains(q)) {
        results.add(SearchResultItem(
          filename: snap.name,
          path: snap.sourcePath,
          deviceName: 'Local Merkle Vault',
          deviceId: 'local',
          size: snap.totalSize,
          category: 'Backup Snapshot',
          availability: ResultAvailability.localRetrievable,
          icon: Icons.history_edu_rounded,
          iconColor: const Color(0xFF7C3AED),
        ));
      }
    }

    // 3. Search Operation Journal records
    for (final op in OperationJournalService.instance.operations) {
      if (q.isEmpty || op.summary.toLowerCase().contains(q) || op.operationId.toLowerCase().contains(q)) {
        results.add(SearchResultItem(
          filename: op.summary,
          path: 'Journal: ${op.operationId}',
          deviceName: 'Journal Record',
          deviceId: op.peerId,
          size: '${(op.totalBytes / 1048576).toStringAsFixed(1)} MB',
          category: 'Transfer Record',
          availability: ResultAvailability.localRetrievable,
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF10B981),
        ));
      }
    }

    // 4. Search Authorized Peer Indexes
    if (q.isNotEmpty) {
      for (final peer in DeviceTrustService.instance.devices) {
        if (peer.name.toLowerCase().contains(q) || peer.id.toLowerCase().contains(q) || query.length >= 2) {
          final isOnline = peer.isOnline;
          results.add(SearchResultItem(
            filename: '${peer.name} Index Manifest',
            path: 'peer://${peer.id}/manifest.json',
            deviceName: peer.name,
            deviceId: peer.id,
            size: isOnline ? 'Available via P2P' : 'Cached Catalog Only',
            category: 'Peer Index',
            availability: isOnline
                ? ResultAvailability.remoteRetrievable
                : ResultAvailability.remoteOfflineDiscovered,
            icon: isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            iconColor: isOnline ? const Color(0xFF10B981) : Colors.amber.shade700,
          ));
        }
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchController.text.trim();
    final allResults = _generateResults(query);

    final filteredResults = allResults.where((item) {
      if (_selectedFilter == 1) return item.category == 'Sync Space';
      if (_selectedFilter == 2) return item.category == 'Peer Index';
      if (_selectedFilter == 3) return item.category == 'Backup Snapshot';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Device Omni-Search'),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GlassContainer(
              glowColor: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search local spaces, backups, and authorized peers...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: List.generate(_filters.length, (idx) {
                final isSelected = _selectedFilter == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(_filters[idx]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = idx;
                      });
                    },
                    selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    checkmarkColor: const Color(0xFF6366F1),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          // Content List
          Expanded(
            child: allResults.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GlassContainer(
                        glowColor: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.saved_search_rounded, size: 48, color: Color(0xFF6366F1)),
                            const SizedBox(height: 12),
                            Text(
                              'Search Local and Authorized Peer Indexes',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Search local sync directories, verified backup snapshots, and authorized peer catalogs. Discovered remote results are clearly distinguished from content retrievable right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : filteredResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 44, color: theme.disabledColor),
                            const SizedBox(height: 12),
                            Text(
                              'No matching items found for "$query"',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Check spelling or ensure target peer is paired.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: filteredResults.length,
                        itemBuilder: (context, idx) {
                          final item = filteredResults[idx];
                          Color availColor;
                          String availText;

                          switch (item.availability) {
                            case ResultAvailability.localRetrievable:
                              availColor = const Color(0xFF10B981);
                              availText = 'LOCAL RETRIEVABLE';
                              break;
                            case ResultAvailability.remoteRetrievable:
                              availColor = const Color(0xFF10B981);
                              availText = 'RETRIEVABLE (ONLINE)';
                              break;
                            case ResultAvailability.remoteOfflineDiscovered:
                              availColor = const Color(0xFFF59E0B);
                              availText = 'DISCOVERED (OFFLINE)';
                              break;
                          }

                          return InteractiveGlassCard(
                            glowColor: availColor,
                            margin: const EdgeInsets.only(bottom: 10),
                            borderRadius: BorderRadius.circular(16),
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: item.iconColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(item.icon, color: item.iconColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.filename,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.deviceName} • ${item.size}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.path,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.white38 : Colors.black45,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: availColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: availColor),
                                  ),
                                  child: Text(
                                    availText,
                                    style: TextStyle(
                                      color: availColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
