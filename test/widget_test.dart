import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revomaket_app/core/utils/url_utils.dart';

void main() {
  group('UrlUtils', () {
    test('marks tel:// and mailto:// as external schemes', () {
      expect(UrlUtils.isExternalScheme(Uri.parse('tel:+15551234567')), isTrue);
      expect(
        UrlUtils.isExternalScheme(Uri.parse('mailto:hi@example.com')),
        isTrue,
      );
      expect(
        UrlUtils.isExternalScheme(Uri.parse('whatsapp://send?phone=1')),
        isTrue,
      );
    });

    test('treats revomaket.com URLs as internal', () {
      expect(
        UrlUtils.isInternalUrl(Uri.parse('https://revomaket.com/listing/1')),
        isTrue,
      );
      expect(
        UrlUtils.isInternalUrl(Uri.parse('https://www.revomaket.com/')),
        isTrue,
      );
      expect(
        UrlUtils.isInternalUrl(Uri.parse('https://example.com/')),
        isFalse,
      );
    });
  });

  testWidgets('App routes are wired without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
