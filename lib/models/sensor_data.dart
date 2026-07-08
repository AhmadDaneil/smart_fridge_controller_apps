class SensorData {
  final String id;
  final double temperature;
  final double humidity;
  final bool isDoorOpen;
  final DateTime createdAt;

  SensorData({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.isDoorOpen,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
  return SensorData(
    id: json['id']?.toString() ?? '',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,   // null safe
    humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,          // null safe
    isDoorOpen: json['door_open'] as bool? ?? false,                 // null safe
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now(),
  );
}

  factory SensorData.empty() {
    return SensorData(
      id: '',
      temperature: 0,
      humidity: 0,
      isDoorOpen: false,
      createdAt: DateTime.now(),
    );
  }

  bool get isTemperatureNormal => temperature >= 1.0 && temperature <= 8.0;
  bool get isHumidityNormal => humidity >= 30.0 && humidity <= 80.0;

  TemperatureStatus get temperatureStatus {
    if (temperature < 1.0) return TemperatureStatus.tooCold;
    if (temperature > 8.0) return TemperatureStatus.tooHot;
    return TemperatureStatus.normal;
  }
}

enum TemperatureStatus { tooCold, normal, tooHot }