import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_colors.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/export/export_modal.dart';
import '../../features/profile/presentation/profile_modals.dart';
import '../../features/profile/presentation/settings_modal.dart';
import '../../features/profile/presentation/user_avatar.dart';

typedef _Dest = ({
  String route,
  IconData icon,
  String label,
  AppPermission permission,
});

/// Minimalist shell with the primary destinations reachable from any screen
/// (Req 9.2, 9.4) via a floating bottom dock. Destinations are filtered by the
/// current user's role so navigation only shows what they can access (Req 1.5).
class AppNavScaffold extends ConsumerWidget {
  const AppNavScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentRoute,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final String? currentRoute;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const List<_Dest> _destinations = [
    (
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      permission: AppPermission.viewDashboard,
    ),
    (
      route: '/products',
      icon: Icons.inventory_2_outlined,
      label: 'Products',
      permission: AppPermission.manageProducts,
    ),
    (
      route: '/labels',
      icon: Icons.barcode_reader,
      label: 'Labels',
      permission: AppPermission.manageProducts,
    ),
    (
      route: '/sales',
      icon: Icons.point_of_sale_outlined,
      label: 'Sales',
      permission: AppPermission.recordSales,
    ),
    (
      route: '/finance',
      icon: Icons.savings_outlined,
      label: 'Finance',
      permission: AppPermission.manageFinance,
    ),
    (
      route: '/management',
      icon: Icons.manage_accounts_outlined,
      label: 'Manage',
      permission: AppPermission.manageUsers,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final destinations =
        _destinations.where((d) => user?.can(d.permission) ?? false).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          if (user != null) _ProfileMenu(user: user),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: destinations.length >= 2
          ? _Dock(destinations: destinations, currentRoute: currentRoute)
          : null,
      body: body,
    );
  }
}

/// Floating, rounded bottom dock of navigation destinations.
class _Dock extends StatelessWidget {
  const _Dock({required this.destinations, required this.currentRoute});

  final List<_Dest> destinations;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in destinations)
                      _DockItem(
                        dest: d,
                        selected: currentRoute != null &&
                            currentRoute!.startsWith(d.route),
                        onTap: () => context.go(d.route),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16 : 14,
          vertical: 10,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dest.icon,
              size: 22,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            // Show the label only on the selected item for a compact dock.
            if (selected) ...[
              const SizedBox(width: 8),
              Text(
                dest.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// App-bar profile dropdown: avatar + name, with edit profile, change password,
/// export, settings and sign out.
class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canExport = user.can(AppPermission.manageFinance);
    final isOwner = user.isOwner;
    final compact = MediaQuery.sizeOf(context).width < 560;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'profile':
            showEditProfileModal(context, user);
          case 'password':
            showChangePasswordModal(context);
          case 'export':
            showExportModal(context);
          case 'settings':
            showSettingsModal(context);
          case 'about':
            showAboutModal(context);
          case 'signout':
            ref.read(authRepositoryProvider).signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              UserAvatar(user: user, radius: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(user.roleLabel,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Edit profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'password',
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Change password'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (canExport)
          const PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('Reports'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (isOwner)
          const PopupMenuItem(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'about',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'signout',
          child: ListTile(
            leading: Icon(Icons.logout, color: AppColors.error),
            title: Text('Sign out'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(user: user, radius: 16),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(user.displayName,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ],
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
