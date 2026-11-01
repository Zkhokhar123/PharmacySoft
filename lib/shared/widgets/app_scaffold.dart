import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../state/core_providers.dart';

/// A navigation destination shown in the sidebar. Order must match the route
/// branch order in the ShellRoute.
class NavItem {
  final String label;
  final IconData icon;
  final String path;
  const NavItem(this.label, this.icon, this.path);
}

const _navItems = <NavItem>[
  NavItem('Dashboard',     Icons.dashboard_outlined,        '/dashboard'),
  NavItem('Inventory',     Icons.medication_outlined,       '/inventory'),
  NavItem('New Sale',      Icons.point_of_sale_outlined,    '/pos'),
  NavItem('Sales History', Icons.receipt_long_outlined,     '/sales'),
  NavItem('Purchases',     Icons.inventory_2_outlined,      '/purchases'),
  NavItem('Customers',     Icons.people_outlined,           '/customers'),
  NavItem('Suppliers',     Icons.local_shipping_outlined,   '/suppliers'),
  NavItem('Categories',    Icons.category_outlined,         '/categories'),
  NavItem('Expenses',      Icons.account_balance_wallet_outlined, '/expenses'),
  NavItem('Reports',       Icons.assessment_outlined,       '/reports'),
  NavItem('Settings',      Icons.settings_outlined,         '/settings'),
];

/// The persistent app shell: a teal sidebar plus the routed screen content.
class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacy = ref.watch(settingsProvider).pharmacyName;
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            pharmacyName: pharmacy,
            currentIndex: navigationShell.currentIndex,
            onSelect: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String pharmacyName;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.pharmacyName,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width >= 1100 ? 248.0 : 72.0;
    final expanded = width > 100;
    return Container(
      width: width,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_pharmacy,
                        color: Colors.white, size: 22),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        pharmacyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 28),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  final item = _navItems[i];
                  final selected = i == currentIndex;
                  return _NavTile(
                    item: item,
                    selected: selected,
                    expanded: expanded,
                    onTap: () => onSelect(i),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                expanded ? 'v${AppConstants.appVersion}' : 'v',
                style: const TextStyle(color: AppColors.sidebarText, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 8,
        vertical: 4,
      ),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.85)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 14 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(item.icon,
                    size: 22,
                    color: selected
                        ? Colors.white
                        : AppColors.sidebarText),
                if (expanded) ...[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.sidebarText,
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
