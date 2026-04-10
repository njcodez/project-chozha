// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/jobs_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/job_card.dart';
import '../widgets/error_snackbar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void _loadAll() {
    final username = ref.read(usernameProvider);
    ref.read(jobListProvider.notifier).load(username: username);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Chozha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'My Work'),
            Tab(text: 'Public Feed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MyWorkTab(),
          _PublicFeedTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/upload'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Upload'),
      ),
    );
  }
}

// ── My Work ─────────────────────────────────────────────────────────────────

class _MyWorkTab extends ConsumerWidget {
  const _MyWorkTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(usernameProvider);
    final jobsAsync = ref.watch(jobListProvider);

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref
            .read(jobListProvider.notifier)
            .load(username: username),
      ),
      data: (items) {
        final mine = items.where((j) => j.username == username).toList();
        if (mine.isEmpty) return const _EmptyView(message: 'No uploads yet');
        return RefreshIndicator(
          onRefresh: () => ref
              .read(jobListProvider.notifier)
              .load(username: username),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: mine.length,
            itemBuilder: (ctx, i) => JobCard(
              item: mine[i],
              onTap: () => ctx.push('/job/${mine[i].jobId}'),
            ),
          ),
        );
      },
    );
  }
}

// ── Public Feed ──────────────────────────────────────────────────────────────

class _PublicFeedTab extends ConsumerWidget {
  const _PublicFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedAsync = ref.watch(sortedFeedProvider);
    final sort = ref.watch(feedSortProvider);

    return Column(
      children: [
        // Sort toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              const Text('Sort:'),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Newest'),
                selected: sort == FeedSort.newest,
                onSelected: (_) => ref.read(feedSortProvider.notifier).state =
                    FeedSort.newest,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('By User'),
                selected: sort == FeedSort.byUsername,
                onSelected: (_) => ref.read(feedSortProvider.notifier).state =
                    FeedSort.byUsername,
              ),
            ],
          ),
        ),
        Expanded(
          child: sortedAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.read(jobListProvider.notifier).load(),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyView(message: 'No public jobs yet');
              }
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(jobListProvider.notifier).load(),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => JobCard(
                    item: items[i],
                    showUsername: true,
                    onTap: () => ctx.push('/job/${items[i].jobId}'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
