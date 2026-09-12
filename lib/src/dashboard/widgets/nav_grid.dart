import 'package:material_ui/material_ui.dart';

import '../../debug_logger.dart';
import '../../filters/filter_state.dart';
import '../../filters/filters_screen.dart';
import '../../log_level.dart';
import '../../logs/all_logs_screen.dart';
import '../../sessions/sessions_screen.dart';
import '../../settings/settings_screen.dart';
import '../../shared/app_colors.dart';
import '../../shared/custom_text.dart';
import '../../shared/debug_scope.dart';

class NavGrid extends StatelessWidget {
  const NavGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugLogger.store,
      builder: (context, _) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            _NavTile(
              icon: Icons.list_alt_rounded,
              label: 'All Logs',
              onTap: () => Navigator.push(
                context,
                debugPageRoute(const AllLogsScreen()),
              ),
            ),
            _NavTile(
              icon: Icons.history_rounded,
              label: 'Sessions',
              onTap: () => Navigator.push(
                context,
                debugPageRoute(const SessionsScreen()),
              ),
            ),
            if (DebugLogger.socketLoggingEnabled)
              _NavTile(
                icon: Icons.sync_alt_rounded,
                label: 'Socket Logs',
                onTap: () => Navigator.push(
                  context,
                  debugPageRoute(
                    AllLogsScreen(
                      tagFilter: LogTag.socketTags.toSet(),
                      title: 'Socket Logs',
                    ),
                  ),
                ),
              ),
            ListenableBuilder(
              listenable: FilterState.instance,
              builder: (_, __) => _NavTile(
                icon: Icons.filter_list_rounded,
                label: 'Filters',
                badge: FilterState.instance.activeFilterCount > 0
                    ? '${FilterState.instance.activeFilterCount}'
                    : null,
                onTap: () => Navigator.push(
                  context,
                  debugPageRoute(const FiltersScreen()),
                ),
              ),
            ),
            _NavTile(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => Navigator.push(
                context,
                debugPageRoute(const SettingsScreen()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: CustomText(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orangeAccent.withAlpha(80)),
                ),
                child: CustomText(
                  badge!,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
