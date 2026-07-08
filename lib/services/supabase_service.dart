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
  try {
    final response = await _client
        .from('sensor_readings')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return SensorData.fromJson(response);
  } catch (e) {
    print('Error fetching sensor data: $e');
    return null;
  }
}

  /// Stream real-time sensor updates (Supabase Realtime)
  Stream<SensorData> sensorDataStream() {
  return _client
      .from('sensor_readings')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .map((rows) {
        print('Sensor stream received: ${rows.length} rows');  // ADD - debug
        if (rows.isEmpty) return SensorData.empty();
        print('Sensor data: ${rows.first}');                   // ADD - debug
        return SensorData.fromJson(rows.first);
      });
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      // No active session — return empty instead of crashing the app.
      // (Screens should also guard on AuthGate, but this is a safety net.)
      return [];
    }
    final response = await _client
        .from('fridge_items')
        .select()
        .eq('user_id', userId)
        .order('expiry_date', ascending: true);
    return (response as List).map((e) => FridgeItem.fromJson(e)).toList();
  }

  /// Stream real-time inventory updates
  Stream<List<FridgeItem>> fridgeItemsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();
    return _client
        .from('fridge_items')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('expiry_date', ascending: true)
        .map((rows) => rows.map((e) => FridgeItem.fromJson(e)).toList());
  }

  /// Add a new fridge item. Returns the inserted row (including its
  /// database-generated id) so callers can use the real id afterwards
  /// (e.g. to schedule a notification tied to this specific item).
  Future<FridgeItem> addFridgeItem(FridgeItem item) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in to add an item.');
    }
    final data = item.toJson()..['user_id'] = userId;
    final response =
        await _client.from('fridge_items').insert(data).select().single();
    return FridgeItem.fromJson(response);
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