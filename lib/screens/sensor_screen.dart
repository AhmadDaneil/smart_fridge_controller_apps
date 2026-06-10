import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/fridge_provider.dart';
import '../models/sensor_data.dart';
import '../theme.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FridgeProvider>();
    final sensor = provider.sensorData;
    final history = provider.sensorHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live readings banner
          if (sensor != null) ...[
            _LiveBanner(sensor: sensor),
            const SizedBox(height: 20),
          ],

          // Temperature chart
          _ChartCard(
            title: 'Temperature (°C)',
            subtitle: 'Ideal range: 1–8°C',
            icon: Icons.thermostat_rounded,
            color: AppTheme.primary,
            spots: history.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), e.value.temperature)).toList(),
            minY: -5, maxY: 20,
            safeMin: 1, safeMax: 8,
          ),

          const SizedBox(height: 16),

          // Humidity chart
          _ChartCard(
            title: 'Humidity (%)',
            subtitle: 'Ideal range: 30–80%',
            icon: Icons.water_drop_outlined,
            color: Colors.blue.shade600,
            spots: history.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), e.value.humidity)).toList(),
            minY: 0, maxY: 100,
            safeMin: 30, safeMax: 80,
          ),

          const SizedBox(height: 16),

          // Weight chart
          _ChartCard(
            title: 'Total Weight (g)',
            subtitle: 'All items combined',
            icon: Icons.scale_outlined,
            color: Colors.orange.shade700,
            spots: history.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), e.value.totalWeightGrams)).toList(),
            minY: 0, maxY: null,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  final SensorData sensor;

  const _LiveBanner({required this.sensor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text('LIVE', style: TextStyle(color: Colors.white70,
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const Spacer(),
            Text(
              DateFormat('HH:mm').format(sensor.createdAt),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _LiveStat(
              label: 'Temperature',
              value: '${sensor.temperature.toStringAsFixed(1)}°C',
              ok: sensor.isTemperatureNormal,
            )),
            Container(width: 1, height: 40, color: Colors.white24),
            Expanded(child: _LiveStat(
              label: 'Humidity',
              value: '${sensor.humidity.toStringAsFixed(0)}%',
              ok: sensor.isHumidityNormal,
            )),
            Container(width: 1, height: 40, color: Colors.white24),
            Expanded(child: _LiveStat(
              label: 'Weight',
              value: '${sensor.totalWeightGrams.toStringAsFixed(0)}g',
              ok: true,
            )),
          ]),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String label, value;
  final bool ok;

  const _LiveStat({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
            color: ok ? Colors.white : const Color(0xFFFFB74D),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          )),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final List<FlSpot> spots;
  final double minY;
  final double? maxY;
  final double? safeMin, safeMax;

  const _ChartCard({
    required this.title, required this.subtitle, required this.icon,
    required this.color, required this.spots, required this.minY,
    this.maxY, this.safeMin, this.safeMax,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = spots.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: hasData
                ? LineChart(LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 5,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFE0E8E3), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 36,
                          getTitlesWidget: (v, m) => Text(v.toInt().toString(),
                              style: const TextStyle(fontSize: 10,
                                  color: AppTheme.textSecondary)),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    rangeAnnotations: safeMin != null ? RangeAnnotations(
                      horizontalRangeAnnotations: [
                        HorizontalRangeAnnotation(
                          y1: safeMin!, y2: safeMax!,
                          color: color.withOpacity(0.07),
                        ),
                      ],
                    ) : null,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ))
                : const Center(
                    child: Text('No data yet',
                        style: TextStyle(color: AppTheme.textSecondary))),
          ),
        ],
      ),
    );
  }
}
