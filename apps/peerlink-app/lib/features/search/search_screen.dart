import 'package:flutter/material.dart';

class SearchResultItem {
  final String filename;
  final String path;
  final String deviceName;
  final String size;
  final String modified;
  final IconData icon;

  SearchResultItem({
    required this.filename,
    required this.path,
    required this.deviceName,
    required this.size,
    required this.modified,
    required this.icon,
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

  final List<String> _filters = ['All Files', 'Documents', 'Photos & Video', 'Shared Spaces'];

  final List<SearchResultItem> _results = [
    SearchResultItem(
      filename: 'PeerLink_Architecture_Spec.pdf',
      path: 'Documents/Specs/',
      deviceName: 'This Device (Local Node)',
      size: '1.4 MB',
      modified: 'Modified today',
      icon: Icons.picture_as_pdf_rounded,
    ),
    SearchResultItem(
      filename: 'Q3_Financial_Summary.xlsx',
      path: 'Work/Reports/',
      deviceName: 'MacBook Pro 16"',
      size: '840 KB',
      modified: 'Modified 2 days ago',
      icon: Icons.table_chart_rounded,
    ),
    SearchResultItem(
      filename: 'IMG_20261003_Sunset.jpg',
      path: 'Camera/2026/',
      deviceName: 'Pixel 8 Pro',
      size: '4.8 MB',
      modified: 'Modified yesterday',
      icon: Icons.image_rounded,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Device Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files across connected peers...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search queries local and online peer manifests. Offline devices will synchronize results upon reconnecting.',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Indexed Files (${_results.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(item.icon, color: Colors.blue),
                      ),
                      title: Text(item.filename, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${item.path} • ${item.deviceName} • ${item.size}', style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'Request File',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Requested "${item.filename}" from ${item.deviceName}')),
                          );
                        },
                      ),
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
