import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/safehouse_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  static const double _neonVaultLat = 4.7068;
  static const double _neonVaultLng = -74.2210;

  // === RAMA: feature/local-storage ===
  // Almacenamiento seguro encriptado para el caché de emergencia
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _cacheKey = 'aegis_safehouses_cache';

  Future<List<Safehouse>> fetchSafehouses() async {
    try {
      final response = await _client
          .from('safehouses')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final safehouses = data
          .map((json) => Safehouse.fromJson(json as Map<String, dynamic>))
          .toList();

      // Guardar en caché encriptado local después de descarga exitosa
      await _saveToCache(safehouses);

      return safehouses;
    } catch (e) {
      throw Exception('Error al conectar con la red de Aegis Vault: $e');
    }
  }

  // Guarda la lista de refugios como JSON encriptado en el dispositivo
  Future<void> _saveToCache(List<Safehouse> safehouses) async {
    final jsonList = safehouses.map((s) => s.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _secureStorage.write(key: _cacheKey, value: jsonString);
  }

  // Lee el caché local encriptado cuando no hay conexión a internet
  Future<List<Safehouse>> fetchFromCache() async {
    final jsonString = await _secureStorage.read(key: _cacheKey);
    if (jsonString == null) return [];
    final List<dynamic> data = jsonDecode(jsonString);
    return data
        .map((json) => Safehouse.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleSafehouseStatus(String id, bool currentStatus) async {
    try {
      await _client
          .from('safehouses')
          .update({'is_compromised': !currentStatus})
          .eq('id', id);
    } catch (e) {
      throw Exception('Error al actualizar el estado del refugio: $e');
    }
  }
}
