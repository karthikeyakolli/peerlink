import 'package:flutter/material.dart';
import '../../core/node_ipc_client.dart';
import '../../core/operation_journal_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String? _refreshErrorMessage;

  Future<void> _refreshJournal() async {
    setState(() {
      _refreshErrorMessage = null;
    });
    try {
      if (NodeIpcClient.instance.isAuthenticated) {
        await NodeIpcClient.instance.listTransfers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshErrorMessage = 'Failed to refresh journal from Local Node: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<JournalOperation>>(
      stream: OperationJournalService.instance.operationsStream,
      initialData: OperationJournalService.instance.operations,
      builder: (context, snapshot) {
        final activeOps = OperationJournalService.instance.activeOperations;
        final problemOps = OperationJournalService.instance.problemOperations;
        final historyOps = OperationJournalService.instance.historyOperations;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Activity & Problem Diagnostics'),
              actions: [
                IconButton(
                  tooltip: 'Refresh Journal',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refreshJournal,
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(
                    icon: Badge(
                      isLabelVisible: activeOps.isNotEmpty,
                      label: Text('${activeOps.length}'),
                      child: const Icon(Icons.bolt_rounded),
                    ),
                    text: 'ACTIVE',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: problemOps.isNotEmpty,
                      label: Text('${problemOps.length}'),
                      child: const Icon(Icons.warning_amber_rounded),
                    ),
                    text: 'PROBLEMS',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: historyOps.isNotEmpty,
                      label: Text('${historyOps.length}'),
                      child: const Icon(Icons.receipt_long_rounded),
                    ),
                    text: 'HISTORY',
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                if (_refreshErrorMessage != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade900.withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _refreshErrorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _refreshJournal,
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildActiveTab(theme, activeOps),
                      _buildProblemsTab(theme, problemOps),
                      _buildHistoryTab(theme, historyOps),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTab(ThemeData theme, List<JournalOperation> activeOps) {
    if (activeOps.isEmpty) {
      final ipcState = NodeIpcClient.instance.currentState;
      final isConnected = ipcState.status == IpcConnectionStatus.connected;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            glowColor: isConnected ? const Color(0xFF10B981) : Colors.grey,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isConnected ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected ? Icons.verified_user_rounded : Icons.cloud_off_rounded,
                    size: 44,
                    color: isConnected ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'No In-Flight Operations',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isConnected
                      ? 'Local Node Core daemon is operational and waiting for incoming or outgoing transfer requests.'
                      : 'Local Node Core daemon is disconnected. Transfers will stage locally until daemon connects.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildHealthTag(
                      isConnected ? 'NODE: CONNECTED' : 'NODE: DISCONNECTED',
                      isConnected ? const Color(0xFF10B981) : Colors.grey,
                    ),
                    _buildHealthTag('AUDIT LOG: MONITORED', const Color(0xFF2563EB)),
                    _buildHealthTag('ZERO-TRUST: ACTIVE', const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: activeOps.length,
      itemBuilder: (context, index) {
        final op = activeOps[index];
        final progress = op.totalBytes > 0 ? (op.bytesTransferred / op.totalBytes).clamp(0.0, 1.0) : 0.0;

        return InteractiveGlassCard(
          glowColor: const Color(0xFF2563EB),
          margin: const EdgeInsets.only(bottom: 14),
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      op.summary,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB)),
                    ),
                    child: Text(
                      op.stage.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Peer: ${op.peerId} • ID: ${op.operationId}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(op.bytesTransferred / 1048576).toStringAsFixed(1)} MB / ${(op.totalBytes / 1048576).toStringAsFixed(1)} MB (${(progress * 100).toInt()}%)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      OperationJournalService.instance.updateState(
                        op.operationId,
                        JournalOperationState.cancelled,
                        note: 'Cancelled by user from Activity screen',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Operation ${op.operationId} cancelled.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProblemsTab(ThemeData theme, List<JournalOperation> problems) {
    if (problems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            glowColor: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 48, color: Color(0xFF10B981)),
                const SizedBox(height: 14),
                Text(
                  'Zero Unresolved Problems',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'All operation journal states are consistent. No orphaned transfers, quarantine alerts, or uncertain commits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: problems.length,
      itemBuilder: (context, index) {
        final p = problems[index];
        final isUnknown = p.state == JournalOperationState.outcomeUnknown;

        final title = isUnknown
            ? 'Outcome Uncertain: ACK Lost After Commit'
            : (p.state == JournalOperationState.recoveryRequired
                ? 'Crash Interruption: Recovery Required'
                : 'Operation Failure Detected');

        final whyExplanation = isUnknown
            ? 'The payload was committed locally or on the target, but the network was severed before delivery confirmation. Rule 9 prohibits blind destructive replay.'
            : (p.errorNote ?? 'Operation encountered an unhandled network or filesystem condition.');

        final suggestedAction = isUnknown
            ? 'Do NOT blindly re-send to avoid duplicate commits. Run real diagnostics to inspect staging and reconcile status.'
            : 'Review error details and inspect node status to safely clear or retry the operation.';

        return InteractiveGlassCard(
          glowColor: Colors.deepPurple,
          margin: const EdgeInsets.only(bottom: 14),
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.deepPurple, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade300,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Operation: ${p.summary}\nID: ${p.operationId} • Peer: ${p.peerId}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why this happened:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(whyExplanation, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested Recovery Action:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(suggestedAction, style: const TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      OperationJournalService.instance.dismissProblem(p.operationId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Incident dismissed.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (isUnknown) {
                        final res = await OperationJournalService.instance.runDiagnosticsAndReconcile(p.operationId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      } else {
                        OperationJournalService.instance.dismissProblem(p.operationId);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(isUnknown ? 'Run Diagnostics & Reconcile' : 'Resolve Incident'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(ThemeData theme, List<JournalOperation> history) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            glowColor: Colors.blueGrey,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded, size: 48, color: Colors.blueGrey),
                const SizedBox(height: 14),
                Text(
                  'No Operation History Recorded',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Past completed, failed, and cancelled operations from the journal will be logged here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final h = history[index];
        Color statusColor;
        IconData statusIcon;

        switch (h.state) {
          case JournalOperationState.committed:
            statusColor = const Color(0xFF10B981);
            statusIcon = Icons.check_circle_rounded;
            break;
          case JournalOperationState.failed:
            statusColor = const Color(0xFFEF4444);
            statusIcon = Icons.error_rounded;
            break;
          case JournalOperationState.cancelled:
            statusColor = Colors.grey;
            statusIcon = Icons.cancel_rounded;
            break;
          default:
            statusColor = Colors.orange;
            statusIcon = Icons.help_outline_rounded;
            break;
        }

        return InteractiveGlassCard(
          glowColor: statusColor,
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.summary,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peer: ${h.peerId} • ID: ${h.operationId}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (h.errorNote != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        h.errorNote!,
                        style: TextStyle(fontSize: 10, color: Colors.amber.shade300),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  h.state.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
