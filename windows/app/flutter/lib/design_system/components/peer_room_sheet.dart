import 'package:flutter/material.dart';
import '../../core/peer_room_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only PeerRoom Multi-Recipient Broadcast Sheet.
/// Allows a host to create a temporary room via 4-digit PIN for classroom/meeting group drops.
class PeerRoomSheet extends StatefulWidget {
  final String? hostDeviceId;

  const PeerRoomSheet({super.key, this.hostDeviceId});

  static Future<void> show(BuildContext context, {String? hostDeviceId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PeerRoomSheet(hostDeviceId: hostDeviceId),
    );
  }

  @override
  State<PeerRoomSheet> createState() => _PeerRoomSheetState();
}

class _PeerRoomSheetState extends State<PeerRoomSheet> {
  final PeerRoomService _roomService = PeerRoomService.instance;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController(text: 'Local Meeting Room');

  PeerRoomSession? _currentSession;
  bool _isCreating = false;
  String? _statusMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _handleCreateRoom() {
    final name = _roomNameController.text.trim();
    if (name.isEmpty) return;
    final session = _roomService.createRoom(
      roomName: name,
      hostDeviceId: widget.hostDeviceId ?? 'local-host',
    );
    setState(() {
      _currentSession = session;
      _statusMessage = 'Room created! Share 4-digit PIN with nearby peers.';
    });
  }

  void _handleJoinRoom() {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _statusMessage = 'Please enter a valid 4-digit PIN.');
      return;
    }
    final session = _roomService.joinRoom(
      pin: pin,
      deviceId: 'guest-${DateTime.now().millisecondsSinceEpoch}',
      deviceName: 'Guest Device',
    );
    if (session != null) {
      setState(() {
        _currentSession = session;
        _statusMessage = 'Connected to ${session.roomName}!';
      });
    } else {
      setState(() => _statusMessage = 'Room not found. Check PIN and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.groups_rounded, size: 22, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PeerRoom Broadcast Drop',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        _currentSession != null
                            ? '${_currentSession!.roomName} • PIN: ${_currentSession!.pin}'
                            : '1-to-Many Classroom / Team Drop',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_currentSession == null) ...[
              // Choice: Host Room or Join Room
              if (!_isCreating) ...[
                ElevatedButton.icon(
                  key: const Key('peerroom_create_button'),
                  onPressed: () => setState(() => _isCreating = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Host a New PeerRoom'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PeerLinkColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('peerroom_pin_input'),
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          hintText: 'Enter 4-Digit PIN to Join',
                          counterText: '',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('peerroom_join_button'),
                      onPressed: _handleJoinRoom,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _handleCreateRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PeerLinkColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start Room & Generate PIN'),
                ),
              ],
            ] else ...[
              // Active Room View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    const Text('Room PIN', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text(
                      _currentSession!.pin,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: PeerLinkColors.primaryBlue),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connected Members: ${_currentSession!.members.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _roomService.closeRoom(_currentSession!.pin);
                  setState(() {
                    _currentSession = null;
                    _statusMessage = null;
                    _isCreating = false;
                  });
                },
                icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                label: const Text('Leave / Close Room'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PeerLinkColors.dangerRed,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
