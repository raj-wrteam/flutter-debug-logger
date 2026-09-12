import 'package:material_ui/material_ui.dart';

import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_divider.dart';
import 'widgets/log_stats_cards.dart';
import 'widgets/nav_grid.dart';
import 'widgets/status_panel.dart';
import '../shared/debug_scope.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DebugSurface(
      child: Scaffold(
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
              CustomDivider(),
              SizedBox(height: 16),
              NavGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
