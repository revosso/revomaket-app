import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/webview_shell_config.dart';
import '../../domain/webview_shell_language.dart';

class WebviewNativeAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const WebviewNativeAppBar({
    super.key,
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onSearch,
    required this.onLanguageSelected,
    required this.activeLanguageCode,
    this.userInitial,
    this.isAuthenticated = false,
    this.showDashboardSwitcher = false,
    this.role = WebviewShellRole.buyer,
    this.onNavigate,
    this.onLogout,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final ValueChanged<String> onLanguageSelected;
  final String activeLanguageCode;
  final String? userInitial;
  final bool isAuthenticated;
  final bool showDashboardSwitcher;
  final WebviewShellRole role;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  WebviewShellLanguage get _activeLanguage =>
      WebviewShellLanguage.findByCode(activeLanguageCode) ??
      WebviewShellLanguage.supported[2];

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      centerTitle: true,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: onBack,
            )
          : const SizedBox(width: 8),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: onSearch,
        ),
        _LanguageButton(
          language: _activeLanguage,
          onSelected: onLanguageSelected,
        ),
        if (showDashboardSwitcher && onNavigate != null)
          _DashboardButton(role: role, onNavigate: onNavigate!),
        if (isAuthenticated && onNavigate != null && onLogout != null)
          _ProfileButton(
            initial: userInitial ?? '?',
            onNavigate: onNavigate!,
            onLogout: onLogout!,
          )
        else
          const SizedBox(width: 4),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.language,
    required this.onSelected,
  });

  final WebviewShellLanguage language;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Language',
      offset: const Offset(0, 44),
      color: AppColors.surface,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final lang in WebviewShellLanguage.supported)
          PopupMenuItem(
            value: lang.code,
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.label,
                    style: TextStyle(
                      fontWeight: lang.code == language.code
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 16)),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  const _DashboardButton({
    required this.role,
    required this.onNavigate,
  });

  final WebviewShellRole role;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Dashboard',
      offset: const Offset(0, 44),
      color: AppColors.surface,
      icon: Icon(
        switch (role) {
          WebviewShellRole.admin => Icons.admin_panel_settings_outlined,
          WebviewShellRole.seller => Icons.dashboard_outlined,
          WebviewShellRole.buyer => Icons.storefront_outlined,
        },
      ),
      onSelected: onNavigate,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '/',
          child: _MenuRow(
            icon: Icons.storefront_outlined,
            label: 'Shop',
          ),
        ),
        const PopupMenuItem(
          value: '/vendor',
          child: _MenuRow(
            icon: Icons.dashboard_outlined,
            label: 'My Store Dashboard',
          ),
        ),
        if (role == WebviewShellRole.admin)
          const PopupMenuItem(
            value: '/admin',
            child: _MenuRow(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Dashboard',
            ),
          ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.initial,
    required this.onNavigate,
    required this.onLogout,
  });

  final String initial;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      color: AppColors.surface,
      onSelected: (value) {
        if (value == 'logout') {
          onLogout();
        } else {
          onNavigate(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '/account',
          child:
              Text('Account', style: TextStyle(color: AppColors.textPrimary)),
        ),
        const PopupMenuItem(
          value: '/account/orders',
          child:
              Text('My Orders', style: TextStyle(color: AppColors.textPrimary)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            destructive: true,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
