// lib/providers/jobs_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../models/job_list_item.dart';
import '../config/constants.dart';
import 'api_provider.dart';

// ── Job List ────────────────────────────────────────────────────────────────

class JobListNotifier extends AsyncNotifier<List<JobListItem>> {
  String? _username; // null = public feed

  @override
  Future<List<JobListItem>> build() async => [];

  Future<void> load({String? username}) async {
    _username = username;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => requireApi(ref).getJobs(username: username),
    );
  }

  Future<void> refresh() => load(username: _username);
}

final jobListProvider =
    AsyncNotifierProvider<JobListNotifier, List<JobListItem>>(
  JobListNotifier.new,
);

// ── Public Feed Sort ────────────────────────────────────────────────────────

enum FeedSort { newest, byUsername }

final feedSortProvider = StateProvider<FeedSort>((_) => FeedSort.newest);

/// Derived: sorted public feed
final sortedFeedProvider = Provider<AsyncValue<List<JobListItem>>>((ref) {
  final listAsync = ref.watch(jobListProvider);
  final sort = ref.watch(feedSortProvider);
  return listAsync.whenData((items) {
    final copy = [...items];
    if (sort == FeedSort.newest) {
      copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      copy.sort((a, b) => a.username.compareTo(b.username));
    }
    return copy;
  });
});

// ── Job Detail + Polling ────────────────────────────────────────────────────

class JobDetailNotifier extends AutoDisposeAsyncNotifier<Job> {
  Timer? _timer;
  late String _jobId;

  @override
  Future<Job> build() async {
    ref.onDispose(_stopPolling);
    throw UnimplementedError();
  }

  Future<void> load(String jobId) async {
    _jobId = jobId;
    state = const AsyncLoading();
    await _fetch();
    if (!(state.valueOrNull?.isTerminal ?? false)) {
      _startPolling();
    }
  }

  Future<void> _fetch() async {
    state = await AsyncValue.guard(
      () => requireApi(ref).getJob(_jobId),
    );
    if (state.valueOrNull?.isTerminal ?? false) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(kPollInterval, (_) => _fetch());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> saveMetadata({
    String? title,
    String? description,
    bool? isPublic,
  }) async {
    final updated = await requireApi(ref).updateJob(
      _jobId,
      title: title,
      description: description,
      isPublic: isPublic,
    );
    state = AsyncData(updated);
  }

  Future<void> deleteJob(String masterPassword) async {
    await requireApi(ref).deleteJob(_jobId, masterPassword);
  }

}

final jobDetailProvider =
    AsyncNotifierProvider.autoDispose<JobDetailNotifier, Job>(
  JobDetailNotifier.new,
);
