import 'package:flutter/material.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';

class AndroidNodeStatusWidget extends StatefulWidget {
  const AndroidNodeStatusWidget({super.key});

  @override
  State<AndroidNodeStatusWidget> createState() =>
      _AndroidNodeStatusWidgetState();
}

class _AndroidNodeStatusWidgetState extends State<AndroidNodeStatusWidget> {
  AndroidNodeStateEnum _currentState = AndroidNodeStateEnum.unknown;

  @override
  void initState() {
    super.initState();
    if (PlatformCapabilities.isAndroid) {
      _fetchInitialState();
      AndroidNodeBridge.instance.events.listen((event) {
        if (event['type'] == 'nodeStateChanged') {
          final newStateStr = event['newState'] as String?;
          setState(() {
            _currentState = _parseState(newStateStr);
          });
        }
      });
    }
  }

  Future<void> _fetchInitialState() async {
    final state = await AndroidNodeBridge.instance.getNodeState();
    if (mounted) {
      setState(() {
        _currentState = state;
      });
    }
  }

  AndroidNodeStateEnum _parseState(String? stateStr) {
    switch (stateStr) {
      case 'ACTIVE':
        return AndroidNodeStateEnum.active;
      case 'BACKGROUND_CAPABLE':
        return AndroidNodeStateEnum.backgroundCapable;
      case 'OS_RESTRICTED':
        return AndroidNodeStateEnum.osRestricted;
      case 'UNAVAILABLE':
        return AndroidNodeStateEnum.unavailable;
      default:
        return AndroidNodeStateEnum.unknown;
    }
  }

  void _showAndroidStateDetails(BuildContext context) {
    String stateDescription;
    String recommendation;

    switch (_currentState) {
      case AndroidNodeStateEnum.active:
        stateDescription =
            'The Android local node is running in the foreground with full network priority and real-time P2P transport.';
        recommendation =
            'All transfers and sync jobs operate at maximum throughput.';
        break;
      case AndroidNodeStateEnum.backgroundCapable:
        stateDescription =
            'Device is connected to Wi-Fi and power, or running an active foreground service notification.';
        recommendation =
            'Transfers can continue in the background with moderate resource allocation.';
        break;
      case AndroidNodeStateEnum.osRestricted:
        stateDescription =
            'Android Doze mode or aggressive battery optimization is active. Network discovery pings are throttled to 120-second intervals.';
        recommendation =
            'For uninterrupted large transfers, keep PeerLink open on your screen or plug the phone into power.';
        break;
      case AndroidNodeStateEnum.unavailable:
        stateDescription =
            'The Android node background service has terminated or was killed by the OS due to low system memory.';
        recommendation = 'Reopen PeerLink to re-initialize the local daemon.';
        break;
      case AndroidNodeStateEnum.unknown:
        stateDescription = 'Connecting to Android local node IPC service...';
        recommendation = 'Please wait while the daemon initializes.';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.android_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Android Resource Behavior'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Node State: ${_currentState.name.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(stateDescription, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recommendation:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue)),
                  const SizedBox(height: 2),
                  Text(recommendation, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Storage & Permissions:\nPeerLink utilizes Scoped Storage (`Downloads/PeerLinkReceived`) to avoid asking for dangerous system-wide storage permissions.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isAndroid) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    IconData badgeIcon;
    String label;

    switch (_currentState) {
      case AndroidNodeStateEnum.active:
        badgeColor = Colors.green;
        badgeIcon = Icons.bolt;
        label = 'Android Node: ACTIVE';
        break;
      case AndroidNodeStateEnum.backgroundCapable:
        badgeColor = Colors.blue;
        badgeIcon = Icons.battery_charging_full;
        label = 'Android Node: BACKGROUND CAPABLE';
        break;
      case AndroidNodeStateEnum.osRestricted:
        badgeColor = Colors.orange;
        badgeIcon = Icons.battery_saver;
        label = 'Android Node: OS RESTRICTED';
        break;
      case AndroidNodeStateEnum.unavailable:
        badgeColor = Colors.red;
        badgeIcon = Icons.cloud_off;
        label = 'Android Node: UNAVAILABLE';
        break;
      case AndroidNodeStateEnum.unknown:
        badgeColor = Colors.grey;
        badgeIcon = Icons.help_outline;
        label = 'Android Node: Initializing';
        break;
    }

    return InkWell(
      onTap: () => _showAndroidStateDetails(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badgeColor.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, color: badgeColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.info_outline_rounded, color: badgeColor, size: 14),
          ],
        ),
      ),
    );
  }
}
