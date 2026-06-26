import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/services/xrex_product_text_normalizer.dart';

void main() {
  test('normalizes common snack shelf OCR errors', () {
    expect(
      XRexProductTextNormalizer.normalizeProductName('ÜLKER P9MALK PAKeF'),
      'Ülker Paylaşmalık',
    );
    expect(
      XRexProductTextNormalizer.normalizeProductName('Biscolata Brounie'),
      'Biscolata Brownie',
    );
    expect(
      XRexProductTextNormalizer.normalizeProductName('Darikek DanlCpallay'),
      'Dankek',
    );
    expect(
      XRexProductTextNormalizer.normalizeProductName('Reulokats ken Rleikat'),
      'Rulokat',
    );
  });

  test('builds stable dedupe keys from noisy names', () {
    expect(
      XRexProductTextNormalizer.dedupeKey('Biscolata spscoki İsimsiz ürün'),
      'biscolata',
    );
    expect(
      XRexProductTextNormalizer.dedupeKey('Biscolta Brownıe 9 adet'),
      'biscolata brownie',
    );
  });
}
