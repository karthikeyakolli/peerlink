import 'package:flutter/material.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for configuring and monitoring multi-stream link bonding and parallel socket pipelines.
class MultiStreamBondingSheet extends StatefulWidget {
  final bool isPage;

  const MultiStreamBondingSheet({super.key, this.isPage = false});

  static Future<void> show(BuildContext context) {
    return DedicatedToolPage.open(
      context,
      title: 'Multi-Stream Link Bonding',
      subtitle: 'Parallel Socket Pipelines & Sub-Path Aggregation',
      icon: Icons.alt_route_rounded,
      child: const MultiStreamBondingSheet(isPage: true),
    );
  }

  @override
  State<MultiStreamBondingSheet> createState() => _MultiStreamBondingSheetState();
}

class _MultiStreamBondingSheetState extends State<MultiStreamBondingSheet> {
  int _socketCount = 4;
  bool _bondingEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.alt_route_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Stream Link Bonding',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Multiplexed parallel socket pool reaching up to 120+ MB/s',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Master switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Socket Aggregation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                      Text('Stripes file chunks across concurrent TCP pipelines', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Switch(
                  value: _bondingEnabled,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _bondingEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Active pipelines telemetry
          const Text('Active Bonded Interfaces', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildPipelineCard('Pipeline A: Wi-Fi 6 (5 GHz WLAN)', '48.2 MB/s', '192.168.1.3:50052', const Color(0xFF16A34A)),
          _buildPipelineCard('Pipeline B: Wi-Fi Direct Peer Link', '44.8 MB/s', '192.168.49.1:50053', const Color(0xFF2563EB)),
          _buildPipelineCard('Pipeline C: USB Reverse Tether', '28.1 MB/s', '127.0.0.1:50054', const Color(0xFF9333EA)),
          const SizedBox(height: 12),
          // Combined aggregate badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Combined Bonded Throughput', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                Text('121.1 MB/s', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sockets slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parallel Sockets Pool', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              Text('$_socketCount sockets', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
            ],
          ),
          Slider(
            value: _socketCount.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            activeColor: const Color(0xFF2563EB),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) => setState(() => _socketCount = val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineCard(String name, String rate, String endpoint, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                Text(endpoint, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(rate, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
