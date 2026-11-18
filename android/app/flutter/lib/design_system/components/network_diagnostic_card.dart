import 'package:flutter/material.dart';
import '../../core/network_diagnostic_service.dart';

class NetworkDiagnosticCard extends StatefulWidget {
  const NetworkDiagnosticCard({super.key});

  @override
  State<NetworkDiagnosticCard> createState() => _NetworkDiagnosticCardState();
}

class _NetworkDiagnosticCardState extends State<NetworkDiagnosticCard> {
  final NetworkDiagnosticService _service = NetworkDiagnosticService.instance;
  NetworkDiagnosticResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _service.diagnose();
    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;

    if (_isLoading || res == null) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Container(
      key: const Key('network_diagnostic_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                res.isCongested ? Icons.warning_amber_rounded : Icons.speed_rounded,
                size: 18,
                color: res.isCongested ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'Link Speed Diagnostic',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: res.isCongested ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: res.isCongested ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Text(
                  res.frequencyBand,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: res.isCongested ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            res.recommendation,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
