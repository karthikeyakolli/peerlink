import 'package:flutter/material.dart';

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
        whatHappened: 'Transfer of "design_assets.zip" (24.5 MB) was halted at 68% completion.',
        whyExplanation: 'Target peer "peer_pixel_phone" entered Android Doze mode or lost Wi-Fi connectivity.',
        suggestedAction: 'Wait for peer to reconnect or click "Retry Connection". Unfinished chunks are preserved in staging.',
        timestamp: '14 minutes ago',
        icon: Icons.wifi_off_rounded,
        severityColor: Colors.orange.shade800,
        recoveryButtonLabel: 'Retry Connection',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retrying connection and resuming transfer from chunk #42...')),
          );
        },
      ),
      ProblemRecord(
        id: 'prob_safety_quarantine',
        title: 'Security Alert: Inbound Executable Quarantined',
        whatHappened: 'File "patch_tool.exe" from Bob (Guest Share) was held in secure quarantine.',
        whyExplanation: 'PeerLink safety policy blocks direct automatic execution or writing of binary executables to prevent malware infection.',
        suggestedAction: 'Review file source. You can inspect or explicitly authorize the file in Quarantine settings if trusted.',
        timestamp: '45 minutes ago',
        icon: Icons.security_rounded,
        severityColor: Colors.red.shade700,
        recoveryButtonLabel: 'Review in Quarantine',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening Quarantine Manager in Settings...')),
          );
        },
      ),
      ProblemRecord(
        id: 'prob_outcome_unknown',
        title: 'Outcome Unconfirmed: ACK Lost After Commit',
        whatHappened: 'Remote confirmation for transfer "xfer_8f910b" was not received.',
        whyExplanation: 'The target peer committed the files to disk, but the network was severed before delivering the final ACK.',
        suggestedAction: 'Do NOT blindly re-send to avoid duplicates. Click "Reconcile Status" to verify receipt.',
        timestamp: '1 hour ago',
        icon: Icons.help_outline_rounded,
        severityColor: Colors.deepPurple,
        recoveryButtonLabel: 'Reconcile Status',
        onRecover: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reconciled with remote peer: Files are confirmed intact!')),
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
              const Tab(icon: Icon(Icons.receipt_long_rounded), text: 'HISTORY'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(
              'All Active Operations Idling',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No file transfers or active sync streams are running. Local Node is listening for peer connections.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemsTab(ThemeData theme) {
    if (_problems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_rounded, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(
              'Zero Unresolved Problems',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All transfers, sync spaces, and cryptographic integrity checks are clean.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _problems.length,
      itemBuilder: (context, index) {
        final p = _problems[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.severityColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
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
                        color: p.severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(p.icon, color: p.severityColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.severityColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(p.timestamp, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Dismiss Alert',
                      onPressed: () => _dismissProblem(p),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  p.whatHappened,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Why this happened:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(p.whyExplanation, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.green.shade800),
                          const SizedBox(width: 4),
                          Text(
                            'Suggested Action:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(p.suggestedAction, style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _dismissProblem(p),
                      child: const Text('Dismiss'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: p.onRecover,
                      style: FilledButton.styleFrom(backgroundColor: p.severityColor),
                      child: Text(p.recoveryButtonLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final h = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: h.statusColor.withValues(alpha: 0.12),
              child: Icon(Icons.check_rounded, color: h.statusColor),
            ),
            title: Text(h.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Peer: ${h.peer} • ${h.timestamp}', style: const TextStyle(fontSize: 12)),
            trailing: Chip(
              label: Text(h.status),
              backgroundColor: h.statusColor.withValues(alpha: 0.1),
              labelStyle: TextStyle(color: h.statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
