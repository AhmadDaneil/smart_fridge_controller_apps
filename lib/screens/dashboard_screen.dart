import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fridge_provider.dart';
import '../theme.dart';
import '../models/sensor_data.dart';
import '../services/supabase_service.dart';
import 'auth/login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FridgeProvider>();
    final sensor = provider.sensorData;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: RefreshIndicator(
        color: AppTheme.primary,        // ADD THIS
        onRefresh: () => context.read<FridgeProvider>().refresh(),
        child: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: false,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Log out',
                onPressed: () => _confirmLogout(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_greeting()}! 👋',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Text(
                    'Smart Fridge Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Live Sensor Card ─────────────────────────────────────
                _SectionLabel('Live Sensor Readings'),
                const SizedBox(height: 10),
                if (sensor == null)
                  _shimmerPlaceholder()
                else
                  Row(
                    children: [
                      Expanded(
                        child: _SensorTile(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperature',
                          value: '${sensor.temperature.toStringAsFixed(1)}°C',
                          status:
                              sensor.temperatureStatus ==
                                  TemperatureStatus.normal
                              ? _StatusLevel.good
                              : _StatusLevel.bad,
                          subtitle:
                              sensor.temperatureStatus ==
                                  TemperatureStatus.normal
                              ? 'Normal'
                              : 'Out of range',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SensorTile(
                          icon: Icons.water_drop_outlined,
                          label: 'Humidity',
                          value: '${sensor.humidity.toStringAsFixed(0)}%',
                          status: sensor.isHumidityNormal
                              ? _StatusLevel.good
                              : _StatusLevel.warn,
                          subtitle: sensor.isHumidityNormal
                              ? 'Normal'
                              : 'Check fridge',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SensorTile(
                          icon: sensor.isDoorOpen
                              ? Icons.door_front_door_rounded
                              : Icons.door_front_door_outlined,
                          label: 'Door',
                          value: sensor.isDoorOpen ? 'Open' : 'Closed',
                          status: sensor.isDoorOpen
                              ? (provider.isDoorLeftOpen
                                  ? _StatusLevel.bad
                                  : _StatusLevel.warn)
                              : _StatusLevel.good,
                          subtitle: provider.isDoorLeftOpen
                              ? 'Left open!'
                              : (sensor.isDoorOpen ? 'Just opened' : 'Secure'),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // ── Summary Stats ────────────────────────────────────────
                _SectionLabel('Inventory Summary'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Items',
                        value: provider.items.length.toString(),
                        color: AppTheme.primary,
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Expiring Soon',
                        value: provider.expiringSoonCount.toString(),
                        color: AppTheme.warning,
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Expired',
                        value: provider.expiredCount.toString(),
                        color: AppTheme.danger,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Recent Items ─────────────────────────────────────────
                _SectionLabel('Recent Items'),
                const SizedBox(height: 10),
                if (provider.loading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.items.isEmpty)
                  _EmptyState()
                else
                  ...provider.items
                      .take(4)
                      .map(
                        (item) => _ItemPreviewTile(
                          name: item.name,
                          category: item.category,
                          expiryLabel: item.isExpired
                              ? 'Expired ${(-item.daysUntilExpiry)}d ago'
                              : item.daysUntilExpiry == 0
                              ? 'Expires today'
                              : 'Expires in ${item.daysUntilExpiry}d',
                          statusColor: item.isExpired
                              ? AppTheme.danger
                              : item.isExpiringSoon
                              ? AppTheme.warning
                              : AppTheme.safe,
                        ),
                      ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService().signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _shimmerPlaceholder() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

enum _StatusLevel { good, warn, bad }

class _SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _StatusLevel status;
  final String subtitle;

  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.subtitle,
  });

  Color get _color => status == _StatusLevel.good
      ? AppTheme.safe
      : status == _StatusLevel.warn
      ? AppTheme.warning
      : AppTheme.danger;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(icon, color: _color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: _color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ItemPreviewTile extends StatelessWidget {
  final String name, category, expiryLabel;
  final Color statusColor;

  const _ItemPreviewTile({
    required this.name,
    required this.category,
    required this.expiryLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_categoryIcon(category), color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expiryLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Dairy':
        return Icons.egg_outlined;
      case 'Meat':
        return Icons.set_meal_outlined;
      case 'Vegetables':
        return Icons.eco_outlined;
      case 'Fruits':
        return Icons.apple_outlined;
      case 'Beverages':
        return Icons.local_drink_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'No items yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to add your first item',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}