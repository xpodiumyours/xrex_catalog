import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/xrex_draft_product.dart';

class XRexSupabaseService {
  static final XRexSupabaseService _instance = XRexSupabaseService._internal();

  factory XRexSupabaseService() {
    return _instance;
  }

  XRexSupabaseService._internal();

  // Read credentials from environment variables (dart-define) or default values
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://chfulefxczbgurtgavtp.supabase.co',
  );
  static const String key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_GcCRXDh6vXFGR1UvBFG-3w_x85hvXbN',
  );

  // Upload products list directly to Supabase using a self-healing REST client
  Future<bool> uploadProducts(List<XRexDraftProduct> products) async {
    if (products.isEmpty) return false;

    // Try standard table name 'products' first, with fallback options
    final tableNamesToTry = ['products', 'Supabase_Export', 'urunler'];
    
    for (final tableName in tableNamesToTry) {
      final success = await _attemptUpload(products, tableName: tableName, useTurkishColumns: false);
      if (success) return true;

      // If it failed because of missing column names, retry that table with Turkish columns mapping
      final retrySuccess = await _attemptUpload(products, tableName: tableName, useTurkishColumns: true);
      if (retrySuccess) return true;
    }

    return false;
  }

  // Attempt upload for a specific table name and column mapping
  Future<bool> _attemptUpload(
    List<XRexDraftProduct> products, {
    required String tableName,
    required bool useTurkishColumns,
  }) async {
    final endpoint = Uri.parse('$url/rest/v1/$tableName');
    
    final payload = products.map((p) {
      if (useTurkishColumns) {
        return {
          'urun_adi': p.name.trim(),
          'fiyat': p.price.trim(),
          'aciklama': p.description.trim(),
          'kategori': p.category.trim(),
          'stok_durumu': p.stockStatus.trim(),
        };
      } else {
        return {
          'name': p.name.trim(),
          'price': p.price.trim(),
          'description': p.description.trim(),
          'category': p.category.trim(),
          'stock_status': p.stockStatus.trim(),
        };
      }
    }).toList();

    try {
      final response = await http.post(
        endpoint,
        headers: {
          'apikey': key,
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode(payload),
      );

      // 200 OK or 201 Created indicates successful insert
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (_) {
      // Keep going to fallback or return false
    }
    
    return false;
  }
}
