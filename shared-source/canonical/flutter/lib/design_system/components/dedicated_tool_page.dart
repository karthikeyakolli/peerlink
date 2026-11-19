import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors/peerlink_colors.dart';

/// Dedicated Full-Screen Page Container for PeerLink Studio Tools & Features.
/// Replaces cramped bottom-sheet popups with an expansive, dedicated workspace page
/// featuring a consistent Minimalist Light AppBar, breadcrumb context, and 100% full-height layout.
class DedicatedToolPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final List<Widget>? actions;

  const DedicatedToolPage({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.actions,
  });

  /// Navigates cleanly to a dedicated full-page tool experience.
  static Future<T?> open<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget child,
    List<Widget>? actions,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => DedicatedToolPage(
          title: title,
          subtitle: subtitle,
          icon: icon,
          actions: actions,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          tooltip: 'Back',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Icon(icon, size: 18, color: PeerLinkColors.primaryBlue),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: child,
      ),
    );
  }
}
