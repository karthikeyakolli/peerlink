import 'package:flutter/foundation.dart';

enum PresentationCommand {
  nextSlide,
  prevSlide,
  blackScreen,
  mediaPlayPause,
  volumeUp,
  volumeDown,
  mute,
  mouseMove,
  mouseClick,
}

class RemoteCommandPacket {
  final PresentationCommand command;
  final double? dx;
  final double? dy;
  final int timestamp;

  const RemoteCommandPacket({
    required this.command,
    this.dx,
    this.dy,
    required this.timestamp,
  });
}

typedef RemoteCommandCallback = void Function(Map<String, dynamic> packet);

class RemotePresentationControllerService extends ChangeNotifier {
  RemotePresentationControllerService._();
  static final RemotePresentationControllerService instance = RemotePresentationControllerService._();

  RemoteCommandCallback? onSendCommand;

  void sendPresentationCommand(PresentationCommand command) {
    final payload = {
      'type': 'REMOTE_COMMAND',
      'command': _commandToString(command),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    onSendCommand?.call(payload);
  }

  void sendMouseMove({required double dx, required double dy}) {
    final payload = {
      'type': 'REMOTE_COMMAND',
      'command': 'MOUSE_MOVE',
      'dx': dx,
      'dy': dy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    onSendCommand?.call(payload);
  }

  void sendMouseClick({bool isRightClick = false}) {
    final payload = {
      'type': 'REMOTE_COMMAND',
      'command': isRightClick ? 'RIGHT_CLICK' : 'LEFT_CLICK',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    onSendCommand?.call(payload);
  }

  RemoteCommandPacket? parseCommand(Map<String, dynamic> packet) {
    if (packet['type'] != 'REMOTE_COMMAND') return null;
    final cmdStr = packet['command'] as String?;
    if (cmdStr == null) return null;

    final cmd = _stringToCommand(cmdStr);
    if (cmd == null) return null;

    final dx = (packet['dx'] as num?)?.toDouble();
    final dy = (packet['dy'] as num?)?.toDouble();
    final ts = (packet['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

    return RemoteCommandPacket(
      command: cmd,
      dx: dx,
      dy: dy,
      timestamp: ts,
    );
  }

  String _commandToString(PresentationCommand cmd) {
    switch (cmd) {
      case PresentationCommand.nextSlide:
        return 'NEXT_SLIDE';
      case PresentationCommand.prevSlide:
        return 'PREV_SLIDE';
      case PresentationCommand.blackScreen:
        return 'BLACK_SCREEN';
      case PresentationCommand.mediaPlayPause:
        return 'MEDIA_PLAY_PAUSE';
      case PresentationCommand.volumeUp:
        return 'VOLUME_UP';
      case PresentationCommand.volumeDown:
        return 'VOLUME_DOWN';
      case PresentationCommand.mute:
        return 'MUTE';
      case PresentationCommand.mouseMove:
        return 'MOUSE_MOVE';
      case PresentationCommand.mouseClick:
        return 'MOUSE_CLICK';
    }
  }

  PresentationCommand? _stringToCommand(String str) {
    switch (str.toUpperCase()) {
      case 'NEXT_SLIDE':
        return PresentationCommand.nextSlide;
      case 'PREV_SLIDE':
        return PresentationCommand.prevSlide;
      case 'BLACK_SCREEN':
        return PresentationCommand.blackScreen;
      case 'MEDIA_PLAY_PAUSE':
        return PresentationCommand.mediaPlayPause;
      case 'VOLUME_UP':
        return PresentationCommand.volumeUp;
      case 'VOLUME_DOWN':
        return PresentationCommand.volumeDown;
      case 'MUTE':
        return PresentationCommand.mute;
      case 'MOUSE_MOVE':
        return PresentationCommand.mouseMove;
      case 'MOUSE_CLICK':
      case 'LEFT_CLICK':
        return PresentationCommand.mouseClick;
      default:
        return null;
    }
  }
}
