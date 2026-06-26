import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/screens/xrex_home_screen.dart';

void main() {
  testWidgets('X-rex home screen opens', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: XRexHomeScreen()));

    expect(find.text('Ürün Listesi'), findsOneWidget);
  });
}
