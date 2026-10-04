import 'package:flutter/material.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Trust'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Pair Device via QR',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.laptop_windows_rounded),
              ),
              title: Text('This Device (Local Node)'),
              subtitle: Text('Fingerprint: Verified • Ed25519'),
              trailing: Chip(
                label: Text('ACTIVE'),
                backgroundColor: Color(0xFFE8F5E9),
                labelStyle: TextStyle(color: Color(0xFF2E7D32)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
