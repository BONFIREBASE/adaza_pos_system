import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/domain/app_user.dart';
import '../../finance/domain/finance_record.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';

final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// Lays stat cards out in a responsive grid that fills each row evenly.
Widget _grid(List<Widget> cards) {
  return LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1100 ? 3 : (w >= 680 ? 2 : 1);
      const gap = 16.0;
      final cardW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: cardW, child: card),
        ],
      );
    },
  );
}

/// Business-at-a-glance summary (Req 7).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesRepo = ref.watch(saleRepositoryProvider);
    final productRepo = ref.watch(productRepositoryProvider);
    final financeRepo = ref.watch(financeRepositoryProvider);
    final user = ref.watch(currentUserProvider);

    return AppNavScaffold(
      title: 'Dashboard',
      currentRoute: '/dashboard',
      body: (salesRepo == null || productRepo == null || financeRepo == null)
          ? const _DashboardSkeleton()
          : StreamBuilder<List<Sale>>(
              stream: salesRepo.watchSales(),
              builder: (context, salesSnap) {
                return StreamBuilder<List<Product>>(
                  stream: productRepo.watchProducts(),
                  builder: (context, prodSnap) {
                    return StreamBuilder<List<FinanceRecord>>(
                      stream: financeRepo.watchRecords(),
                      builder: (context, finSnap) {
                        final loading = !salesSnap.hasData ||
                            !prodSnap.hasData ||
                            !finSnap.hasData;
                        if (loading) return const _DashboardSkeleton();
                        return _DashboardBody(
                          sales: salesSnap.data!,
                          products: prodSnap.data!,
                          records: finSnap.data!,
                          user: user,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.sales,
    required this.products,
    required this.records,
    required this.user,
  });

  final List<Sale> sales;
  final List<Product> products;
  final List<FinanceRecord> records;
  final AppUser? user;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStartDay = today.subtract(Duration(days: now.weekday - 1));

    double daySales = 0, weekSales = 0, yesterdaySales = 0;
    int dayTxns = 0;
    for (final s in sales) {
      if (_sameDay(s.createdAt, now)) {
        daySales += s.total;
        dayTxns++;
      }
      if (_sameDay(s.createdAt, yesterday)) yesterdaySales += s.total;
      if (!s.createdAt.isBefore(weekStartDay)) weekSales += s.total;
    }

    double profit(bool Function(DateTime) inRange) {
      double income = 0, expense = 0;
      for (final r in records) {
        if (!inRange(r.date)) continue;
        if (r.type == FinanceType.income) {
          income += r.amount;
        } else {
          expense += r.amount;
        }
      }
      return income - expense;
    }

    final dayProfit = profit((d) => _sameDay(d, now));
    final weekProfit = profit((d) => !d.isBefore(weekStartDay));
    final dayTrend = _trend(daySales, yesterdaySales);

    final lowStock = products.where((p) => p.isLowStock).toList();
    final inventoryValue =
        products.fold<double>(0, (sum, p) => sum + p.price * p.stockQuantity);

    final daily = List<double>.filled(7, 0);
    for (final s in sales) {
      final diff = today
          .difference(
              DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day))
          .inDays;
      if (diff >= 0 && diff < 7) daily[6 - diff] += s.total;
    }

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(user: user, now: now),
        const SizedBox(height: 20),
        _grid([
          _StatCard(
            label: 'Sales today',
            value: _money.format(daySales),
            icon: Icons.today,
            color: AppColors.teal,
            trend: dayTrend,
          ),
          _StatCard(
            label: 'Profit today',
            value: _money.format(dayProfit),
            icon: Icons.trending_up,
            color: AppColors.gold,
          ),
          _StatCard(
            label: 'Sales this week',
            value: _money.format(weekSales),
            icon: Icons.calendar_view_week,
            color: AppColors.copper,
          ),
          _StatCard(
            label: 'Profit this week',
            value: _money.format(weekProfit),
            icon: Icons.savings_outlined,
            color: AppColors.bronze,
          ),
          _StatCard(
            label: 'Transactions today',
            value: '$dayTxns',
            icon: Icons.receipt_long_outlined,
            color: AppColors.tealDark,
          ),
          _StatCard(
            label: 'Inventory value',
            value: _money.format(inventoryValue),
            icon: Icons.inventory_2_outlined,
            color: AppColors.teal,
          ),
        ]),
        const SizedBox(height: 20),
        Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: isWide ? 3 : 0,
              child: _Panel(
                title: 'Sales — last 7 days',
                child: _WeeklySalesChart(daily: daily, today: today),
              ),
            ),
            SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
            Expanded(
              flex: isWide ? 2 : 0,
              child: _Panel(
                title: 'Recent sales',
                child: _RecentSales(sales: sales.take(6).toList()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Low stock',
          trailing: lowStock.isEmpty
              ? null
              : Text('${lowStock.length}',
                  style: AppTheme.mono(
                      fontWeight: FontWeight.w700, color: AppColors.warning)),
          child: _LowStock(items: lowStock),
        ),
      ],
    );
  }

  double? _trend(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : null;
    return ((current - previous) / previous) * 100;
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.now});
  final AppUser? user;
  final DateTime now;

  String get _greeting {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting${user != null ? ',' : ''}',
                  style: Theme.of(context).textTheme.titleLarge),
              if (user != null)
                Text(user!.email,
                    style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text(DateFormat('EEE, MMM d').format(now),
            style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (trend != null) ...[
              const SizedBox(width: 8),
              _TrendBadge(percent: trend!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text('${percent.abs().toStringAsFixed(0)}%',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _WeeklySalesChart extends StatelessWidget {
  const _WeeklySalesChart({required this.daily, required this.today});
  final List<double> daily;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final max = daily.fold<double>(0, (m, v) => v > m ? v : m);
    final hasData = max > 0;

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < daily.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      hasData && daily[i] > 0 ? _money.format(daily[i]) : '',
                      style: AppTheme.mono(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor:
                              hasData ? (daily[i] / max).clamp(0.02, 1.0) : 0.02,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.teal, AppColors.tealDark],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E')
                          .format(today.subtract(Duration(days: 6 - i))),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentSales extends StatelessWidget {
  const _RecentSales({required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No sales yet.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    final fmt = DateFormat('MMM d, h:mm a');
    return Column(
      children: [
        for (final s in sales)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.creamSurface,
              child: Icon(Icons.point_of_sale_outlined,
                  size: 16, color: AppColors.teal),
            ),
            title:
                Text('${s.lines.length} item${s.lines.length == 1 ? '' : 's'}'),
            subtitle: Text(fmt.format(s.createdAt)),
            trailing: Text(_money.format(s.total),
                style: AppTheme.mono(
                    fontWeight: FontWeight.w700, color: AppColors.teal)),
          ),
      ],
    );
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.items});
  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 10),
          Text('All products are well stocked.'),
        ],
      );
    }
    return Column(
      children: [
        for (final p in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.warning_amber, color: AppColors.warning),
            title: Text(p.name),
            subtitle: Text('Threshold ${p.lowStockThreshold}'),
            trailing: Text(
              '${p.stockQuantity} left',
              style: AppTheme.mono(
                  fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
            onTap: () => context.go('/products'),
          ),
      ],
    );
  }
}

/// Shimmer skeleton shown while the dashboard data loads.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Skeleton(width: 220, height: 24),
        const SizedBox(height: 10),
        const Skeleton(width: 160, height: 14),
        const SizedBox(height: 20),
        _grid(List.generate(6, (_) => const SkeletonStatCard())),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 160, height: 18),
                SizedBox(height: 20),
                Skeleton(height: 180, radius: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
