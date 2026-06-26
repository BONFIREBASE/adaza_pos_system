import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/domain/activity_log.dart';
import '../../features/activity/presentation/activity_log_modal.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/products/domain/product.dart';
import '../providers.dart';
import '../theme/app_colors.dart';

/// App-bar notification bell: surfaces low/out-of-stock alerts and (for managers)
/// recent audit-log activity, with an unread badge.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canViewLog = user?.can(AppPermission.manageUsers) ?? false;

    final lowStock = ref.watch(lowStockProductsProvider).valueOrNull ?? const [];
    final feed = canViewLog
        ? (ref.watch(activityFeedProvider).valueOrNull ?? const [])
        : const <ActivityLog>[];
    final lastSeen = ref.watch(notificationsSeenProvider);

    final newActivity = feed.where((l) => l.at.isAfter(lastSeen)).length;
    final unread = lowStock.length + newActivity;

    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: AppColors.copper,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () {
        ref.read(notificationsSeenProvider.notifier).markSeen();
        _openPanel(context, lowStock, feed, canViewLog);
      },
    );
  }

  void _openPanel(
    BuildContext context,
    List<Product> lowStock,
    List<ActivityLog> feed,
    bool canViewLog,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (_) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 12, left: 12),
          child: Material(
            color: Colors.transparent,
            child: _NotificationPanel(
              lowStock: lowStock,
              feed: feed,
              canViewLog: canViewLog,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.lowStock,
    required this.feed,
    required this.canViewLog,
  });

  final List<Product> lowStock;
  final List<ActivityLog> feed;
  final bool canViewLog;

  @override
  Widget build(BuildContext context) {
    final recent = feed.take(6).toList();
    final nothing = lowStock.isEmpty && recent.isEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 15)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: nothing
                  ? const _PanelEmpty()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shrinkWrap: true,
                      children: [
                        if (lowStock.isNotEmpty) ...[
                          const _SectionLabel('Needs attention'),
                          for (final p in lowStock.take(6))
                            _AlertTile(product: p),
                          if (lowStock.length > 6)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Text(
                                  '+${lowStock.length - 6} more low on stock',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ),
                        ],
                        if (canViewLog && recent.isNotEmpty) ...[
                          const _SectionLabel('Recent activity'),
                          for (final l in recent)
                            ActivityTile(log: l, dense: true),
                        ],
                      ],
                    ),
            ),
            if (canViewLog) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showActivityLogModal(context);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View full activity log'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = product.stockQuantity <= 0;
    final color = out ? AppColors.error : AppColors.warning;
    final canManage =
        ref.read(currentUserProvider)?.can(AppPermission.manageProducts) ??
            false;

    return InkWell(
      onTap: canManage
          ? () {
              Navigator.pop(context);
              context.go('/products');
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(out ? Icons.error_outline : Icons.warning_amber_rounded,
                size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(out ? 'Out of stock' : '${product.stockQuantity} left',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 40, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text("You're all caught up.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
