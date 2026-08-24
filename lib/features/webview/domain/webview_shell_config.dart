import 'package:flutter/material.dart';

/// Which bottom-tab set the native shell should render.
enum WebviewShellRole {
  buyer,
  seller,
  admin,
}

class WebviewShellTab {
  const WebviewShellTab({
    required this.path,
    required this.label,
    required this.icon,
    this.exact = false,
  });

  final String path;
  final String label;
  final IconData icon;

  /// When true, only [path] matches — not nested routes.
  final bool exact;
}

/// Route + chrome state derived from the SPA URL (and optional seller hint).
class WebviewRouteState {
  const WebviewRouteState({
    required this.path,
    required this.role,
    required this.tabs,
    required this.title,
    required this.showBack,
    required this.settingsPath,
  });

  final String path;
  final WebviewShellRole role;
  final List<WebviewShellTab> tabs;
  final String title;
  final bool showBack;
  final String settingsPath;
}

/// Mirrors the tab sets baked into the SPA WebView chrome so Flutter can
/// replace them without changing revo-maket.
class WebviewShellConfig {
  const WebviewShellConfig._();

  static const buyerTabs = <WebviewShellTab>[
    WebviewShellTab(path: '/', label: 'Home', icon: Icons.home_outlined, exact: true),
    WebviewShellTab(path: '/shop', label: 'Shop', icon: Icons.storefront_outlined),
    WebviewShellTab(path: '/cart', label: 'Cart', icon: Icons.shopping_cart_outlined),
    WebviewShellTab(path: '/account', label: 'Account', icon: Icons.person_outline),
  ];

  static const sellerTabs = <WebviewShellTab>[
    WebviewShellTab(path: '/vendor', label: 'Overview', icon: Icons.dashboard_outlined, exact: true),
    WebviewShellTab(path: '/vendor/orders', label: 'Orders', icon: Icons.receipt_long_outlined),
    WebviewShellTab(path: '/vendor/products', label: 'Products', icon: Icons.inventory_2_outlined),
    WebviewShellTab(path: '/vendor/wallet', label: 'Wallet', icon: Icons.account_balance_wallet_outlined),
  ];

  static const adminTabs = <WebviewShellTab>[
    WebviewShellTab(path: '/admin', label: 'Dashboard', icon: Icons.dashboard_outlined, exact: true),
    WebviewShellTab(path: '/admin/vendors', label: 'Vendors', icon: Icons.store_outlined),
    WebviewShellTab(path: '/admin/payouts', label: 'Payouts', icon: Icons.payments_outlined),
    WebviewShellTab(path: '/admin/users', label: 'Users', icon: Icons.people_outline),
  ];

  static const tabRoots = <String>{
    '/',
    '/shop',
    '/cart',
    '/account',
    '/vendor',
    '/vendor/orders',
    '/vendor/products',
    '/vendor/wallet',
    '/admin',
    '/admin/vendors',
    '/admin/payouts',
    '/admin/users',
  };

  static WebviewRouteState fromPath(
    String rawPath, {
    bool sellerSession = false,
  }) {
    final path = _normalizePath(rawPath);
    final role = _roleForPath(path);
    final tabs = switch (role) {
      WebviewShellRole.admin => adminTabs,
      WebviewShellRole.seller => sellerTabs,
      WebviewShellRole.buyer => buyerTabs,
    };

    return WebviewRouteState(
      path: path,
      role: role,
      tabs: tabs,
      title: _titleForPath(path),
      showBack: !tabRoots.contains(path),
      settingsPath: switch (role) {
        WebviewShellRole.admin => '/admin/platform',
        WebviewShellRole.seller => '/vendor/settings',
        WebviewShellRole.buyer => '/account/settings',
      },
    );
  }

  /// Tab roots for vendor/admin should offer a way back to the marketplace.
  static bool showMarketplaceBack(String path, WebviewShellRole role) {
    if (role == WebviewShellRole.buyer) return false;
    return tabRoots.contains(path);
  }

  /// Vendor/admin screens where back should return to marketplace Home
  /// when the WebView has no history entry (common with SPA pushState).
  static bool fallsBackToMarketplaceHome(WebviewShellRole role) {
    return role != WebviewShellRole.buyer;
  }

  static bool isTabActive(String path, WebviewShellTab tab) {
    if (tab.exact) return path == tab.path;
    return path == tab.path || path.startsWith('${tab.path}/');
  }

  static String _normalizePath(String raw) {
    if (raw.isEmpty) return '/';
    final path = raw.split('?').first.split('#').first;
    if (!path.startsWith('/')) return '/$path';
    return path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
  }

  static WebviewShellRole _roleForPath(String path) {
    if (path == '/admin' || path.startsWith('/admin/')) {
      return WebviewShellRole.admin;
    }
    if (path == '/vendor' || path.startsWith('/vendor/')) {
      return WebviewShellRole.seller;
    }
    // Marketplace routes always use buyer chrome, even for registered sellers.
    return WebviewShellRole.buyer;
  }

  static String _titleForPath(String path) {
    const titles = <String, String>{
      '/': 'Home',
      '/shop': 'Shop',
      '/cart': 'Cart',
      '/checkout': 'Checkout',
      '/checkout/success': 'Payment status',
      '/checkout/cancel': 'Checkout cancelled',
      '/account': 'My account',
      '/account/orders': 'My orders',
      '/account/addresses': 'Addresses',
      '/account/wishlist': 'Wishlist',
      '/account/settings': 'Account settings',
      '/account/disputes': 'Disputes',
      '/vendor': 'Seller overview',
      '/vendor/orders': 'Orders',
      '/vendor/products': 'My products',
      '/vendor/wallet': 'Wallet',
      '/vendor/shipments': 'Shipments',
      '/vendor/coupons': 'Coupons',
      '/vendor/activity': 'Activity',
      '/vendor/settings': 'Store settings',
      '/vendor/disputes': 'Disputes',
      '/admin': 'Admin overview',
      '/admin/vendors': 'Vendors',
      '/admin/payouts': 'Payouts',
      '/admin/users': 'Users',
      '/admin/products': 'Products',
      '/admin/platform': 'Platform',
      '/admin/analytics': 'Analytics',
      '/admin/audit': 'Audit',
      '/admin/disputes': 'Disputes',
      '/become-vendor': 'Become a seller',
      '/help': 'Help center',
      '/seller-help': 'Seller help',
    };

    if (titles.containsKey(path)) return titles[path]!;

    final entries = titles.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }

    if (path.startsWith('/product/')) return 'Product';
    if (path.startsWith('/shop/')) return 'Shop';
    return 'Revomaket';
  }
}
