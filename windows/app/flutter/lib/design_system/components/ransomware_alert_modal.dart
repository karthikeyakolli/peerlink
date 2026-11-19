import 'package:flutter/material.dart';
import '../../core/services/ransomware_canary_guard.dart';

/// Security warning dialog when Ransomware & Mass-Renaming Canary Guard trips.
class RansomwareAlertModal extends StatelessWidget {
  final CanaryTripEvent event;

  const RansomwareAlertModal({super.key, required this.event});

  static Future<void> show(BuildContext context, CanaryTripEvent event) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RansomwareAlertModal(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Row(
        children: [
          Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security Alert: Canary Tripped',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              'Detected ${event.operationCount} rapid file modifications in under 3s targeting: "${event.triggerPath}". Vault writes are temporarily frozen to protect user files.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Rule 11: Anti-Ransomware Invariant',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'No automated process has authority to encrypt, mass-rename, or mass-delete your vault without explicit human confirmation.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            RansomwareCanaryGuard.instance.unlockVault();
            Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Unlock Vault', style: TextStyle(color: Color(0xFF334155))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Keep Vault Locked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
