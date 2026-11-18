import 'package:flutter/material.dart';

/// Structured, user-friendly interpretation of any raw error message or exception.
class SimplifiedError {
  /// Short human-readable title (e.g. "Device Not Paired")
  final String title;

  /// Clear, simple one-line explanation of what went wrong.
  final String oneLineMessage;

  /// Concrete, actionable suggestion to fix or recover from the issue.
  final String suggestedAction;

  /// Contextual icon for dialogs and banners.
  final IconData icon;

  /// Accent color for icons and badges.
  final Color iconColor;

  /// Whether the operation is safe to retry immediately.
  final bool isRetryable;

  /// Whether opening device pairing is the recommended recovery action.
  final bool canPair;

  /// Whether switching to direct hotspot is a viable recovery action.
  final bool canHotspotFallback;

  /// Raw technical diagnostic details (exception class, stack frame, transaction ID)
  final String? technicalDetails;

  const SimplifiedError({
    required this.title,
    required this.oneLineMessage,
    required this.suggestedAction,
    this.icon = Icons.error_outline_rounded,
    this.iconColor = Colors.redAccent,
    this.isRetryable = false,
    this.canPair = false,
    this.canHotspotFallback = false,
    this.technicalDetails,
  });
}

/// Translates raw technical errors, Java exceptions, protocol codes, and JSON tokens
/// into simple, actionable one-line explanations for users.
class ErrorMessageSimplifier {
  ErrorMessageSimplifier._();

  /// Simplifies any raw error string into a human-friendly [SimplifiedError].
  static SimplifiedError simplify(
    String? rawError, {
    String? transferId,
    String? targetPeer,
  }) {
    final raw = (rawError ?? '').trim();
    final lower = raw.toLowerCase();

    // 1. Detect Unauthorized / Mutual Trust failures
    // e.g. "Handshake rejected [ERROR_CODE_UNAUTHORIZED]", "not trusted", "Device Not Trusted"
    if (lower.contains('unauthorized') ||
        lower.contains('error_code_unauthorized') ||
        lower.contains('not trusted') ||
        lower.contains('untrusted') ||
        lower.contains('trustlevel') ||
        lower.contains('trust_level') ||
        lower.contains('unknown peer') ||
        lower.contains('unauthenticated')) {
      return SimplifiedError(
        title: 'Device Not Paired',
        oneLineMessage: 'The remote device has not paired with you yet.',
        suggestedAction:
            'Pair both devices first by scanning the QR code in the Devices tab.',
        icon: Icons.phonelink_lock_rounded,
        iconColor: Colors.orangeAccent,
        canPair: true,
        isRetryable: false,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 2. Detect unparsed JSON payload passed as peer ID
    if (raw.contains('{"v":') ||
        (targetPeer != null && targetPeer.contains('{"v":'))) {
      return SimplifiedError(
        title: 'Invalid Peer Token',
        oneLineMessage: 'Unrecognized pairing token format.',
        suggestedAction:
            'Scan the QR code directly or enter the clean Device ID.',
        icon: Icons.qr_code_scanner_rounded,
        iconColor: Colors.orangeAccent,
        canPair: true,
        isRetryable: false,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 3. Detect Route / Network Unreachable
    // e.g. "has no reachable discovered routes or active sessions", "ehostunreach"
    if (lower.contains('no reachable') ||
        lower.contains('no active sessions') ||
        lower.contains('unreachable') ||
        lower.contains('ehostunreach') ||
        lower.contains('route not found') ||
        lower.contains('noroute')) {
      return SimplifiedError(
        title: 'Device Unreachable',
        oneLineMessage: 'Cannot reach the other device over your local Wi-Fi.',
        suggestedAction:
            'Ensure both devices are on the same Wi-Fi, or switch to Direct Hotspot.',
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.redAccent,
        canPair: true,
        canHotspotFallback: true,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 4. Detect Connection Refused / App Not Running
    // e.g. "Connection refused", "econnrefused"
    if (lower.contains('connection refused') ||
        lower.contains('econnrefused') ||
        lower.contains('port closed') ||
        lower.contains('failed to connect')) {
      return SimplifiedError(
        title: 'PeerLink Not Open',
        oneLineMessage:
            'PeerLink is not open or running on the other device.',
        suggestedAction:
            'Launch PeerLink on the destination device and keep its screen awake.',
        icon: Icons.mobile_off_rounded,
        iconColor: Colors.amber.shade700,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 5. Detect Timeout
    // e.g. "timed out", "timeout", "etimedout"
    if (lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('etimedout')) {
      return SimplifiedError(
        title: 'Connection Timed Out',
        oneLineMessage: 'The remote device took too long to respond.',
        suggestedAction:
            'Check your Wi-Fi signal strength, or use Direct Hotspot to connect directly.',
        icon: Icons.timer_off_rounded,
        iconColor: Colors.orangeAccent,
        canHotspotFallback: true,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 6. Detect Transfer Declined by User
    // e.g. "declined by user", "transfer rejected by user", "declined"
    if (lower.contains('declined') ||
        lower.contains('rejected by user') ||
        lower.contains('user declined') ||
        lower.contains('transfer declined')) {
      return SimplifiedError(
        title: 'Transfer Declined',
        oneLineMessage:
            'The transfer was declined on the receiving device.',
        suggestedAction:
            'Ask the recipient to tap "Accept" on their screen when prompted.',
        icon: Icons.cancel_outlined,
        iconColor: Colors.redAccent,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 7. Detect Storage Full
    if (lower.contains('enospc') ||
        lower.contains('storage') ||
        lower.contains('space') ||
        lower.contains('disk full')) {
      return SimplifiedError(
        title: 'Insufficient Storage',
        oneLineMessage:
            'Not enough free storage space on the destination device.',
        suggestedAction:
            'Free up storage space on the receiving device and retry.',
        icon: Icons.disc_full_rounded,
        iconColor: Colors.redAccent,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 8. Detect Malware / Quarantine
    if (lower.contains('quarantine') ||
        lower.contains('malware') ||
        lower.contains('infected') ||
        lower.contains('security_verdict')) {
      return SimplifiedError(
        title: 'Blocked for Safety',
        oneLineMessage:
            'Transfer blocked because the file failed safety scanning.',
        suggestedAction:
            'Inspect quarantine details in the Activity tab to review findings.',
        icon: Icons.shield_rounded,
        iconColor: Colors.redAccent,
        isRetryable: false,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 9. Detect User Cancellation
    if (lower.contains('cancelled') || lower.contains('canceled')) {
      return SimplifiedError(
        title: 'Transfer Cancelled',
        oneLineMessage: 'The transfer was cancelled.',
        suggestedAction: 'Tap Retry to start this transfer again.',
        icon: Icons.stop_circle_outlined,
        iconColor: Colors.grey,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 10. Detect Local File / Permission issues
    if (lower.contains('permission denied') ||
        lower.contains('access is denied') ||
        lower.contains('eacces') ||
        lower.contains('enoent') ||
        lower.contains('not found')) {
      return SimplifiedError(
        title: 'File Access Error',
        oneLineMessage: 'Could not access or read the selected file.',
        suggestedAction:
            'Verify file permissions and make sure the file was not moved or deleted.',
        icon: Icons.folder_off_rounded,
        iconColor: Colors.redAccent,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 11. Detect Connection Severed / Pipe Broken
    if (lower.contains('broken pipe') ||
        lower.contains('connection reset') ||
        lower.contains('econnreset') ||
        lower.contains('closed by remote host')) {
      return SimplifiedError(
        title: 'Connection Lost',
        oneLineMessage: 'The Wi-Fi connection dropped during transfer.',
        suggestedAction:
            'Check your Wi-Fi connection and tap Retry to resume.',
        icon: Icons.signal_wifi_bad_rounded,
        iconColor: Colors.orangeAccent,
        isRetryable: true,
        technicalDetails: _buildTechDetails(raw, transferId),
      );
    }

    // 12. Fallback: Clean up Java exception formatting
    final cleanMessage = _cleanRawException(raw);
    return SimplifiedError(
      title: 'Transfer Interrupted',
      oneLineMessage: cleanMessage.isNotEmpty
          ? cleanMessage
          : 'The transfer could not be completed.',
      suggestedAction:
          'Ensure both devices are on the same network and try again.',
      icon: Icons.error_outline_rounded,
      iconColor: Colors.redAccent,
      isRetryable: true,
      technicalDetails: _buildTechDetails(raw, transferId),
    );
  }

  /// Strips Java exception class prefixes, error codes, and technical wrappers.
  static String _cleanRawException(String raw) {
    var s = raw;
    // Strip "java.io.IOException: " or similar
    s = s.replaceAll(RegExp(r'^[a-zA-Z0-9_.]+(Exception|Error):\s*'), '');
    // Strip redundant "Transfer tx_... failed: "
    s = s.replaceAll(RegExp(r'^Transfer\s+tx_[a-zA-Z0-9]+\s+failed:\s*', caseSensitive: false), '');
    // Strip trailing "(ID: tx_...)"
    s = s.replaceAll(RegExp(r'\(ID:\s*tx_[a-zA-Z0-9]+\)'), '').trim();
    // Strip error code brackets like "[ERROR_CODE_UNAUTHORIZED]"
    s = s.replaceAll(RegExp(r'\[ERROR_CODE_[A-Z0-9_]+\]'), '').trim();
    // Collapse excess whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return 'An unexpected network error occurred.';
    // Capitalize first letter
    return s[0].toUpperCase() + s.substring(1);
  }

  static String? _buildTechDetails(String raw, String? transferId) {
    if (raw.isEmpty && (transferId == null || transferId.isEmpty)) return null;
    final sb = StringBuffer();
    if (raw.isNotEmpty) sb.writeln(raw);
    if (transferId != null && transferId.isNotEmpty) {
      sb.write('Transfer ID: $transferId');
    }
    return sb.toString().trim();
  }
}
