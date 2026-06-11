import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'add_item_screen.dart';
import 'sensor_screen.dart';
import 'alerts_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InventoryScreen(),
    SensorScreen(),
    AlertsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    //context.read<FridgeProvider>().init();
  }

  @override
  Widget build(BuildContext context) {
    final hasAlerts = context.watch<FridgeProvider>().hasAlerts;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AddItemScreen())),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                  label: 'Home', index: 0, current: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 0)),
              _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded,
                  label: 'Inventory', index: 1, current: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 1)),
              const SizedBox(width: 56), // FAB gap
              _NavItem(icon: Icons.sensors_outlined, activeIcon: Icons.sensors_rounded,
                  label: 'Sensors', index: 2, current: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 2)),
              _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded,
                  label: 'Alerts', index: 3, current: _currentIndex,
                  onTap: () => setState(() => _currentIndex = 3), badge: hasAlerts),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;
  final bool badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(active ? activeIcon : icon,
                    color: active ? AppTheme.primary : AppTheme.textSecondary, size: 24),
                if (badge)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
