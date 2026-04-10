// lib/widgets/job_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/job_list_item.dart';
import '../providers/settings_provider.dart';
import 'status_chip.dart';

class JobCard extends ConsumerWidget {
  final JobListItem item;
  final bool showUsername;
  final VoidCallback onTap;

  const JobCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showUsername = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final createdAt = DateTime.tryParse(item.createdAt) ?? DateTime.now();
    final baseUrl = ref.watch(backendUrlProvider).valueOrNull ?? '';
    final imageUrl = '$baseUrl/jobs/${item.jobId}/input';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: cs.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: cs.surfaceContainer),
                errorWidget: (_, __, ___) => Container(
                  color: cs.surfaceContainer,
                  child: Icon(Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title ?? 'Untitled',
                          style: ts.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showUsername
                        ? '${item.username} · ${timeago.format(createdAt)}'
                        : timeago.format(createdAt),
                    style: ts.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}