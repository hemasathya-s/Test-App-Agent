import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class DashboardState {
  final int currentTabIndex;
  final bool isAvailable;

  const DashboardState({
    this.currentTabIndex = 0,
    this.isAvailable = false,
  });

  DashboardState copyWith({
    int? currentTabIndex,
    bool? isAvailable,
  }) {
    return DashboardState(
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController() : super(const DashboardState());

  void setTabIndex(int index) {
    state = state.copyWith(currentTabIndex: index);
  }

  void toggleAvailability(bool value) {
    state = state.copyWith(isAvailable: value);
  }
}

final dashboardProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController();
});
