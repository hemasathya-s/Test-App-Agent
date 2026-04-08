import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  final bool isLocationServiceEnabled;
  final String? toggleError;

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
    this.isLocationServiceEnabled = true,
    this.toggleError,
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
    bool? isLocationServiceEnabled,
    Object? toggleError = _sentinel,
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
      isLocationServiceEnabled: isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      toggleError: toggleError == _sentinel ? this.toggleError : toggleError as String?,
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
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final hasNotification = await Permission.notification.isGranted;
      
      if (hasLocation && isServiceEnabled && hasNotification) {
        _startBackgroundService();
      } else {
        await prefs.setBool(_availabilityKey, false);
        state = state.copyWith(isAvailable: false);
      }
    }

    // Always check permissions on startup to ensure location is mandatory
    await _checkPermissions();

    Future.microtask(() => fetchUpcomingJobs());
  }

  Future<void> _checkPermissions() async {
    List<String> missing = [];
    final locationGranted = await Permission.location.isGranted;
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!locationGranted || !isServiceEnabled) missing.add("Location");
    if (!await Permission.notification.isGranted) missing.add("Notification");
    // Check battery optimization status
    if (!await Permission.ignoreBatteryOptimizations.isGranted) missing.add("Battery Optimization");

    if (missing.isNotEmpty) {
      state = state.copyWith(
        showPermissionDialog: true,
        missingPermissions: missing,
        isLocationServiceEnabled: isServiceEnabled,
      );
    } else {
      state = state.copyWith(
        showPermissionDialog: false, 
        missingPermissions: [],
        isLocationServiceEnabled: true,
      );
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to load jobs: $e",
      );
    }
  }

  void setTabIndex(int index) {
    state = state.copyWith(currentTabIndex: index);
  }

  Future<void> requestPermissions() async {
    // 1. Clear current dialog state
    state = state.copyWith(showPermissionDialog: false);

    // 2. Check current status
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();

    // 3. Handle Permission Request Logic
    if (!isServiceEnabled) {
      // If service is disabled, we need to open location settings
      await Geolocator.openLocationSettings();
    }

    if (locationStatus.isPermanentlyDenied || notificationStatus.isPermanentlyDenied) {
      // If permanently denied, must open settings
      await openAppSettings();
    } else {
      // Request permissions
      await [
        Permission.location,
        Permission.notification,
      ].request();
    }

    // 4. Request background location if needed
    if (await Permission.location.isGranted) {
      await Permission.locationAlways.request();
    }

    // 5. Request battery optimization exemption (Non-blocking)
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 6. Re-check status
    await _checkPermissions();

    // If essential tracking permissions and GPS are now granted/enabled, automatically try to go online
    final hasLoc = await Permission.location.isGranted;
    final hasNotif = await Permission.notification.isGranted;
    final isGpsOn = await Geolocator.isLocationServiceEnabled();
    if (hasLoc && hasNotif && isGpsOn && !state.isAvailable) {
       await toggleAvailability(true);
    }
  }

  Future<void> toggleAvailability(bool value) async {
    // 1. Check permissions if going online
    if (value) {
      final hasLocation = await Permission.location.isGranted;
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final hasNotification = await Permission.notification.isGranted;

      if (!hasLocation || !isServiceEnabled || !hasNotification) {
        state = state.copyWith(isAvailable: false);
        _checkPermissions();
        return;
      }
    }

    state = state.copyWith(isLoading: true, toggleError: null);

    try {
      // 2. Call API first to sync status with server
      final result = await ApiService.toggleActiveStatus();

      if (result.isSuccess) {
        // Success: Update local state and background service
        if (value) {
          _startBackgroundService();
        } else {
          _stopBackgroundService();
        }

        state = state.copyWith(
          isAvailable: value,
          showPermissionDialog: false,
          isLoading: false,
        );

        // Refresh jobs to reflect new availability
        await fetchUpcomingJobs();
      } else {
        // Failure: Don't update isAvailable, just show error
        state = state.copyWith(
          isLoading: false,
          toggleError: result.error,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        toggleError: e.toString(),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_availabilityKey, state.isAvailable);
  }

  void clearToggleError() {
    state = state.copyWith(toggleError: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
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
      // Immediately remove the rejected order from the list
      state = state.copyWith(
        upcomingOrders: state.upcomingOrders.where((o) => o.id != orderId).toList(),
        isLoading: false,
      );
      // Still fetch to be safe, but the UI will update immediately
      await fetchUpcomingJobs();
    } else {
      state = state.copyWith(isLoading: false, error: "Failed to reject job");
    }
    return success;
  }
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(() {
  return DashboardController();
});
