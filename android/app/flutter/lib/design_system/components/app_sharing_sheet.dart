import 'package:flutter/material.dart';
import '../../core/app_sharing_service.dart';
import '../colors/peerlink_colors.dart';
import 'glass_container.dart';

/// Modal bottom sheet for browsing and selecting installed applications to send offline.
class AppSharingSheet extends StatefulWidget {
  final void Function(SharedAppInfo app)? onAppSelected;

  const AppSharingSheet({super.key, this.onAppSelected});

  static Future<void> show(BuildContext context, {void Function(SharedAppInfo app)? onAppSelected}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AppSharingSheet(onAppSelected: onAppSelected),
      ),
    );
  }

  @override
  State<AppSharingSheet> createState() => _AppSharingSheetState();
}

class _AppSharingSheetState extends State<AppSharingSheet> {
  final AppSharingService _service = AppSharingService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<SharedAppInfo> _apps = [];
  bool _isLoading = true;
  bool _includeSystem = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _service.getInstalledApps(
      searchFilter: _searchController.text,
      includeSystem: _includeSystem,
    );
    if (mounted) {
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final isDark = theme.brightness == Brightness.dark;
        return GlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.android_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Installed Apps (APK)',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Select an app to extract and send offline',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 20, color: theme.colorScheme.outlineVariant),

              // Search Bar & Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadApps();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (_) => _loadApps(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('System', style: TextStyle(fontSize: 11)),
                    selected: _includeSystem,
                    onSelected: (val) {
                      setState(() => _includeSystem = val);
                      _loadApps();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // App List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _apps.isEmpty
                        ? Center(
                            child: Text(
                              'No applications found.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _apps.length,
                            itemBuilder: (context, index) {
                              final app = _apps[index];
                              return _buildAppTile(theme, app);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppTile(ThemeData theme, SharedAppInfo app) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.android_rounded, color: Color(0xFF10B981), size: 22),
        ),
        title: Text(
          app.appName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          '${app.packageName} • v${app.versionName} • ${app.formattedSize}',
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () {
            _service.stageAppForSending(app);
            widget.onAppSelected?.call(app);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Staged ${app.appName} APK for transfer.'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          },
          child: const Text('Send', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
