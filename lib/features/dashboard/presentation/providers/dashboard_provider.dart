import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urban_agent_app/core/model/slot_availability.dart';
import 'package:urban_agent_app/core/model/order_details.dart';
import 'package:urban_agent_app/core/services/apiservices.dart';
import 'package:urban_agent_app/Model/AgentProfileResponse.dart';

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
  @override
  DashboardState build() {
    _init();
    return const DashboardState();
  }

  void _init() async {
    // Need to avoid setting state during build, so we wait for the next frame
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

  void toggleAvailability(bool value) {
    state = state.copyWith(isAvailable: value);
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
