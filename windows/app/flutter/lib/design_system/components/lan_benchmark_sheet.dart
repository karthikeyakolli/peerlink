import 'package:flutter/material.dart';
import '../../core/lan_benchmark_service.dart';
import '../../core/usb_turbo_mode_service.dart';

/// Minimalist Light-only LAN benchmark and Wi-Fi diagnostic sheet.
class LanBenchmarkSheet extends StatefulWidget {
  const LanBenchmarkSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LanBenchmarkSheet(),
    );
  }

  @override
  State<LanBenchmarkSheet> createState() => _LanBenchmarkSheetState();
}

class _LanBenchmarkSheetState extends State<LanBenchmarkSheet> {
  bool _isRunning = false;
  LanBenchmarkResult? _result;

  @override
  void initState() {
    super.initState();
    _startBenchmark();
  }

  Future<void> _startBenchmark() async {
    setState(() => _isRunning = true);
    final res = await LanBenchmarkService.instance.runBenchmark();
    if (mounted) {
      setState(() {
        _result = res;
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag pill
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAN Speed Benchmark',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Direct socket throughput & Wi-Fi latency diagnostics',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Speedometer / Gauge Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (_isRunning) ...[
                  const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
                  const SizedBox(height: 16),
                  const Text(
                    'Measuring socket throughput...',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ] else if (_result != null) ...[
                  Text(
                    _result!.formattedSpeed,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _metricBadge('Latency', '${_result!.latencyMs} ms', Icons.network_ping_rounded),
                      const SizedBox(width: 12),
                      _metricBadge('Jitter', '${_result!.jitterMs} ms', Icons.wifi_find_rounded),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Diagnostic Advice Card
          if (_result != null && !_isRunning)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _result!.recommendationTurbo ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _result!.recommendationTurbo ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _result!.recommendationTurbo ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: _result!.recommendationTurbo ? const Color(0xFFD97706) : const Color(0xFF15803D),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _result!.recommendationTurbo ? 'Bottleneck Detected' : 'Optimal Network Health',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _result!.recommendationTurbo ? const Color(0xFF92400E) : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _result!.diagnosticAdvice,
                    style: TextStyle(
                      fontSize: 12,
                      color: _result!.recommendationTurbo ? const Color(0xFF92400E) : const Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                  if (_result!.recommendationTurbo) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF92400E),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.usb_rounded, size: 16),
                      label: const Text('Check USB-C Turbo Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        UsbTurboModeService.instance.detectWiredInterfaceIp();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Checking USB tethering interfaces...'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Retest button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('benchmark_start_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isRunning ? 'Testing...' : 'Retest Network Speed', style: const TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _isRunning ? null : _startBenchmark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
