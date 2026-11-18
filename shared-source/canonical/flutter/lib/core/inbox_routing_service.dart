import 'dart:io';
import 'received_files_service.dart';

class InboxRoutingRule {
  final String id;
  final String name;
  final ReceivedFileCategory? matchCategory;
  final String? matchExtension;
  final String? matchPeerNameContains;
  final String targetSubfolder;
  final bool enabled;

  const InboxRoutingRule({
    required this.id,
    required this.name,
    this.matchCategory,
    this.matchExtension,
    this.matchPeerNameContains,
    required this.targetSubfolder,
    this.enabled = true,
  });

  InboxRoutingRule copyWith({bool? enabled, String? targetSubfolder}) => InboxRoutingRule(
        id: id,
        name: name,
        matchCategory: matchCategory,
        matchExtension: matchExtension,
        matchPeerNameContains: matchPeerNameContains,
        targetSubfolder: targetSubfolder ?? this.targetSubfolder,
        enabled: enabled ?? this.enabled,
      );
}

class InboxRoutingAction {
  final String fileName;
  final String sourcePath;
  final String destinationPath;
  final String matchedRuleName;

  const InboxRoutingAction({
    required this.fileName,
    required this.sourcePath,
    required this.destinationPath,
    required this.matchedRuleName,
  });
}

/// Deterministic "Auto-Sort Inbox" Routing Engine.
/// Routes incoming/vault files into organized subfolders based on explicit,
/// user-defined rules (category, extension, or peer name).
/// Enforces Rule 11: 100% deterministic local rules — zero AI authority.
class InboxRoutingService {
  static final InboxRoutingService _instance = InboxRoutingService._internal();
  static InboxRoutingService get instance => _instance;

  InboxRoutingService._internal();

  final List<InboxRoutingRule> _rules = [
    const InboxRoutingRule(
      id: 'rule_photos',
      name: 'Photos -> Pictures',
      matchCategory: ReceivedFileCategory.photos,
      targetSubfolder: 'Pictures',
      enabled: true,
    ),
    const InboxRoutingRule(
      id: 'rule_videos',
      name: 'Videos -> Videos',
      matchCategory: ReceivedFileCategory.videos,
      targetSubfolder: 'Videos',
      enabled: true,
    ),
    const InboxRoutingRule(
      id: 'rule_docs',
      name: 'Documents & PDFs -> Documents',
      matchCategory: ReceivedFileCategory.documents,
      targetSubfolder: 'Documents',
      enabled: true,
    ),
    const InboxRoutingRule(
      id: 'rule_archives',
      name: 'ZIP & Archives -> Archives',
      matchCategory: ReceivedFileCategory.archives,
      targetSubfolder: 'Archives',
      enabled: false,
    ),
  ];

  List<InboxRoutingRule> get rules => List.unmodifiable(_rules);

  void toggleRule(String id, bool enabled) {
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _rules[idx] = _rules[idx].copyWith(enabled: enabled);
    }
  }

  void addCustomRule(InboxRoutingRule rule) {
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  /// Evaluates enabled rules deterministically in order and returns the first match.
  InboxRoutingRule? matchRuleForFile(
    String fileName, {
    String? senderPeerName,
  }) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot != -1 ? fileName.substring(dot + 1).toLowerCase() : '';
    final cat = ReceivedFilesService.instance.classifyExtension(ext);

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.matchPeerNameContains != null && rule.matchPeerNameContains!.isNotEmpty) {
        final peer = (senderPeerName ?? '').toLowerCase();
        if (!peer.contains(rule.matchPeerNameContains!.toLowerCase())) continue;
      }
      if (rule.matchExtension != null && rule.matchExtension!.isNotEmpty) {
        if (ext != rule.matchExtension!.toLowerCase().replaceAll('.', '')) continue;
      }
      if (rule.matchCategory != null && rule.matchCategory != cat) {
        continue;
      }
      return rule;
    }
    return null;
  }

  /// Dry-run preview of files in PeerLink Vault root that would be auto-sorted.
  List<InboxRoutingAction> previewAutoSort({Directory? vaultDir}) {
    final root = vaultDir ?? ReceivedFilesService.instance.saveDirectory;
    if (!root.existsSync()) return const [];
    final actions = <InboxRoutingAction>[];

    for (final entity in root.listSync(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
      if (name.startsWith('.') || name.endsWith('.tmp') || name.endsWith('.part')) continue;

      final rule = matchRuleForFile(name);
      if (rule == null) continue;

      final safeSub = rule.targetSubfolder.replaceAll('..', '_').trim();
      if (safeSub.isEmpty) continue;
      final destPath = '${root.path}${Platform.pathSeparator}$safeSub${Platform.pathSeparator}$name';
      actions.add(InboxRoutingAction(
        fileName: name,
        sourcePath: entity.path,
        destinationPath: destPath,
        matchedRuleName: rule.name,
      ));
    }
    return actions;
  }

  /// Executes planned auto-sort moves safely without overwriting existing files.
  Future<int> applyAutoSort({Directory? vaultDir}) async {
    final planned = previewAutoSort(vaultDir: vaultDir);
    int moved = 0;
    for (final action in planned) {
      final src = File(action.sourcePath);
      if (!src.existsSync()) continue;
      final destFile = File(action.destinationPath);
      if (!destFile.parent.existsSync()) {
        destFile.parent.createSync(recursive: true);
      }
      var finalDest = destFile.path;
      if (File(finalDest).existsSync()) {
        finalDest =
            '${destFile.parent.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_${action.fileName}';
      }
      try {
        src.renameSync(finalDest);
        moved++;
      } catch (_) {
        try {
          src.copySync(finalDest);
          src.deleteSync();
          moved++;
        } catch (_) {}
      }
    }
    if (moved > 0) {
      ReceivedFilesService.instance.notifyChanged();
    }
    return moved;
  }
}
