import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/webview_shell_config.dart';

class WebviewNativeBottomNav extends StatelessWidget {
  const WebviewNativeBottomNav({
    super.key,
    required this.path,
    required this.tabs,
    required this.onTabSelected,
  });

  final String path;
  final List<WebviewShellTab> tabs;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14101F41),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _TabItem(
                    tab: tab,
                    active: WebviewShellConfig.isTabActive(path, tab),
                    onTap: () => onTabSelected(tab.path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final WebviewShellTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (active)
              Container(
                height: 2,
                width: 32,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              )
            else
              const SizedBox(height: 6),
            Icon(
              active ? _filledIcon(tab.icon) : tab.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _filledIcon(IconData outline) {
    return switch (outline) {
      Icons.home_outlined => Icons.home,
      Icons.storefront_outlined => Icons.storefront,
      Icons.shopping_cart_outlined => Icons.shopping_cart,
      Icons.person_outline => Icons.person,
      Icons.dashboard_outlined => Icons.dashboard,
      Icons.receipt_long_outlined => Icons.receipt_long,
      Icons.inventory_2_outlined => Icons.inventory_2,
      Icons.account_balance_wallet_outlined => Icons.account_balance_wallet,
      Icons.store_outlined => Icons.store,
      Icons.payments_outlined => Icons.payments,
      Icons.people_outline => Icons.people,
      _ => outline,
    };
  }
}
