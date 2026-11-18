import 'package:flutter/material.dart';

/// Minimalist Light-Only Send & Receive bilateral hero widget.
/// Flat white cards with crisp 1px borders, essential restrained accents,
/// zero gradients, zero dark backgrounds, and zero drop shadows/glow.
class SendReceiveHero extends StatelessWidget {
  final VoidCallback onSendPressed;
  final VoidCallback onReceivePressed;
  final int discoveredPeersCount;
  final bool isNodeOnline;

  const SendReceiveHero({
    super.key,
    required this.onSendPressed,
    required this.onReceivePressed,
    this.discoveredPeersCount = 0,
    this.isNodeOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // SEND HERO CARD (Flat Light Surface)
            Expanded(
              child: _HeroActionButton(
                title: 'Send',
                subtitle: 'Send files, photos & apps',
                actionTag: discoveredPeersCount > 0
                    ? '$discoveredPeersCount nearby'
                    : 'Tap to select',
                icon: Icons.arrow_upward_rounded,
                accentColor: const Color(0xFF2563EB),
                accentTint: const Color(0xFFEFF6FF),
                onTap: onSendPressed,
              ),
            ),
            const SizedBox(width: 12),
            // RECEIVE HERO CARD (Flat Light Surface)
            Expanded(
              child: _HeroActionButton(
                title: 'Receive',
                subtitle: 'Wait for incoming files',
                actionTag: isNodeOnline ? 'Radar active' : 'Connecting...',
                icon: Icons.arrow_downward_rounded,
                accentColor: const Color(0xFF15803D),
                accentTint: const Color(0xFFF0FDF4),
                onTap: onReceivePressed,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionTag;
  final IconData icon;
  final Color accentColor;
  final Color accentTint;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.title,
    required this.subtitle,
    required this.actionTag,
    required this.icon,
    required this.accentColor,
    required this.accentTint,
    required this.onTap,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTapDown: (_) => _animController.forward(),
            onTapUp: (_) => _animController.reverse(),
            onTapCancel: () => _animController.reverse(),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: widget.accentTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.actionTag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
