import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import 'widgets/log_stats_cards.dart';
import 'widgets/nav_grid.dart';
import 'widgets/status_panel.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Debug Console',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            StatusPanel(),
            SizedBox(height: 16),
            LogStatsCards(),
            SizedBox(height: 20),
            Divider(color: Colors.white10, height: 1),
            SizedBox(height: 16),
            NavGrid(),
          ],
        ),
      ),
    );
  }
}
