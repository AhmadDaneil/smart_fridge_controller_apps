import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fridge_item.dart';
import '../models/sensor_data.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

class FridgeProvider extends ChangeNotifier {
  final SupabaseService _service = SupabaseService();

  List<FridgeItem> _items = [];
  SensorData? _sensorData;
  List<SensorData> _sensorHistory = [];
  bool _loading = false;
  String? _error;

  StreamSubscription? _itemsSub;
  StreamSubscription? _sensorSub;
  Timer? _doorAlertTicker;

  // Tracks when the door was last seen transitioning to "open" so we can
  // tell how long it's been open. This is in-memory only — it resets if
  // the app is fully closed and reopened while the door happens to still
  // be open, which is an acceptable limitation without a dedicated
  // "door_opened_at" timestamp column from the ESP32.
  DateTime? _doorOpenedAt;

  /// How long the door has been continuously open, or null if it's closed.
  Duration? get doorOpenDuration =>
      _doorOpenedAt == null ? null : DateTime.now().difference(_doorOpenedAt!);

  /// Door is considered "left open too long" past this duration.
  static const doorOpenAlertThreshold = Duration(minutes: 2);

  List<FridgeItem> get items => _items;
  SensorData? get sensorData => _sensorData;
  List<SensorData> get sensorHistory => _sensorHistory;
  bool get loading => _loading;
  String? get error => _error;

  // ─── Derived counts ────────────────────────────────────────────────────────
  int get expiredCount => _items.where((i) => i.isExpired).length;
  int get expiringSoonCount => _items.where((i) => i.isExpiringSoon).length;
  bool get isDoorLeftOpen =>
      doorOpenDuration != null && doorOpenDuration! >= doorOpenAlertThreshold;
  bool get hasAlerts => expiredCount > 0 || expiringSoonCount > 0 ||
      isDoorLeftOpen ||
      (_sensorData != null && !_sensorData!.isTemperatureNormal);

  void init() {
    _loading = true;
    notifyListeners();
    _listenItems();
    _listenSensor();
    _loadHistory();

    // Re-check door-open duration every 30s so "left open too long" alerts
    // appear even if no new sensor reading has come in yet.
    _doorAlertTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_doorOpenedAt != null) notifyListeners();
    });
  }

  void _checkImmediateAlerts(List<FridgeItem> items) {
  for (final item in items) {
    if (item.isExpired) {
      NotificationService().showImmediateNotification(
        id: item.id,
        title: '🚨 ${item.name} has expired!',
        body: 'Expired ${-item.daysUntilExpiry} day(s) ago. Please remove it.',
      );
    } else if (item.isExpiringSoon) {
      NotificationService().showImmediateNotification(
        id: item.id,
        title: '⏰ ${item.name} expiring soon',
        body: 'Expires in ${item.daysUntilExpiry} day(s). Use it up!',
      );
    }
  }
}

  void _listenItems() {
  // Fetch immediately on init
  _service.getFridgeItems().then((items) {
    _items = items;
    _loading = false;
    _checkImmediateAlerts(items); 
    notifyListeners();
  });

  // Then keep listening for realtime changes
  _itemsSub = _service.fridgeItemsStream().listen((items) {
    _items = items;
    _loading = false;
    _checkImmediateAlerts(items); 
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
      _trackDoorState(data.isDoorOpen);
      notifyListeners();
    });
  }

  void _trackDoorState(bool isOpen) {
    if (isOpen && _doorOpenedAt == null) {
      _doorOpenedAt = DateTime.now();
    } else if (!isOpen) {
      _doorOpenedAt = null;
    }
  }

  Future<void> _loadHistory() async {
    _sensorHistory = await _service.getSensorHistory(limit: 24);
    notifyListeners();
  }

  Future<void> addItem(FridgeItem item) async {
    final saved = await _service.addFridgeItem(item);
    await NotificationService().scheduleExpiryReminder(saved);
    await NotificationService().scheduleExpiryReminder(item);
  }

  Future<void> updateItem(FridgeItem item) async {
    await _service.updateFridgeItem(item);
    // Reschedule in case the expiry date changed.
    await NotificationService().scheduleExpiryReminder(item);
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteFridgeItem(id);
    await NotificationService().cancelReminder(id);
    await refresh();
  }

  Future<void> refresh() async {
    final items = await _service.getFridgeItems();
    _items = items;
    notifyListeners();
    await _loadHistory();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _sensorSub?.cancel();
    _doorAlertTicker?.cancel();
    super.dispose();
  }
}