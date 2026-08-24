import 'package:flutter_test/flutter_test.dart';
import 'package:revomaket_app/features/webview/domain/webview_shell_config.dart';

void main() {
  group('WebviewShellConfig', () {
    test('uses buyer tabs on marketplace routes', () {
      final state = WebviewShellConfig.fromPath('/shop');
      expect(state.role, WebviewShellRole.buyer);
      expect(state.tabs, WebviewShellConfig.buyerTabs);
      expect(state.showBack, isFalse);
    });

    test('uses seller tabs on vendor routes', () {
      final state = WebviewShellConfig.fromPath('/vendor/orders');
      expect(state.role, WebviewShellRole.seller);
      expect(state.tabs, WebviewShellConfig.sellerTabs);
      expect(state.title, 'Orders');
    });

    test('uses buyer tabs on marketplace routes even with seller session', () {
      final state = WebviewShellConfig.fromPath(
        '/shop',
        sellerSession: true,
      );
      expect(state.role, WebviewShellRole.buyer);
      expect(state.tabs, WebviewShellConfig.buyerTabs);
    });

    test('falls back to marketplace home from nested vendor pages', () {
      final state = WebviewShellConfig.fromPath('/vendor/settings');
      expect(state.role, WebviewShellRole.seller);
      expect(state.showBack, isTrue);
      expect(
        WebviewShellConfig.fallsBackToMarketplaceHome(state.role),
        isTrue,
      );
    });

    test('shows marketplace back on vendor tab roots', () {
      expect(
        WebviewShellConfig.showMarketplaceBack(
          '/vendor',
          WebviewShellRole.seller,
        ),
        isTrue,
      );
      expect(
        WebviewShellConfig.showMarketplaceBack('/', WebviewShellRole.buyer),
        isFalse,
      );
    });

    test('shows back button on nested pages', () {
      final state = WebviewShellConfig.fromPath('/product/abc');
      expect(state.showBack, isTrue);
      expect(state.title, 'Product');
    });

    test('matches tab prefixes for nested vendor routes', () {
      expect(
        WebviewShellConfig.isTabActive(
          '/vendor/orders/123',
          WebviewShellConfig.sellerTabs[1],
        ),
        isTrue,
      );
    });
  });
}
