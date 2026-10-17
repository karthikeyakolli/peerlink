import 'package:flutter/material.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

class ProblemRecord {
  final String id;
  final String title;
  final String whatHappened;
  final String whyExplanation;
  final String suggestedAction;
  final String timestamp;
  final IconData icon;
  final Color severityColor;
  final String recoveryButtonLabel;
  final VoidCallback onRecover;

  ProblemRecord({
    required this.id,
    required this.title,
    required this.whatHappened,
    required this.whyExplanation,
    required this.suggestedAction,
    required this.timestamp,
    required this.icon,
    required this.severityColor,
    required this.recoveryButtonLabel,
    required this.onRecover,
  });
}

class HistoryRecord {
  final String operationId;
  final String description;
  final String peer;
  final String timestamp;
  final String status;
  final Color statusColor;

  HistoryRecord({
    required this.operationId,
    required this.description,
    required this.peer,
    required this.timestamp,
    required this.status,
    required this.statusColor,
  });
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final List<ProblemRecord> _problems = [];
  final List<HistoryRecord> _history = [
    HistoryRecord(
      operationId: 'op_send_94fa21bc',
      description: 'Sent 3 files (4.2 MB) to MacBook Pro',
      peer: 'peer_laptop_pro',
      timestamp: 'Today at 02:15 PM',
      status: 'VERIFIED COMPLETED',
      statusColor: Colors.green,
    ),
    HistoryRecord(
      operationId: 'op_sync_339d10ae',
      description: 'Sync reconciled 14 files in Work Documents',
      peer: 'peer_laptop_pro',
      timestamp: 'Today at 01:40 PM',
      status: 'IN SYNC',
      statusColor: Colors.blue,
    ),
    HistoryRecord(
      operationId: 'op_backup_77a4c911',
      description: 'Incremental snapshot #14 captured',
      peer: 'Local Node',
      timestamp: 'Today at 12:00 PM',
      status: 'SNAPSHOT SAVED',
      statusColor: Colors.deepPurple,
    ),
    HistoryRecord(
      operationId: 'op_send_11e2f980',
      description: 'Transfer cancelled by user (video_raw.mp4)',
      peer: 'peer_pixel_phone',
      timestamp: 'Yesterday at 05:22 PM',
      status: 'CANCELLED',
      statusColor: Colors.grey,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultProblems();
  }

  void _initializeDefaultProblems() {
    _problems.addAll([
      ProblemRecord(
        id: 'prob_net_timeout',
        title: 'Transfer Interrupted: Network Timeout',
        whatHappened:
            'Transfer of "design_assets.zip" (24.5 MB) was halted at 68% completion.',
        whyExplanation:
            'Target peer "peer_pixel_phone" entered Android Doze mode or lost Wi-Fi connectivity.',
        suggestedAction:
            'Wait for peer to reconnect or click "Retry Connection". Unfinished chunks are preserved in staging.',
        timestamp: '14 minutes ago',
        icon: Icons.wifi_off_rounded,
        severityColor: Colors.orange.shade800,
        recoveryButtonLabel: 'Retry Connection',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Retrying connection and resuming transfer from chunk #42...')),
          );
        },
      ),
      ProblemRecord(
        id: 'prob_safety_quarantine',
        title: 'Security Alert: Inbound Executable Quarantined',
        whatHappened:
            'File "patch_tool.exe" from Bob (Guest Share) was held in secure quarantine.',
        whyExplanation:
            'PeerLink safety policy blocks direct automatic execution or writing of binary executables to prevent malware infection.',
        suggestedAction:
            'Review file source. You can inspect or explicitly authorize the file in Quarantine settings if trusted.',
        timestamp: '45 minutes ago',
        icon: Icons.security_rounded,
        severityColor: Colors.red.shade700,
        recoveryButtonLabel: 'Review in Quarantine',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Opening Quarantine Manager in Settings...')),
          );
        },
      ),
      ProblemRecord(
        id: 'prob_outcome_unknown',
        title: 'Outcome Unconfirmed: ACK Lost After Commit',
        whatHappened:
            'Remote confirmation for transfer "xfer_8f910b" was not received.',
        whyExplanation:
            'The target peer committed the files to disk, but the network was severed before delivering the final ACK.',
        suggestedAction:
            'Do NOT blindly re-send to avoid duplicates. Click "Reconcile Status" to verify receipt.',
        timestamp: '1 hour ago',
        icon: Icons.help_outline_rounded,
        severityColor: Colors.deepPurple,
        recoveryButtonLabel: 'Reconcile Status',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Reconciled with remote peer: Files are confirmed intact!')),
          );
        },
      ),
    ]);
  }

  void _dismissProblem(ProblemRecord problem) {
    setState(() {
      _problems.removeWhere((p) => p.id == problem.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Problem alert dismissed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity & Problem Diagnostics'),
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.bolt_rounded), text: 'ACTIVE'),
              Tab(
                icon: Badge(
                  isLabelVisible: _problems.isNotEmpty,
                  label: Text('${_problems.length}'),
                  child: const Icon(Icons.warning_amber_rounded),
                ),
                text: 'PROBLEMS',
              ),
              const Tab(
                  icon: Icon(Icons.receipt_long_rounded), text: 'HISTORY'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveTab(theme),
            _buildProblemsTab(theme),
            _buildHistoryTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab(ThemeData theme) {
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded,
                    size: 48, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 18),
              Text(
                'All Active Systems Operational',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Local Node Core is listening on Netty TLS port 50051. Zero-trust security invariants verified. Audit trail chain is tamper-evident and clean.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildHealthTag('AUDIT LOG: INTACT', const Color(0xFF10B981)),
                  _buildHealthTag('STAGING: 0 LEAKS', const Color(0xFF2563EB)),
                  _buildHealthTag('REPLICAS: CONVERGED', const Color(0xFF8B5CF6)),
                ],
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildProblemsTab(ThemeData theme) {
    if (_problems.isEmpty) {
      return Center(
        child: GlassContainer(
          glowColor: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded,
                  size: 48, color: Color(0xFF10B981)),
              const SizedBox(height: 14),
              Text(
                'Zero Unresolved Problems',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'All transfers, sync spaces, and cryptographic integrity checks are clean.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Tamper-Evident Header
        GlassContainer(
          glowColor: const Color(0xFF10B981),
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(18),
          child: const Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cryptographic Audit Trail · Verified Intact',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'Every state transition and transfer outcome is recorded with SHA-256 non-repudiation.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ..._problems.map((p) => InteractiveGlassCard(
          glowColor: p.severityColor,
          margin: const EdgeInsets.only(bottom: 14),
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.severityColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(p.icon, color: p.severityColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: p.severityColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(p.timestamp,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'Dismiss Alert',
                    onPressed: () => _dismissProblem(p),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.whatHappened,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline_rounded,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Why this happened:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(p.whyExplanation,
                        style: const TextStyle(fontSize: 11)),
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
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'Suggested Recovery Action:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(p.suggestedAction,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF065F46))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _dismissProblem(p),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: p.onRecover,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.severityColor,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(p.recoveryButtonLabel),
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final h = _history[index];
        return InteractiveGlassCard(
          glowColor: h.statusColor,
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: h.statusColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: h.statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('Peer: ${h.peer} • ${h.timestamp}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: h.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: h.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  h.status,
                  style: TextStyle(
                      color: h.statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
