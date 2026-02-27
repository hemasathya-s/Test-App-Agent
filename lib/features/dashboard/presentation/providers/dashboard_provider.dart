import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardState {
  final int currentTabIndex;
  final bool isAvailable;
  final Set<String> acceptedJobIds;

  const DashboardState({
    this.currentTabIndex = 0,
    this.isAvailable = false,
    this.acceptedJobIds = const {},
  });

  DashboardState copyWith({
    int? currentTabIndex,
    bool? isAvailable,
    Set<String>? acceptedJobIds,
  }) {
    return DashboardState(
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isAvailable: isAvailable ?? this.isAvailable,
      acceptedJobIds: acceptedJobIds ?? this.acceptedJobIds,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    return const DashboardState();
  }

  void setTabIndex(int index) {
    state = state.copyWith(currentTabIndex: index);
  }

  void toggleAvailability(bool value) {
    state = state.copyWith(isAvailable: value);
  }

  void acceptJob(String jobId) {
    state = state.copyWith(
      acceptedJobIds: {...state.acceptedJobIds, jobId},
    );
  }
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(() {
  return DashboardController();
});
