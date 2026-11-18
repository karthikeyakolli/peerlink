import 'package:flutter/material.dart';

/// Minimalist Card Container for PeerLink.
/// Modern clean elevation, crisp subtle 1px border for clear block differentiation,
/// and complete elimination of neon/glowing drop shadows.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final Color? customBgColor;
  final double blur;
  final Border? customBorder;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.glowColor,
    this.customBgColor,
    this.blur = 16.0,
    this.customBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = borderRadius ?? BorderRadius.circular(14);

    // Pure minimalist Light Mode surface — flat white, neutral 1px border, zero glow
    const defaultBg = Colors.white;
    final border = customBorder ??
        Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customBgColor ?? defaultBg,
        borderRadius: r,
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            splashColor: (glowColor ?? theme.colorScheme.primary).withValues(alpha: 0.08),
            highlightColor: (glowColor ?? theme.colorScheme.primary).withValues(alpha: 0.04),
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }
}
