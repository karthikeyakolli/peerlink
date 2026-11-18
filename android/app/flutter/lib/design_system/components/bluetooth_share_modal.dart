import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/bluetooth_service.dart';
import '../../core/file_staging_service.dart';
import 'glass_container.dart';
import 'interactive_glass_card.dart';

/// Bottom modal sheet enabling offline Bluetooth / BLE sharing for text, links, and small files.
class BluetoothShareModal extends StatefulWidget {
  final String? initialText;

  const BluetoothShareModal({super.key, this.initialText});

  static Future<void> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: BluetoothShareModal(initialText: initialText),
      ),
    );
  }

  static void showIncomingPayload(
    BuildContext context, {
    required BluetoothPayloadRecord payload,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bluetooth_connected_rounded, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                payload.isFile ? 'Bluetooth File Received' : 'Bluetooth Text Received',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${payload.senderName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: SelectableText(
                payload.text,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload.text));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  @override
  State<BluetoothShareModal> createState() => _BluetoothShareModalState();
}

class _BluetoothShareModalState extends State<BluetoothShareModal> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedDeviceId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    }
    BluetoothService.instance.startScan();
    final devices = BluetoothService.instance.discoveredDevices;
    if (devices.isNotEmpty) {
      _selectedDeviceId = devices.first.id;
    }
  }

  @override
  void dispose() {
    BluetoothService.instance.stopScan();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text or a link to beam.')),
      );
      return;
    }
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a nearby Bluetooth device.')),
      );
      return;
    }

    setState(() => _isSending = true);
    final success = await BluetoothService.instance.sendText(
      targetDeviceId: _selectedDeviceId!,
      text: text,
    );
    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beamed successfully via Bluetooth!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Offline Beam',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Zero-network transfer for text and small files',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              StreamBuilder<bool>(
                stream: BluetoothService.instance.scanningStream,
                initialData: BluetoothService.instance.isScanning,
                builder: (context, snapshot) {
                  final isScanning = snapshot.data ?? false;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isScanning
                          ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isScanning ? 'Scanning...' : 'Ready',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isScanning ? const Color(0xFF0284C7) : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Device Selector
          StreamBuilder<List<BluetoothDeviceRecord>>(
            stream: BluetoothService.instance.nearbyDevicesStream,
            initialData: BluetoothService.instance.discoveredDevices,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? [];
              if (devices.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Searching for nearby Bluetooth peers...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return DropdownButtonFormField<String>(
                value: _selectedDeviceId != null &&
                        devices.any((d) => d.id == _selectedDeviceId)
                    ? _selectedDeviceId
                    : devices.first.id,
                decoration: InputDecoration(
                  labelText: 'Target Bluetooth Device',
                  prefixIcon: const Icon(Icons.devices_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: devices.map((d) {
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.name, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          '(${d.signalStrength})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedDeviceId = val);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Text Field
          TextField(
            controller: _textController,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter text, link, code snippet, or phone number to beam...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),

          // Staged file indicator if small file present
          if (FileStagingService.instance.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Staged: ${FileStagingService.instance.stagedFiles.first.name} (${FileStagingService.instance.formattedTotalBytes})',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isSending ? null : _handleSend,
                icon: _isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded, size: 16),
                label: Text(_isSending ? 'Beaming...' : 'Beam via Bluetooth'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
