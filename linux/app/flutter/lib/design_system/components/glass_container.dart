import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Minimalist Glassmorphic Container for PeerLink.
/// Combines frosted glass backdrop blur, subtle inner borders, translucent gradients,
/// and optional atmospheric glowing drop-shadows tailored to specific operations.
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
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(20);

    // Subtle frosted glass gradient background
    final defaultBg = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x22FFFFFF), // 13% white sheen
              Color(0x0CFFFFFF), // 5% white depth
              Color(0x1A0F172A), // Subtle dark tint
            ],
            stops: [0.0, 0.5, 1.0],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xCCFFFFFF), // 80% white surface
              Color(0xAAFFFFFF), // 67% white surface
              Color(0x88F8FAFC), // Crisp light glass
            ],
            stops: [0.0, 0.6, 1.0],
          );

    // Atmospheric edge reflections
    final border = customBorder ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        );

    // Atmospheric glow / shadow
    final boxShadow = [
      if (glowColor != null)
        BoxShadow(
          color: glowColor!.withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customBgColor,
        gradient: customBgColor == null ? defaultBg : null,
        borderRadius: r,
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          splashColor: (glowColor ?? theme.colorScheme.primary).withValues(alpha: 0.12),
          highlightColor: (glowColor ?? theme.colorScheme.primary).withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}
