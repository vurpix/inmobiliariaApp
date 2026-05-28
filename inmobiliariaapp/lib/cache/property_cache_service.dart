import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PropertyCacheService {
  static const String _key = 'pending_property_registration';

  // Guardar mapa de datos (incluye paths de imágenes y strings)
  static Future<void> saveProgress(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  // Obtener progreso
  static Future<Map<String, dynamic>?> getProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    return data != null ? jsonDecode(data) : null;
  }

  // Limpiar al finalizar el pago
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}