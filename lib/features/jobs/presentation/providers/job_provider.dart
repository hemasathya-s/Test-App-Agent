import 'package:flutter_riverpod/legacy.dart';

enum JobStatus {
  none,
  offered,
  accepted,
  navigating,
  inProgress,
  completed,
  cancelled,
}

class JobState {
  final JobStatus status;
  final String? currentJobId;
  final int offerTimer; // Seconds remaining for offer

  const JobState({
    this.status = JobStatus.none,
    this.currentJobId,
    this.offerTimer = 30,
  });

  JobState copyWith({
    JobStatus? status,
    String? currentJobId,
    int? offerTimer,
  }) {
    return JobState(
      status: status ?? this.status,
      currentJobId: currentJobId ?? this.currentJobId,
      offerTimer: offerTimer ?? this.offerTimer,
    );
  }
}

class JobController extends StateNotifier<JobState> {
  JobController() : super(const JobState());

  void receiveJobOffer(String jobId) {
    state = state.copyWith(
      status: JobStatus.offered,
      currentJobId: jobId,
      offerTimer: 30,
    );
    // Start timer logic would go here
  }

  void acceptJob() {
    state = state.copyWith(status: JobStatus.accepted);
  }

  void startNavigation() {
    state = state.copyWith(status: JobStatus.navigating);
  }

  void arriveAtLocation() {
    // Transition to ready to start
  }

  void startJob() {
    state = state.copyWith(status: JobStatus.inProgress);
  }

  void completeJob() {
    state = state.copyWith(status: JobStatus.completed);
  }

  void rejectJob() {
    state = state.copyWith(status: JobStatus.none, currentJobId: null);
  }
}

final jobProvider = StateNotifierProvider<JobController, JobState>((ref) {
  return JobController();
});
