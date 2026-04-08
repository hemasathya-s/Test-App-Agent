import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urban_agent_app/core/services/apiservices.dart';
import 'package:urban_agent_app/features/inventory/presentation/pages/inventory_screen.dart';
import 'package:urban_agent_app/features/map/presentation/pages/live_map_screen.dart';
import 'package:urban_agent_app/features/schedule/presentation/pages/slot_management_screen.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../schedule/presentation/providers/schedule_refresh_provider.dart';
import '../providers/dashboard_provider.dart';
import 'home_tab.dart';


import '../widgets/app_drawer.dart';
import '../widgets/sos_bottom_sheet.dart';
import 'package:flutter/services.dart';


class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {

  @override
  void initState() {
    super.initState();
    _onDashboardReady();
  }

  Future<void> _onDashboardReady() async {
    await ApiService.addFcmToken();
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (state.currentTabIndex != 0) {
          controller.setTabIndex(0);
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor:
                isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Exit App',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                content: Text(
                  'Do you really want to exit?',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor),
                      ),
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        // drawer: const AppDrawer(),
        body: IndexedStack(
          index: state.currentTabIndex,
          children: const [
            HomeTab(),
            SlotManagementScreen(),
            MyZonePage(),
            InventoryScreen(),
          ],
        ),
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
            onDestinationSelected: (index) {
              if (index == 1) {
                ref.read(scheduleRefreshProvider.notifier).state++;
              }
              controller.setTabIndex(index);
            },
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
      ),
    );
  }
}
