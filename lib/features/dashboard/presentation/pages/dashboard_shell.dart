import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urban_agent_app/features/inventory/presentation/pages/inventory_screen.dart';
import 'package:urban_agent_app/features/map/presentation/pages/live_map_screen.dart';
import 'package:urban_agent_app/features/schedule/presentation/pages/slot_management_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import 'home_tab.dart';

import '../widgets/app_drawer.dart';
import '../widgets/sos_bottom_sheet.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      // drawer: const AppDrawer(),
      body: IndexedStack(
        index: state.currentTabIndex,
        children: [
          const HomeTab(),
          const SlotManagementScreen(),
          const MyZonePage(),
          const InventoryScreen(),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     showModalBottomSheet(
      //       context: context,
      //       backgroundColor: Colors.transparent,
      //       isScrollControlled: true,
      //       builder: (context) => const SosBottomSheet(),
      //     );
      //   },
      //   backgroundColor: Colors.red,
      //   elevation: 4,
      //   shape: const CircleBorder(),
      //   child: const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
      // ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: state.currentTabIndex,
          onDestinationSelected: controller.setTabIndex,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryColor.withOpacity(0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(
                Icons.calendar_today,
                color: AppTheme.primaryColor,
              ),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppTheme.primaryColor),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(
                Icons.inventory_2,
                color: AppTheme.primaryColor,
              ),
              label: 'Inventory',
            ),
          ],
        ),
      ),
    );
  }
}
