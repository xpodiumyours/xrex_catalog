import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/services/xrex_supabase_service.dart';

void main() {
  group('XRexSupabaseService Tests', () {
    late XRexSupabaseService service;

    setUp(() {
      service = XRexSupabaseService();
    });

    test('should load credentials correctly from environment/defaults', () {
      expect(XRexSupabaseService.url, isNotEmpty);
      expect(XRexSupabaseService.url.contains('supabase.co'), isTrue);
      expect(XRexSupabaseService.key, isNotEmpty);
    });

    test('should return false gracefully on empty product list', () async {
      final success = await service.uploadProducts([]);
      expect(success, isFalse);
    });
  });
}
