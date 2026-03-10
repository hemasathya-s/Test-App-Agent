import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/model/slot_availability.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';

class DashboardState {
  final int currentTabIndex;
  final bool isAvailable;
  final Set<String> acceptedJobIds;
  final List<SlotAvailability> upcomingJobs;
  final List<OrderDetails> upcomingOrders;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.currentTabIndex = 0,
    this.isAvailable = false,
    this.acceptedJobIds = const {},
    this.upcomingJobs = const [],
    this.upcomingOrders = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    int? currentTabIndex,
    bool? isAvailable,
    Set<String>? acceptedJobIds,
    List<SlotAvailability>? upcomingJobs,
    List<OrderDetails>? upcomingOrders,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isAvailable: isAvailable ?? this.isAvailable,
      acceptedJobIds: acceptedJobIds ?? this.acceptedJobIds,
      upcomingJobs: upcomingJobs ?? this.upcomingJobs,
      upcomingOrders: upcomingOrders ?? this.upcomingOrders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  static const String _availabilityKey = 'agent_is_online';

  @override
  DashboardState build() {
    _init();
    return const DashboardState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final bool persistedStatus = prefs.getBool(_availabilityKey) ?? false;

    state = state.copyWith(isAvailable: persistedStatus);

    if (persistedStatus) {
      // Check if we still have permissions on restart
      final hasLocation = await Permission.location.isGranted;
      final hasNotification = await Permission.notification.isGranted;

      if (hasLocation && hasNotification) {
        _startBackgroundService();
      } else {
        await prefs.setBool(_availabilityKey, false);
        state = state.copyWith(isAvailable: false);
      }
    }

    Future.microtask(() => fetchUpcomingJobs());
  }

  Future<void> fetchUpcomingJobs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final jobs = await ApiService.getAgentSlotAvailability();
      final orders = await ApiService.agentOrder();
      
      // Fetch profile to get availability status
      final profileResult = await ApiService.getAgentProfile();
      bool isAvailable = state.isAvailable;
      if (profileResult.isSuccess && profileResult.data != null) {
        isAvailable = profileResult.data!.agent.userDetails.isActive;
      }

      state = state.copyWith(
        upcomingJobs: jobs,
        upcomingOrders: orders ?? [],
        isAvailable: isAvailable,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load jobs: $e",
      );
      print("Error fetching upcoming jobs: $e");
    }
  }

  void setTabIndex(int index) {
    state = state.copyWith(currentTabIndex: index);
  }

  Future<void> toggleAvailability(bool value) async {
    if (value) {
      // 1. Request Permissions first
      final status = await [
        Permission.location,
        Permission.notification,
        Permission.locationAlways, // Recommended for background tracking
      ].request();

      // 2. Check if essential permissions are granted
      final isLocationGranted = status[Permission.location]?.isGranted ?? false;
      final isNotificationGranted = status[Permission.notification]?.isGranted ?? false;

      if (isLocationGranted && isNotificationGranted) {
        _startBackgroundService();
      } else {
        // Permissions denied, revert switch
        state = state.copyWith(
          isAvailable: false,
          error: "Location and Notification permissions are required to go online.",
        );
        return;
      }
    } else {
      _stopBackgroundService();
    }

    state = state.copyWith(isAvailable: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_availabilityKey, value);
  }

  void _startBackgroundService() {
    FlutterBackgroundService().startService();
  }

  void _stopBackgroundService() {
    FlutterBackgroundService().invoke("stopService");
  }

  Future<bool> acceptJob(String orderId) async {
    state = state.copyWith(isLoading: true);
    final success = await ApiService.agentApprovalOrder(orderId, "CONFIRMED");
    if (success) {
      state = state.copyWith(
        acceptedJobIds: {...state.acceptedJobIds, orderId},
      );
      await fetchUpcomingJobs();
    } else {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to accept job",
      );
    }
    return success;
  }

  Future<bool> rejectJob(String orderId, String reason) async {
    state = state.copyWith(isLoading: true);
    final success = await ApiService.agentApprovalOrder(
      orderId,
      "REJECTED",
      reason: reason,
    );
    if (success) {
      await fetchUpcomingJobs();
    } else {
      state = state.copyWith(isLoading: false, error: "Failed to reject job");
      state = state.copyWith(
        isLoading: false,
        error: "Failed to reject job",
      );
    }
    return success;
  }
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(() {
  return DashboardController();
});
