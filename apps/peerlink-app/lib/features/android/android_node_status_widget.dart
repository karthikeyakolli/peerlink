import 'package:flutter/material.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';

class AndroidNodeStatusWidget extends StatefulWidget {
  const AndroidNodeStatusWidget({super.key});

  @override
  State<AndroidNodeStatusWidget> createState() => _AndroidNodeStatusWidgetState();
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

    return Container(
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
        ],
      ),
    );
  }
}
