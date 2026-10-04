import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity & Journal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Problems'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('No active transfers or operations in flight.')),
            Center(child: Text('No unresolved errors or warnings.')),
            Center(child: Text('Operation history journal.')),
          ],
        ),
      ),
    );
  }
}
