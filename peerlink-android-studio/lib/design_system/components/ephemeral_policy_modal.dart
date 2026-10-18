import 'package:flutter/material.dart';
import 'glass_container.dart';
import 'interactive_glass_card.dart';

/// Policy configuration for Burn-After-Read and Ephemeral Transfers.
class EphemeralPolicy {
  final bool isEphemeral;
  final bool burnAfterRead;
  final int ttlSeconds;
  final int allowedViews;
  final String watermark;

  const EphemeralPolicy({
    this.isEphemeral = false,
    this.burnAfterRead = false,
    this.ttlSeconds = 0,
    this.allowedViews = 1,
    this.watermark = 'CONFIDENTIAL',
  });

  static const permanent = EphemeralPolicy(
    isEphemeral: false,
    burnAfterRead: false,
    ttlSeconds: 0,
    allowedViews: 999999,
    watermark: '',
  );

  static const singleView = EphemeralPolicy(
    isEphemeral: true,
    burnAfterRead: true,
    ttlSeconds: 0,
    allowedViews: 1,
    watermark: 'CONFIDENTIAL • 1-VIEW BURN',
  );

  static const fiveMinutes = EphemeralPolicy(
    isEphemeral: true,
    burnAfterRead: true,
    ttlSeconds: 300,
    allowedViews: 1,
    watermark: 'CONFIDENTIAL • 5-MIN TTL',
  );

  static const oneHour = EphemeralPolicy(
    isEphemeral: true,
    burnAfterRead: true,
    ttlSeconds: 3600,
    allowedViews: 1,
    watermark: 'CONFIDENTIAL • 1-HR TTL',
  );
}

/// Frosted Glass Modal for configuring Ephemeral / Burn-After-Read parameters.
class EphemeralPolicyModal extends StatefulWidget {
  final EphemeralPolicy initialPolicy;

  const EphemeralPolicyModal({
    super.key,
    this.initialPolicy = EphemeralPolicy.singleView,
  });

  static Future<EphemeralPolicy?> show(
    BuildContext context, {
    EphemeralPolicy initialPolicy = EphemeralPolicy.singleView,
  }) {
    return showModalBottomSheet<EphemeralPolicy>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EphemeralPolicyModal(initialPolicy: initialPolicy),
    );
  }

  @override
  State<EphemeralPolicyModal> createState() => _EphemeralPolicyModalState();
}

class _EphemeralPolicyModalState extends State<EphemeralPolicyModal> {
  late int _selectedPreset; // 0: 1-View, 1: 5m, 2: 1h, 3: Permanent
  late TextEditingController _watermarkCtrl;

  @override
  void initState() {
    super.initState();
    if (!widget.initialPolicy.isEphemeral) {
      _selectedPreset = 3;
    } else if (widget.initialPolicy.ttlSeconds == 300) {
      _selectedPreset = 1;
    } else if (widget.initialPolicy.ttlSeconds == 3600) {
      _selectedPreset = 2;
    } else {
      _selectedPreset = 0;
    }
    _watermarkCtrl = TextEditingController(
      text: widget.initialPolicy.watermark.isNotEmpty
          ? widget.initialPolicy.watermark
          : 'CONFIDENTIAL • ZERO-TRUST EPHEMERAL',
    );
  }

  @override
  void dispose() {
    _watermarkCtrl.dispose();
    super.dispose();
  }

  EphemeralPolicy _buildPolicy() {
    switch (_selectedPreset) {
      case 0:
        return EphemeralPolicy(
          isEphemeral: true,
          burnAfterRead: true,
          ttlSeconds: 0,
          allowedViews: 1,
          watermark: _watermarkCtrl.text.trim(),
        );
      case 1:
        return EphemeralPolicy(
          isEphemeral: true,
          burnAfterRead: true,
          ttlSeconds: 300,
          allowedViews: 1,
          watermark: _watermarkCtrl.text.trim(),
        );
      case 2:
        return EphemeralPolicy(
          isEphemeral: true,
          burnAfterRead: true,
          ttlSeconds: 3600,
          allowedViews: 1,
          watermark: _watermarkCtrl.text.trim(),
        );
      default:
        return EphemeralPolicy.permanent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFEF4444),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Burn-After-Read & Ephemeral Beam',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Self-destructing file transfer with cryptographic wipe',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Info banner
          GlassContainer(
            borderRadius: BorderRadius.circular(14),
            blur: 10,
            customBorder: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'When triggered, the recipient disk sectors are overwritten 3 times with CSPRNG noise, bitwise complements, and unlinked immediately.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'SELF-DESTRUCT POLICY',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(height: 10),

          // Policy options
          _buildPolicyTile(
            index: 0,
            icon: Icons.visibility_off,
            title: '1-View Auto-Burn (Recommended)',
            subtitle: 'Wipes file from recipient disk the second the viewer closes',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 8),
          _buildPolicyTile(
            index: 1,
            icon: Icons.timer,
            title: '5-Minute Auto-Burn',
            subtitle: 'Auto-shreds exactly 300 seconds after receipt',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 8),
          _buildPolicyTile(
            index: 2,
            icon: Icons.hourglass_top,
            title: '1-Hour Auto-Burn',
            subtitle: 'Auto-shreds after 60 minutes TTL expires',
            color: const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 8),
          _buildPolicyTile(
            index: 3,
            icon: Icons.save_alt,
            title: 'Permanent Transfer',
            subtitle: 'Normal zero-trust file transfer (no auto-wipe)',
            color: const Color(0xFF10B981),
          ),

          const SizedBox(height: 16),

          // Watermark field
          if (_selectedPreset != 3) ...[
            const Text(
              'VIEWER WATERMARK STAMP',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _watermarkCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                prefixIcon: const Icon(Icons.water_drop, color: Color(0xFFF59E0B), size: 18),
                hintText: 'Watermark tag (e.g. CONFIDENTIAL)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Confirm button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, _buildPolicy());
            },
            icon: Icon(
              _selectedPreset == 3 ? Icons.check_circle : Icons.local_fire_department,
              size: 18,
            ),
            label: Text(
              _selectedPreset == 3
                  ? 'Use Permanent Mode'
                  : 'Apply Ephemeral Burn Policy',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPreset == 3
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPolicyTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedPreset == index;
    return InteractiveGlassCard(
      onTap: () => setState(() => _selectedPreset = index),
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isSelected: isSelected,
      glowColor: color,
      customBgColor: isSelected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.03),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, color: color, size: 20)
          else
            Icon(Icons.circle_outlined, color: Colors.white.withOpacity(0.2), size: 20),
        ],
      ),
    );
  }
}
