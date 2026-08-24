import 'package:flutter_test/flutter_test.dart';
import 'package:revomaket_app/features/webview/services/webview_vendor_access_service.dart';

void main() {
  group('WebviewVendorAccessService', () {
    test('allows dashboard for seller role', () {
      expect(
        WebviewVendorAccessService.canAccessFromProfile({
          'roles': ['SELLER'],
          'businessAccounts': [],
        }),
        isTrue,
      );
    });

    test('allows dashboard for business account owner', () {
      expect(
        WebviewVendorAccessService.canAccessFromProfile({
          'roles': ['BUYER'],
          'businessAccounts': [
            {
              'id': 'biz-1',
              'capabilities': {'effectiveCanSell': false},
            },
          ],
        }),
        isTrue,
      );
    });

    test('allows dashboard when effectiveCanSell is true', () {
      expect(
        WebviewVendorAccessService.canAccessFromProfile({
          'roles': ['BUYER'],
          'businessAccounts': [
            {
              'id': 'biz-1',
              'capabilities': {'effectiveCanSell': true},
            },
          ],
        }),
        isTrue,
      );
    });

    test('denies dashboard for plain buyer', () {
      expect(
        WebviewVendorAccessService.canAccessFromProfile({
          'roles': ['BUYER'],
          'businessAccounts': [],
        }),
        isFalse,
      );
    });
  });
}
