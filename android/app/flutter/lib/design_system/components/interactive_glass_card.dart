import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Minimalist Interactive Card for PeerLink.
/// Modern clean elevation, crisp subtle 1px border for clear block differentiation,
/// tactile scale animation, and complete elimination of neon/glowing drop shadows.
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
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<InteractiveGlassCard> createState() => _InteractiveGlassCardState();
}

class _InteractiveGlassCardState extends State<InteractiveGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final r = widget.borderRadius ?? BorderRadius.circular(14);

    // Pure minimalist Light Mode interactive surface — flat white, neutral border, zero glow
    final defaultBg = _isHovered ? const Color(0xFFF8FAFC) : Colors.white;

    final borderColor = widget.isSelected
        ? theme.colorScheme.primary
        : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB));

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.customBgColor ?? defaultBg,
        borderRadius: r,
        border: Border.all(
          color: borderColor,
          width: widget.isSelected ? 1.5 : 1.0,
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
              .withValues(alpha: 0.08),
          highlightColor: (widget.glowColor ?? theme.colorScheme.primary)
              .withValues(alpha: 0.04),
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

    return Container(
      margin: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: cardContent,
        ),
      ),
    );
  }
}
