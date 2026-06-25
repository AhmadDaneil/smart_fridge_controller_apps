import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fridge_item.dart';
import '../models/sensor_data.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ─── SENSOR DATA ────────────────────────────────────────────────────────────

  /// Fetch latest sensor reading from ESP32
  Future<SensorData?> getLatestSensorData() async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return SensorData.fromJson(response);
  }

  /// Stream real-time sensor updates (Supabase Realtime)
  Stream<SensorData> sensorDataStream() {
    return _client
        .from('sensor_readings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((rows) => rows.isEmpty ? SensorData.empty() : SensorData.fromJson(rows.first));
  }

  /// Fetch last N sensor readings for chart
  Future<List<SensorData>> getSensorHistory({int limit = 24}) async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List).map((e) => SensorData.fromJson(e)).toList().reversed.toList();
  }

  // ─── FRIDGE ITEMS ────────────────────────────────────────────────────────────

  /// Get all fridge items for current user
  Future<List<FridgeItem>> getFridgeItems() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('fridge_items')
        .select()
        .eq('user_id', userId)
        .order('expiry_date', ascending: true);
    return (response as List).map((e) => FridgeItem.fromJson(e)).toList();
  }

  /// Stream real-time inventory updates
  Stream<List<FridgeItem>> fridgeItemsStream() {
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('fridge_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('expiry_date', ascending: true)
        .map((rows) => rows.map((e) => FridgeItem.fromJson(e)).toList());
  }

  /// Add a new fridge item
  Future<void> addFridgeItem(FridgeItem item) async {
    await _client.from('fridge_items').insert(item.toJson());
  }

  /// Update fridge item
  Future<void> updateFridgeItem(FridgeItem item) async {
    await _client
        .from('fridge_items')
        .update(item.toJson())
        .eq('id', item.id);
  }

  /// Delete fridge item
  Future<void> deleteFridgeItem(String id) async {
    await _client.from('fridge_items')
      .delete()
      .eq('id', int.parse(id));
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────────

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
