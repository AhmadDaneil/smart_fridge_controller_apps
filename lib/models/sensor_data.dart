class SensorData {
  final String id;
  final double temperature;
  final double humidity;
  final double totalWeightGrams;
  final DateTime createdAt;

  SensorData({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.totalWeightGrams,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'].toString(),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      totalWeightGrams: (json['total_weight_grams'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory SensorData.empty() {
    return SensorData(
      id: '',
      temperature: 0,
      humidity: 0,
      totalWeightGrams: 0,
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