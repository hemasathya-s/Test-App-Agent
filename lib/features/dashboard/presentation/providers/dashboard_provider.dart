import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/model/slot_availability.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';

const Object _sentinel = Object();

class DashboardState {
  final int currentTabIndex;
  final bool isAvailable;
  final Set<String> acceptedJobIds;
  final List<SlotAvailability> upcomingJobs;
  final List<OrderDetails> upcomingOrders;
  final String? noOrdersMessage;
  final bool isLoading;
  final String? error;
  final bool showPermissionDialog;
  final List<String> missingPermissions;

  const DashboardState({
    this.currentTabIndex = 0,
    this.isAvailable = false,
    this.acceptedJobIds = const {},
    this.upcomingJobs = const [],
    this.upcomingOrders = const [],
    this.noOrdersMessage,
    this.isLoading = false,
    this.error,
    this.showPermissionDialog = false,
    this.missingPermissions = const [],
  });

  DashboardState copyWith({
    int? currentTabIndex,
    bool? isAvailable,
    Set<String>? acceptedJobIds,
    List<SlotAvailability>? upcomingJobs,
    List<OrderDetails>? upcomingOrders,
    Object? noOrdersMessage = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
    bool? showPermissionDialog,
    List<String>? missingPermissions,
  }) {
    return DashboardState(
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isAvailable: isAvailable ?? this.isAvailable,
      acceptedJobIds: acceptedJobIds ?? this.acceptedJobIds,
      upcomingJobs: upcomingJobs ?? this.upcomingJobs,
      upcomingOrders: upcomingOrders ?? this.upcomingOrders,
      noOrdersMessage: noOrdersMessage == _sentinel
          ? this.noOrdersMessage
          : noOrdersMessage as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      showPermissionDialog: showPermissionDialog ?? this.showPermissionDialog,
      missingPermissions: missingPermissions ?? this.missingPermissions,
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
      final hasLocation = await Permission.location.isGranted;
      final hasNotification = await Permission.notification.isGranted;
      
      if (hasLocation && hasNotification) {
        _startBackgroundService();
      } else {
        await prefs.setBool(_availabilityKey, false);
        state = state.copyWith(isAvailable: false);
        // Initial check on app startup
        _checkPermissions();
      }
    }
    
    Future.microtask(() => fetchUpcomingJobs());
  }

  Future<void> _checkPermissions() async {
    List<String> missing = [];
    if (!await Permission.location.isGranted) missing.add("Location");
    if (!await Permission.notification.isGranted) missing.add("Notification");
    // Check battery optimization status
    if (!await Permission.ignoreBatteryOptimizations.isGranted) missing.add("Battery Optimization");

    if (missing.isNotEmpty) {
      state = state.copyWith(
        showPermissionDialog: true,
        missingPermissions: missing,
      );
    } else {
      state = state.copyWith(showPermissionDialog: false, missingPermissions: []);
    }
  }

  void dismissPermissionDialog() {
    state = state.copyWith(showPermissionDialog: false);
  }

  Future<void> fetchUpcomingJobs() async {
    state = state.copyWith(isLoading: true, error: null, noOrdersMessage: null);
    try {
      final jobs = await ApiService.getAgentSlotAvailability();
      final agentOrderResponse = await ApiService.agentOrder();
      
      final orders = agentOrderResponse?.orders ?? [];
      final noOrdersMsg = agentOrderResponse?.message;
      print("API Response - noOrdersMessage: $noOrdersMsg");

      // Fetch profile to get availability status
      final profileResult = await ApiService.getAgentProfile();
      bool isAvailable = state.isAvailable;
      if (profileResult.isSuccess && profileResult.data != null) {
        isAvailable = profileResult.data!.agent.userDetails.isActive;
      }

      state = state.copyWith(
        upcomingJobs: jobs,
        upcomingOrders: orders,
        noOrdersMessage: noOrdersMsg,
        isAvailable: isAvailable,
        isLoading: false,
      );
      print("Dashboard State - isAvailable: $isAvailable");
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

  Future<void> requestPermissions() async {
    // 1. Clear current dialog state to prevent rebuild loops
    state = state.copyWith(showPermissionDialog: false);

    // 2. Request basic permissions first
    await [
      Permission.location,
      Permission.notification,
    ].request();

    // 3. Request background location
    if (await Permission.location.isGranted) {
      await Permission.locationAlways.request();
    }

    // 4. Request battery optimization exemption
    await Permission.ignoreBatteryOptimizations.request();

    // 5. Re-check status
    await _checkPermissions();

    // If essential tracking permissions are granted, try to go online
    final hasLocation = await Permission.location.isGranted;
    final hasNotification = await Permission.notification.isGranted;
    if (hasLocation && hasNotification) {
       // Only start if they aren't already online
       if (!state.isAvailable) {
         await toggleAvailability(true);
       }
    }
  }

  Future<void> toggleAvailability(bool value) async {
    if (value) {
      final hasLocation = await Permission.location.isGranted;
      final hasNotification = await Permission.notification.isGranted;

      if (hasLocation && hasNotification) {
        _startBackgroundService();
        state = state.copyWith(isAvailable: true, showPermissionDialog: false);
      } else {
        state = state.copyWith(isAvailable: false);
        _checkPermissions();
        return;
      }
    } else {
      _stopBackgroundService();
      state = state.copyWith(isAvailable: false);
    }

    // Call API to sync status with server
    await ApiService.toggleActiveStatus();
    
    // Refresh jobs to reflect new availability
    await fetchUpcomingJobs();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_availabilityKey, state.isAvailable);
  }

  void _startBackgroundService() {
    try {
      FlutterBackgroundService().startService();
    } catch (e) {
      debugPrint("Error starting background service: $e");
    }
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
