import 'package:flutter/material.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

class SearchResultItem {
  final String filename;
  final String path;
  final String deviceName;
  final String deviceType;
  final String size;
  final String modified;
  final IconData icon;
  final Color iconColor;

  SearchResultItem({
    required this.filename,
    required this.path,
    required this.deviceName,
    this.deviceType = 'desktop',
    required this.size,
    required this.modified,
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
    'All Files',
    'Documents',
    'Photos & Video',
    'Shared Spaces',
  ];

  final List<SearchResultItem> _results = [
    SearchResultItem(
      filename: 'PeerLink_Architecture_Spec.pdf',
      path: 'Documents/Specs/',
      deviceName: 'This Device (Local Node)',
      deviceType: 'phone',
      size: '1.4 MB',
      modified: 'Modified today',
      icon: Icons.picture_as_pdf_rounded,
      iconColor: Colors.red,
    ),
    SearchResultItem(
      filename: 'Q3_Financial_Summary.xlsx',
      path: 'Work/Reports/',
      deviceName: 'MacBook Pro 16"',
      deviceType: 'laptop',
      size: '840 KB',
      modified: 'Modified 2 days ago',
      icon: Icons.table_chart_rounded,
      iconColor: Colors.green,
    ),
    SearchResultItem(
      filename: 'IMG_20261003_Sunset.jpg',
      path: 'Camera/2026/',
      deviceName: 'Pixel 8 Pro',
      deviceType: 'phone',
      size: '4.8 MB',
      modified: 'Modified yesterday',
      icon: Icons.image_rounded,
      iconColor: Colors.purple,
    ),
    SearchResultItem(
      filename: 'dataset_export_v2.json',
      path: 'Projects/Analysis/',
      deviceName: 'Ubuntu Studio',
      deviceType: 'desktop',
      size: '12.4 MB',
      modified: 'Modified 3 days ago',
      icon: Icons.data_object_rounded,
      iconColor: const Color(0xFF06B6D4),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = _searchController.text.trim().toLowerCase();
    final filteredResults = _results.where((item) {
      if (query.isEmpty) return true;
      return item.filename.toLowerCase().contains(query) ||
          item.path.toLowerCase().contains(query) ||
          item.deviceName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Device Omni-Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glassmorphic Search Input Bar
            GlassContainer(
              glowColor: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search files across connected peers...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_filters[index]),
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.18),
                      checkmarkColor: const Color(0xFF6366F1),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF6366F1) : null,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedFilter = index;
                        });
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Info Callout
            GlassContainer(
              glowColor: Colors.blueGrey,
              padding: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(14),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Omni-search queries indexed peer manifests with zero cloud relay. 1-tap beam downloads directly from remote node.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Indexed Network Files (${filteredResults.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '3 Nodes Online',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: filteredResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 10),
                          Text('No matching files found',
                              style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredResults.length,
                      itemBuilder: (context, index) {
                        final item = filteredResults[index];
                        return InteractiveGlassCard(
                          glowColor: item.iconColor,
                          margin: const EdgeInsets.only(bottom: 10),
                          borderRadius: BorderRadius.circular(18),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: item.iconColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                item.deviceType == 'phone'
                                                    ? Icons.smartphone_rounded
                                                    : Icons.laptop_rounded,
                                                size: 11,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.deviceName,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.size} • ${item.modified}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Beaming "${item.filename}" from ${item.deviceName}...'),
                                      backgroundColor: const Color(0xFF2563EB),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Pull'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
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
      ),
    );
  }
}
