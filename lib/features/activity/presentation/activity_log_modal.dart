import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/activity_log.dart';

/// Full, scrollable audit-log viewer (Owner/Admin). Append-only and read-only.
Future<void> showActivityLogModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ActivityLogModal(),
  );
}

class _ActivityLogModal extends ConsumerWidget {
  const _ActivityLogModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.teal),
          const SizedBox(width: 10),
          const Text('Activity log'),
          const Spacer(),
          feed.maybeWhen(
            data: (logs) => Text('${logs.length}',
                style: AppTheme.mono(
                    color: AppColors.textSecondary, fontSize: 13)),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 520,
        child: feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Could not load the activity log.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return const _Empty();
            }
            return ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => ActivityTile(log: logs[i]),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off,
              size: 40, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text('No activity recorded yet.',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// A single audit-log row: icon, summary, actor and relative time.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.log, this.dense = false});

  final ActivityLog log;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = log.kind.isSensitive ? AppColors.copper : AppColors.teal;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(log.kind.icon, size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.summary,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.3)),
                const SizedBox(height: 2),
                Text('${log.actorName} · ${relativeTime(log.at)}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "2m ago" / "3h ago" / date formatting.
String relativeTime(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, h:mm a').format(at);
}
