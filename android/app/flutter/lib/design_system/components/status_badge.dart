import 'package:flutter/material.dart';
import '../typography/peerlink_typography.dart';

enum BadgeStatus {
  success,
  warning,
  danger,
  neutral,
  info,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    Color borderColor;

    switch (status) {
      case BadgeStatus.success:
        textColor = const Color(0xFF1B5E20);
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFFA5D6A7);
        break;
      case BadgeStatus.warning:
        textColor = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFCC80);
        break;
      case BadgeStatus.danger:
        textColor = const Color(0xFFB71C1C);
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFEF9A9A);
        break;
      case BadgeStatus.info:
        textColor = const Color(0xFF0D47A1);
        bgColor = const Color(0xFFE3F2FD);
        borderColor = const Color(0xFF90CAF9);
        break;
      case BadgeStatus.neutral:
        textColor = const Color(0xFF424242);
        bgColor = const Color(0xFFEEEEEE);
        borderColor = const Color(0xFFBDBDBD);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: PeerLinkTypography.badgeLabel.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
