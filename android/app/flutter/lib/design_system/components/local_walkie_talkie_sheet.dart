import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal sheet for P2P Local Encrypted Walkie-Talkie & Push-to-Talk (PTT) Intercom.
class LocalWalkieTalkieSheet extends StatefulWidget {
  final String peerName;

  const LocalWalkieTalkieSheet({
    super.key,
    this.peerName = 'Paired Laptop (DESKTOP-OMEN)',
  });

  static Future<void> show(BuildContext context, {String peerName = 'Paired Laptop (DESKTOP-OMEN)'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocalWalkieTalkieSheet(peerName: peerName),
    );
  }

  @override
  State<LocalWalkieTalkieSheet> createState() => _LocalWalkieTalkieSheetState();
}

class _LocalWalkieTalkieSheetState extends State<LocalWalkieTalkieSheet> {
  bool _isTalking = false;

  void _onPressDown(PointerDownEvent event) {
    HapticFeedback.heavyImpact();
    setState(() => _isTalking = true);
  }

  void _onPressUp(PointerUpEvent event) {
    HapticFeedback.mediumImpact();
    setState(() => _isTalking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.record_voice_over_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('P2P Encrypted Walkie-Talkie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('Direct LAN voice intercom with ${widget.peerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Channel Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _isTalking ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isTalking ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isTalking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isTalking ? 'BROADCASTING VOICE (PTT ACTIVE)...' : 'INTERCOM STANDBY • 16kHz PCM mTLS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isTalking ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Giant Push-to-Talk button
          Listener(
            onPointerDown: _onPressDown,
            onPointerUp: _onPressUp,
            child: Container(
              key: const Key('ptt_walkie_talkie_button'),
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: _isTalking ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isTalking ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isTalking ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 44,
                    color: _isTalking ? Colors.white : const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isTalking ? 'TALKING' : 'HOLD TO TALK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _isTalking ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Push and hold the button to broadcast voice.\nRelease to listen. 100% offline, zero internet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
