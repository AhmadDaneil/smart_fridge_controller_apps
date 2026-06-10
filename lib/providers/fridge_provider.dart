import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fridge_item.dart';
import '../models/sensor_data.dart';
import '../services/supabase_service.dart';

class FridgeProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  List<FridgeItem> _items = [];
  SensorData? _sensorData;
  List<SensorData> _sensorHistory = [];
  bool _loading = false;
  String? _error;

  StreamSubscription? _itemsSub;
  StreamSubscription? _sensorSub;

  List<FridgeItem> get items => _items;
  SensorData? get sensorData => _sensorData;
  List<SensorData> get sensorHistory => _sensorHistory;
  bool get loading => _loading;
  String? get error => _error;

  // ─── Derived counts ────────────────────────────────────────────────────────
  int get expiredCount => _items.where((i) => i.isExpired).length;
  int get expiringSoonCount => _items.where((i) => i.isExpiringSoon).length;
  int get lowWeightCount => _items.where((i) => i.isLowWeight).length;
  bool get hasAlerts => expiredCount > 0 || expiringSoonCount > 0 ||
      (_sensorData != null && !_sensorData!.isTemperatureNormal);

  void init() {
    _loading = true;
    notifyListeners();
    _listenItems();
    _listenSensor();
    _loadHistory();
  }

  void _listenItems() {
    _itemsSub = _service.fridgeItemsStream().listen((items) {
      _items = items;
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    });
  }

  void _listenSensor() {
    _sensorSub = _service.sensorDataStream().listen((data) {
      _sensorData = data;
      notifyListeners();
    });
  }

  Future<void> _loadHistory() async {
    _sensorHistory = await _service.getSensorHistory(limit: 24);
    notifyListeners();
  }

  Future<void> addItem(FridgeItem item) async {
    await _service.addFridgeItem(item);
  }

  Future<void> updateItem(FridgeItem item) async {
    await _service.updateFridgeItem(item);
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteFridgeItem(id);
  }

  Future<void> refresh() async {
    await _loadHistory();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }
}