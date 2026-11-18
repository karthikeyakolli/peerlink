import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/ephemeral_burner_share_service.dart';

class BurnerViewerModal extends StatefulWidget {
  final BurnerToken token;

  const BurnerViewerModal({
    super.key,
    required this.token,
  });

  static Future<void> show(BuildContext context, {required BurnerToken token}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BurnerViewerModal(token: token),
    );
  }

  @override
  State<BurnerViewerModal> createState() => _BurnerViewerModalState();
}

class _BurnerViewerModalState extends State<BurnerViewerModal> {
  final EphemeralBurnerShareService _service = EphemeralBurnerShareService.instance;
  final TextEditingController _pinController = TextEditingController();

  bool _isUnlocked = false;
  String? _errorMessage;
  BurnerAccessResult? _accessResult;

  @override
  void initState() {
    super.initState();
    if (widget.token.pin == null) {
      _tryUnlock();
    }
  }

  void _tryUnlock() {
    final res = _service.accessBurnerShare(
      widget.token.id,
      pin: _pinController.text.trim(),
    );

    if (res.isAuthorized) {
      setState(() {
        _isUnlocked = true;
        _accessResult = res;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = res.errorMessage;
      });
    }
  }

  void _closeAndBurn() {
    _service.revokeBurnerShare(widget.token.id);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Self-Destruct Warning Header
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 20, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'One-Time Burner View • Wipes permanently on close',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isUnlocked) ...[
              Text(
                'Enter 4-Digit Security PIN',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'This file is locked with a one-time PIN by the sender.',
                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('burner_pin_input'),
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  errorText: _errorMessage,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _tryUnlock(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('unlock_burner_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _tryUnlock,
                child: const Text('Unlock & Decrypt to Memory', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _accessResult?.fileName ?? widget.token.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _renderSafePreview(_accessResult?.fileBytes ?? []),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('close_and_burn_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Close & Destroy Cache', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _closeAndBurn,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _renderSafePreview(List<int> bytes) {
    if (bytes.isEmpty) return '[Empty File]';
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // Return Hex dump preview
      final hex = bytes.take(128).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      return 'Binary Data (${bytes.length} bytes):\n$hex';
    }
  }
}
