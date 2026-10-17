import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Interactive Glassmorphic Card with rich micro-animations:
/// - Desktop pointer hover scale and glow expansion
/// - Mobile/desktop tactile tap compression
/// - Frosted glass backdrop blur (sigma 16)
/// - Translucent gradient surface with subtle specular border
/// - Operation-tailored atmospheric glow
class InteractiveGlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final Color? customBgColor;
  final double blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final String? tooltip;

  const InteractiveGlassCard({
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
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.tooltip,
  });

  @override
  State<InteractiveGlassCard> createState() => _InteractiveGlassCardState();
}

class _InteractiveGlassCardState extends State<InteractiveGlassCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.borderRadius ?? BorderRadius.circular(20);

    // Subtle frosted glass gradient background
    final defaultBg = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(_isHovered ? 0x2AFFFFFF : 0x1EFFFFFF), // Sheen
              Color(_isHovered ? 0x14FFFFFF : 0x0AFFFFFF), // Depth
              const Color(0x1A0F172A),
            ],
            stops: const [0.0, 0.5, 1.0],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(_isHovered ? 0xF0FFFFFF : 0xCCFFFFFF),
              Color(_isHovered ? 0xD0FFFFFF : 0xAAFFFFFF),
              const Color(0x88F8FAFC),
            ],
            stops: const [0.0, 0.6, 1.0],
          );

    final effectiveGlow = widget.isSelected
        ? (widget.glowColor ?? theme.colorScheme.primary)
        : widget.glowColor;

    // Glowing drop shadow that blooms on hover or selection
    final boxShadow = [
      if (effectiveGlow != null)
        BoxShadow(
          color: effectiveGlow.withValues(
            alpha: _isHovered || widget.isSelected
                ? (isDark ? 0.38 : 0.28)
                : (isDark ? 0.20 : 0.12),
          ),
          blurRadius: _isHovered || widget.isSelected ? 28 : 18,
          spreadRadius: _isHovered || widget.isSelected ? 0 : -2,
          offset: const Offset(0, 6),
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
        blurRadius: _isHovered ? 18 : 12,
        offset: const Offset(0, 4),
      ),
    ];

    final borderColor = widget.isSelected
        ? (widget.glowColor ?? theme.colorScheme.primary)
        : (_isHovered
            ? (isDark ? Colors.white38 : Colors.white)
            : (isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.8)));

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.customBgColor,
        gradient: widget.customBgColor == null ? defaultBg : null,
        borderRadius: r,
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 1.8 : 1.2,
        ),
      ),
      child: widget.child,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: r,
          splashColor: (widget.glowColor ?? theme.colorScheme.primary)
              .withValues(alpha: 0.14),
          highlightColor: (widget.glowColor ?? theme.colorScheme.primary)
              .withValues(alpha: 0.07),
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _animController.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _animController.reverse();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _animController.reverse();
          },
          child: cardContent,
        ),
      );
    }

    Widget result = MouseRegion(
      cursor: (widget.onTap != null) ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && !_isPressed ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: r,
              boxShadow: boxShadow,
            ),
            child: ClipRRect(
              borderRadius: r,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                child: cardContent,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip!,
        child: result,
      );
    }

    return result;
  }
}
