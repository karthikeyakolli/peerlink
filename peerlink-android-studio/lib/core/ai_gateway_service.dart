import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'app_settings_service.dart';
import 'operation_journal_service.dart';

enum AiProposalType {
  naturalLanguageSearch,
  smartShare,
  smartBundle,
  transferRecipe,
  compatibilityExplanation,
  diagnosticsExplanation,
  syncExplanation,
  organizationSuggestion,
  unauthorizedAction,
}

enum PrivacyLevel {
  normal,
  sensitive,
  highlySensitive,
}

enum AiRole {
  user,
  model,
  system,
}

enum PolicyStatus {
  allowed,
  requiresConfirmation,
  securityViolation,
}

class PolicyValidationResult {
  final PolicyStatus status;
  final String reason;

  const PolicyValidationResult._(this.status, this.reason);

  factory PolicyValidationResult.allowed([String reason = 'Operation allowed']) =>
      PolicyValidationResult._(PolicyStatus.allowed, reason);

  factory PolicyValidationResult.requiresConfirmation(String reason) =>
      PolicyValidationResult._(PolicyStatus.requiresConfirmation, reason);

  factory PolicyValidationResult.violation(String reason) =>
      PolicyValidationResult._(PolicyStatus.securityViolation, reason);

  bool get isAllowed => status == PolicyStatus.allowed;
  bool get requiresUserConfirmation => status == PolicyStatus.requiresConfirmation;
  bool get isViolation => status == PolicyStatus.securityViolation;
}

class AiProposal {
  final String id;
  final AiProposalType type;
  final String naturalLanguageQuery;
  final String justification;
  final OperationType? mappedIntent;
  final List<String> targetPaths;
  final Map<String, String> expectedHashes;
  final String? targetPeerId;
  final Map<String, dynamic> parameters;
  final bool requiresUserConfirmation;
  final DateTime createdAt;

  AiProposal({
    required this.id,
    required this.type,
    required this.naturalLanguageQuery,
    required this.justification,
    this.mappedIntent,
    this.targetPaths = const [],
    this.expectedHashes = const {},
    this.targetPeerId,
    this.parameters = const {},
    required this.requiresUserConfirmation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AiAuditRecord {
  final String auditId;
  final String proposalId;
  final AiProposalType proposalType;
  final String outcome;
  final String details;
  final DateTime timestamp;

  AiAuditRecord({
    required this.auditId,
    required this.proposalId,
    required this.proposalType,
    required this.outcome,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class PromptInjectionGuard {
  static final RegExp _injectionPattern = RegExp(
    r'(ignore\s+(all\s+)?previous\s+instructions'
    r'|disregard\s+prior\s+rules'
    r'|you\s+are\s+now\s+(in\s+developer\s+mode|root|admin|unrestricted)'
    r'|override\s+system\s+prompt'
    r'|system\s+override'
    r'|execute\s+(command|shell|terminal|bash|powershell|cmd|binary)'
    r'|grant\s+(trust|admin|root|access|permission)'
    r'|authorize\s+peer'
    r'|bypass\s+(safety|security|policy|guardrails|confirmation)'
    r'|disable\s+scanner'
    r'|delete\s+(all\s+)?files'
    r'|rm\s+-rf'
    r'|del\s+/f\s+/s'
    r'|format\s+[a-z]:)',
    caseSensitive: false,
  );

  static bool containsInjectionPattern(String? text) {
    if (text == null || text.isEmpty) return false;
    return _injectionPattern.hasMatch(text);
  }

  static String wrapUntrustedInput(String input, String sourceTag) {
    final sanitized = input
        .replaceAll('<untrusted_input', '&lt;untrusted_input')
        .replaceAll('</untrusted_input>', '&lt;/untrusted_input&gt;');
    return '<untrusted_input source="$sourceTag">\n$sanitized\n</untrusted_input>';
  }
}

class SanitizedContextFilter {
  static final RegExp _authTokenPattern = RegExp(
    r'(bearer\s+[a-zA-Z0-9_\-\.]+|token[:=]\s*[a-zA-Z0-9_\-\.]+|key[:=]\s*[a-zA-Z0-9_\-\.]+)',
    caseSensitive: false,
  );
  static final RegExp _privateKeyPattern = RegExp(
    r'(-----BEGIN [A-Z ]+PRIVATE KEY-----|[a-f0-9]{64}|ed25519:[a-zA-Z0-9+/=]{32,})',
    caseSensitive: false,
  );
  static final RegExp _sensitivePathPattern = RegExp(
    r'([a-zA-Z]:\\users\\[^\\]+|/home/[^/]+)',
    caseSensitive: false,
  );
  static final RegExp _filenamePattern = RegExp(
    r'\b[a-zA-Z0-9_\-\.]+\.(pdf|docx|txt|jpg|png|zip|tar|gz|json|xml|csv|bin|exe|msi|apk)\b',
    caseSensitive: false,
  );
  static final RegExp _peerIdPattern = RegExp(r'\bpeer_[a-zA-Z0-9_\-]+\b', caseSensitive: false);

  static bool containsForbiddenSecrets(String? text) {
    if (text == null || text.isEmpty) return false;
    return _authTokenPattern.hasMatch(text) || _privateKeyPattern.hasMatch(text);
  }

  static String sanitizeString(String text, {bool allowSensitiveDisclosure = false}) {
    var sanitized = text;
    sanitized = sanitized.replaceAll(_privateKeyPattern, '[REDACTED_CRYPTO_KEY]');
    sanitized = sanitized.replaceAll(_authTokenPattern, '[REDACTED_AUTH_TOKEN]');

    if (!allowSensitiveDisclosure) {
      sanitized = sanitized.replaceAll(_filenamePattern, '[REDACTED_FILENAME]');
      sanitized = sanitized.replaceAll(_peerIdPattern, '[REDACTED_PEER_ID]');
      sanitized = sanitized.replaceAll(_sensitivePathPattern, '[REDACTED_USER_PATH]');
    } else {
      sanitized = sanitized.replaceAll(_sensitivePathPattern, '[REDACTED_USER_PATH]');
    }

    return sanitized;
  }
}

class DeterministicAiPolicyEngine {
  static const int maxQueryLength = 4096;
  static const int maxJustificationLength = 4096;
  static const int maxTargetObjects = 100;
  static const int maxShareDurationSeconds = 86400; // 24 hours

  static const Set<String> forbiddenDirectives = {
    'delete_files',
    'delete_file',
    'delete_all',
    'rm',
    'unlink',
    'drop_table',
    'revoke_device',
    'modify_trust',
    'grant_trust',
    'authorize_peer',
    'disable_scanner',
    'execute_command',
    'system_call',
    'execute_binary',
    'export_private_key',
    'exec',
    'shell',
    'bash',
    'powershell',
    'cmd',
    'format',
    'mass_deletion',
    'bypass_safeguards',
    'bypass_safety',
  };

  static final RegExp _pathTraversalPattern = RegExp(
    r'(\.\./|\.\.\\|/etc/|/root/|[a-zA-Z]:\\windows|[a-zA-Z]:\\program\s+files)',
    caseSensitive: false,
  );

  PolicyValidationResult evaluate(AiProposal proposal) {
    if (proposal.type == AiProposalType.unauthorizedAction) {
      return PolicyValidationResult.violation('AI attempted an unauthorized action category');
    }

    if (proposal.naturalLanguageQuery.length > maxQueryLength) {
      return PolicyValidationResult.violation('Query exceeds safety limit of $maxQueryLength chars');
    }

    if (proposal.justification.length > maxJustificationLength) {
      return PolicyValidationResult.violation('Justification exceeds safety limit of $maxJustificationLength chars');
    }

    if (proposal.targetPaths.length > maxTargetObjects) {
      return PolicyValidationResult.violation('Target objects count exceeds safety limit of $maxTargetObjects');
    }

    if (PromptInjectionGuard.containsInjectionPattern(proposal.naturalLanguageQuery) ||
        PromptInjectionGuard.containsInjectionPattern(proposal.justification)) {
      return PolicyValidationResult.violation('Adversarial prompt injection pattern detected');
    }

    if (SanitizedContextFilter.containsForbiddenSecrets(proposal.naturalLanguageQuery) ||
        SanitizedContextFilter.containsForbiddenSecrets(proposal.justification)) {
      return PolicyValidationResult.violation('Proposal parameters contain private cryptographic secrets or tokens');
    }

    for (final entry in proposal.parameters.entries) {
      final key = entry.key.toLowerCase();
      if (forbiddenDirectives.contains(key)) {
        return PolicyValidationResult.violation('Proposal includes prohibited control directive: $key');
      }

      if (entry.value is String) {
        final val = (entry.value as String).toLowerCase();
        for (final forbidden in forbiddenDirectives) {
          if (val == forbidden || val.contains(forbidden)) {
            return PolicyValidationResult.violation('Proposal parameter value contains prohibited directive: $forbidden');
          }
        }
        if (_pathTraversalPattern.hasMatch(entry.value as String)) {
          return PolicyValidationResult.violation('Proposal parameter contains unauthorized path traversal');
        }
      }
    }

    switch (proposal.type) {
      case AiProposalType.naturalLanguageSearch:
      case AiProposalType.compatibilityExplanation:
      case AiProposalType.diagnosticsExplanation:
      case AiProposalType.syncExplanation:
        return PolicyValidationResult.allowed('Read-only query/explanation permitted without mutation');

      case AiProposalType.smartShare:
        if (!proposal.requiresUserConfirmation) {
          return PolicyValidationResult.violation('Smart Share proposal cannot bypass mandatory user confirmation');
        }
        if (proposal.targetPeerId == null || proposal.targetPeerId!.trim().isEmpty) {
          return PolicyValidationResult.violation('Smart Share proposal missing targetPeerId');
        }
        final dur = proposal.parameters['durationSeconds'];
        if (dur is int && (dur <= 0 || dur > maxShareDurationSeconds)) {
          return PolicyValidationResult.violation('Smart Share duration out of valid bounds (1 - $maxShareDurationSeconds seconds)');
        }
        return PolicyValidationResult.requiresConfirmation('Smart Share grants external access and requires explicit user tap');

      case AiProposalType.smartBundle:
      case AiProposalType.transferRecipe:
      case AiProposalType.organizationSuggestion:
        if (!proposal.requiresUserConfirmation) {
          return PolicyValidationResult.violation('Proposal cannot bypass mandatory user confirmation');
        }
        return PolicyValidationResult.requiresConfirmation('Batch/transfer operation requires explicit user tap');

      default:
        return PolicyValidationResult.violation('Unsupported AI proposal category');
    }
  }
}

class AiGatewayService {
  AiGatewayService._();
  static final AiGatewayService instance = AiGatewayService._();

  final DeterministicAiPolicyEngine policyEngine = DeterministicAiPolicyEngine();
  final List<AiAuditRecord> _auditTrail = [];
  final StreamController<List<AiAuditRecord>> _auditStreamController = StreamController<List<AiAuditRecord>>.broadcast();

  Stream<List<AiAuditRecord>> get auditStream => _auditStreamController.stream;
  List<AiAuditRecord> get auditTrail => List.unmodifiable(_auditTrail);

  void recordAudit({
    required String proposalId,
    required AiProposalType proposalType,
    required String outcome,
    required String details,
  }) {
    final record = AiAuditRecord(
      auditId: 'audit_${DateTime.now().millisecondsSinceEpoch}_${_auditTrail.length}',
      proposalId: proposalId,
      proposalType: proposalType,
      outcome: outcome,
      details: details,
    );
    _auditTrail.add(record);
    if (_auditStreamController.hasListener) {
      _auditStreamController.add(List.unmodifiable(_auditTrail));
    }
  }

  void resetForTesting() {
    _auditTrail.clear();
  }

  /// Evaluates an input query deterministically and builds an AiProposal.
  /// Works completely offline without requiring any external LLM connection.
  AiProposal formulateProposal(String rawQuery) {
    final query = rawQuery.trim();

    // 1. Check prompt injection
    if (PromptInjectionGuard.containsInjectionPattern(query)) {
      final prop = AiProposal(
        id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        type: AiProposalType.unauthorizedAction,
        naturalLanguageQuery: query,
        justification: 'Rejected by PromptInjectionGuard due to detected adversarial override patterns',
        requiresUserConfirmation: true,
      );
      recordAudit(
        proposalId: prop.id,
        proposalType: prop.type,
        outcome: 'REJECTED_SECURITY_VIOLATION',
        details: 'Adversarial pattern: $query',
      );
      return prop;
    }

    final lower = query.toLowerCase();

    // 2. Check forbidden actions
    for (final forbidden in DeterministicAiPolicyEngine.forbiddenDirectives) {
      if (lower.contains(forbidden)) {
        final prop = AiProposal(
          id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
          type: AiProposalType.unauthorizedAction,
          naturalLanguageQuery: query,
          justification: 'Forbidden directive detected: $forbidden',
          parameters: {forbidden: true},
          requiresUserConfirmation: true,
        );
        recordAudit(
          proposalId: prop.id,
          proposalType: prop.type,
          outcome: 'REJECTED_FORBIDDEN_DIRECTIVE',
          details: 'Directives: $forbidden',
        );
        return prop;
      }
    }

    // 3. Propose Smart Share
    if (lower.startsWith('share') || lower.contains('send to') || lower.contains('beam to')) {
      String peerId = 'peer_discovered';
      if (lower.contains('phone')) peerId = 'peer_phone';
      if (lower.contains('laptop')) peerId = 'peer_laptop';
      if (lower.contains('desktop')) peerId = 'peer_desktop';

      final prop = AiProposal(
        id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        type: AiProposalType.smartShare,
        naturalLanguageQuery: query,
        justification: 'Proposed sharing requested files with trusted device "$peerId". Requires user confirmation.',
        mappedIntent: OperationType.send,
        targetPeerId: peerId,
        parameters: {'durationSeconds': 3600},
        requiresUserConfirmation: true,
      );
      recordAudit(
        proposalId: prop.id,
        proposalType: prop.type,
        outcome: 'PROPOSAL_GENERATED',
        details: 'Target: $peerId',
      );
      return prop;
    }

    // 4. Propose Smart Bundle
    if (lower.contains('bundle') || lower.contains('project files') || lower.contains('archive')) {
      final prop = AiProposal(
        id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        type: AiProposalType.smartBundle,
        naturalLanguageQuery: query,
        justification: 'Bundle project documents together for grouped transfer. Requires user confirmation.',
        mappedIntent: OperationType.send,
        parameters: {'bundleName': 'Smart_Bundle_${DateTime.now().millisecondsSinceEpoch}'},
        requiresUserConfirmation: true,
      );
      recordAudit(
        proposalId: prop.id,
        proposalType: prop.type,
        outcome: 'PROPOSAL_GENERATED',
        details: 'Bundle proposal',
      );
      return prop;
    }

    // 5. Propose Diagnostic or Sync Explanation
    if (lower.contains('why') || lower.contains('diagnose') || lower.contains('status') || lower.contains('error')) {
      final prop = AiProposal(
        id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        type: AiProposalType.diagnosticsExplanation,
        naturalLanguageQuery: query,
        justification: 'Explaining local node health, NAT traversal routes, and sync state.',
        requiresUserConfirmation: false,
      );
      recordAudit(
        proposalId: prop.id,
        proposalType: prop.type,
        outcome: 'PROPOSAL_GENERATED',
        details: 'Diagnostics inquiry',
      );
      return prop;
    }

    // 6. Default: Natural Language Search
    final prop = AiProposal(
      id: 'prop_${DateTime.now().millisecondsSinceEpoch}',
      type: AiProposalType.naturalLanguageSearch,
      naturalLanguageQuery: query,
      justification: 'Read-only search across local spaces and authorized peer indexes for "$query".',
      requiresUserConfirmation: false,
    );
    recordAudit(
      proposalId: prop.id,
      proposalType: prop.type,
      outcome: 'PROPOSAL_GENERATED',
      details: 'Search: $query',
    );
    return prop;
  }

  /// Executes an AI proposal strictly adhering to Rule 11.
  /// Fails immediately if the proposal requires confirmation and [userConfirmed] is false.
  Future<bool> executeProposal({
    required AiProposal proposal,
    required bool userConfirmed,
  }) async {
    final validation = policyEngine.evaluate(proposal);

    if (validation.isViolation) {
      recordAudit(
        proposalId: proposal.id,
        proposalType: proposal.type,
        outcome: 'EXECUTION_REJECTED_SECURITY_VIOLATION',
        details: validation.reason,
      );
      throw SecurityException(validation.reason);
    }

    if (validation.requiresUserConfirmation && !userConfirmed) {
      recordAudit(
        proposalId: proposal.id,
        proposalType: proposal.type,
        outcome: 'EXECUTION_BLOCKED_AWAITING_USER_TAP',
        details: 'Rule 11 enforced: User tap is required before dispatch.',
      );
      return false;
    }

    // Revalidate target files if paths were specified (Rule 7/8/11)
    for (final path in proposal.targetPaths) {
      final file = File(path);
      if (!file.existsSync()) {
        recordAudit(
          proposalId: proposal.id,
          proposalType: proposal.type,
          outcome: 'EXECUTION_FAILED_FILE_NOT_FOUND',
          details: 'File not found at path: $path',
        );
        throw PathNotFoundException(path, const OSError('File moved or deleted before confirmation', 2));
      }
    }

    recordAudit(
      proposalId: proposal.id,
      proposalType: proposal.type,
      outcome: 'EXECUTION_DISPATCHED_BY_USER_CONSENT',
      details: 'User explicitly confirmed action for proposal ${proposal.id}',
    );
    return true;
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
