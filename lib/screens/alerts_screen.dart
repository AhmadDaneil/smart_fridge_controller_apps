import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../models/sensor_data.dart';
import '../theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FridgeProvider>();
    final sensor = provider.sensorData;

    final alerts = <_Alert>[];

    // Sensor alerts
    if (sensor != null && !sensor.isTemperatureNormal) {
      alerts.add(_Alert(
        icon: Icons.thermostat_rounded,
        title: 'Temperature Alert',
        message: sensor.temperatureStatus == TemperatureStatus.tooHot
            ? 'Fridge is too warm (${sensor.temperature.toStringAsFixed(1)}°C). '
              'Items may spoil. Check fridge door seal.'
            : 'Fridge is too cold (${sensor.temperature.toStringAsFixed(1)}°C). '
              'Some items may freeze.',
        severity: AlertSeverity.danger,
        time: sensor.createdAt,
      ));
    }

    // Expired items
    for (final item in provider.items.where((i) => i.isExpired)) {
      alerts.add(_Alert(
        icon: Icons.warning_amber_rounded,
        title: '${item.name} Expired',
        message: '${item.name} expired ${-item.daysUntilExpiry} day(s) ago. '
            'Please remove it from the fridge.',
        severity: AlertSeverity.danger,
        time: item.expiryDate,
      ));
    }

    // Expiring soon
    for (final item in provider.items.where((i) => i.isExpiringSoon)) {
      alerts.add(_Alert(
        icon: Icons.schedule_rounded,
        title: '${item.name} Expiring Soon',
        message: '${item.name} expires in ${item.daysUntilExpiry} day(s). '
            'Consider using it soon.',
        severity: AlertSeverity.warning,
        time: item.expiryDate,
      ));
    }

    // Low weight items
    for (final item in provider.items.where((i) => i.isLowWeight)) {
      alerts.add(_Alert(
        icon: Icons.scale_outlined,
        title: '${item.name} Running Low',
        message: '${item.name} is below 100g (${item.weightGrams.toStringAsFixed(0)}g). '
            'Consider restocking.',
        severity: AlertSeverity.info,
        time: DateTime.now(),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (alerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${alerts.length}'),
                backgroundColor: AppTheme.danger.withOpacity(0.1),
                side: BorderSide.none,
                labelStyle: const TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: alerts.isEmpty
          ? _AllClearView()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AlertCard(alert: alerts[i]),
            ),
    );
  }
}

enum AlertSeverity { danger, warning, info }

class _Alert {
  final IconData icon;
  final String title, message;
  final AlertSeverity severity;
  final DateTime time;

  const _Alert({
    required this.icon, required this.title, required this.message,
    required this.severity, required this.time,
  });

  Color get color => severity == AlertSeverity.danger
      ? AppTheme.danger : severity == AlertSeverity.warning
          ? AppTheme.warning : AppTheme.primary;
}

class _AlertCard extends StatelessWidget {
  final _Alert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: alert.color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: alert.color.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: alert.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(alert.icon, color: alert.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(alert.message,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                    height: 1.4)),
          ],
        )),
      ]),
    );
  }
}

class _AllClearView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.safe.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.safe, size: 44),
        ),
        const SizedBox(height: 20),
        const Text('All Clear!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('No alerts right now.\nYour fridge is in great shape! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
      ]),
    );
  }
}
