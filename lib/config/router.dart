import 'package:go_router/go_router.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/features/auth/presentation/pages/splash_screen.dart';
import 'package:urban_agent_app/features/auth/presentation/pages/login_screen.dart';
import 'package:urban_agent_app/features/auth/presentation/pages/permissions_screen.dart';
import 'package:urban_agent_app/features/auth/presentation/pages/kyc_status_screen.dart';
import 'package:urban_agent_app/features/dashboard/presentation/pages/AgentProfilePage.dart';
import 'package:urban_agent_app/features/dashboard/presentation/pages/edit_profile_screen.dart';
import 'package:urban_agent_app/features/dashboard/presentation/pages/dashboard_shell.dart';
import 'package:urban_agent_app/features/auth/presentation/pages/CreateAgent.dart';
import 'package:urban_agent_app/features/map/presentation/pages/service_area_screen.dart';
import 'package:urban_agent_app/features/jobs/presentation/pages/new_job_request_screen.dart';
import 'package:urban_agent_app/features/jobs/presentation/pages/job_details_screen.dart';
import 'package:urban_agent_app/features/jobs/presentation/pages/navigation_screen.dart';
import 'package:urban_agent_app/features/jobs/presentation/pages/service_checklist_screen.dart';
import 'package:urban_agent_app/features/order/presentation/pages/modify_order_screen.dart';
import 'package:urban_agent_app/features/order/presentation/pages/modification_summary_screen.dart';
import 'package:urban_agent_app/features/order/presentation/pages/approval_waiting_screen.dart';
import 'package:urban_agent_app/features/order/presentation/pages/request_tracking_screen.dart';
import 'package:urban_agent_app/features/orders/presentation/pages/orders_history_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final mobileNumber = state.extra as String?;
        return LoginPage(initialMobileNumber: mobileNumber);
      },
    ),
    GoRoute(
      path: '/permissions',
      builder: (context, state) => const PermissionsScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final mobileNumber = state.extra as String?;
        return AgentRegistrationPage(mobileNumber: mobileNumber);
      },
    ),
    GoRoute(path: '/kyc', builder: (context, state) => const KycStatusScreen()),
    GoRoute(path: '/home', builder: (context, state) => const DashboardShell()),
    GoRoute(
      path: '/service-area',
      builder: (context, state) => const ServiceAreaScreen(),
    ),
    GoRoute(
      path: '/job-request',
      builder: (context, state) => const NewJobRequestScreen(),
    ),
    GoRoute(
      path: '/job-details',
      builder: (context, state) {
        final extra = state.extra;
        print("Router extra: $extra");
        print("Router extra type: ${extra.runtimeType}");
        if (extra is SlotAvailability) {
          print("Router: extra matches SlotAvailability");
          return JobDetailsScreen(slot: extra);
        } else if (extra is OrderDetails) {
          print("Router: extra matches OrderDetails");
          return JobDetailsScreen(order: extra);
        }
        print("Router: extra NO MATCH");
        return const JobDetailsScreen();
      },
    ),
    GoRoute(
      path: '/navigation',
      builder: (context, state) => const NavigationScreen(),
    ),
    GoRoute(
      path: '/agent-tracking',
      builder: (context, state) => const NavigationScreen(),
    ),
    GoRoute(
      path: '/checklist',
      builder: (context, state) => const ServiceChecklistScreen(),
    ),
    GoRoute(
      path: '/modify-order',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is OrderDetails) {
          return ModifyOrderScreen(order: extra);
        }
        return const ModifyOrderScreen();
      },
    ),
    GoRoute(
      path: '/modification-summary',
      builder: (context, state) => const ModificationSummaryScreen(),
    ),
    GoRoute(
      path: '/approval-waiting',
      builder: (context, state) => const ApprovalWaitingScreen(),
    ),
    GoRoute(
      path: '/request-tracking',
      builder: (context, state) => const RequestTrackingScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersHistoryScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const AgentProfilePage(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
  ],
);
