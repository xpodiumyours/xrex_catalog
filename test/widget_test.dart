import 'package:flutter_test/flutter_test.dart';

import 'package:xrex_catalog/main.dart';

void main() {
  testWidgets('X-rex home screen opens', (WidgetTester tester) async {
    await tester.pumpWidget(const XRexCatalogApp());

    expect(find.text('X-rex'), findsOneWidget);
    expect(find.text('Ürün fotoğrafı'), findsOneWidget);
    expect(find.text('Fotoğraf yükle'), findsOneWidget);
  });
}
