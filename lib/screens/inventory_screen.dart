import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../models/fridge_item.dart';
import '../theme.dart';
import 'item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';
  String _filterCat = 'All';
  String _filterStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FridgeProvider>();
    final items = _filtered(provider.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${provider.items.length} items'),
              backgroundColor: AppTheme.primarySurface,
              side: BorderSide.none,
              labelStyle: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category filter chips
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children:
                  [
                        'All',
                        'Dairy',
                        'Meat',
                        'Vegetables',
                        'Fruits',
                        'Beverages',
                        'Other',
                      ]
                      .map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: _filterCat == cat,
                            onSelected: (_) => setState(() => _filterCat = cat),
                            selectedColor: AppTheme.primarySurface,
                            labelStyle: TextStyle(
                              color: _filterCat == cat
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),

          // Status filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterBtn(
                  'All',
                  _filterStatus,
                  () => setState(() => _filterStatus = 'All'),
                ),
                const SizedBox(width: 8),
                _FilterBtn(
                  'Good',
                  _filterStatus,
                  () => setState(() => _filterStatus = 'Good'),
                  color: AppTheme.safe,
                ),
                const SizedBox(width: 8),
                _FilterBtn(
                  'Expiring',
                  _filterStatus,
                  () => setState(() => _filterStatus = 'Expiring'),
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _FilterBtn(
                  'Expired',
                  _filterStatus,
                  () => setState(() => _filterStatus = 'Expired'),
                  color: AppTheme.danger,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),

          // List
          Expanded(
            child: items.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => context.read<FridgeProvider>().refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ItemCard(
                      item: items[i],
                      onDelete: () => provider.deleteItem(items[i].id),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  List<FridgeItem> _filtered(List<FridgeItem> all) {
    return all.where((item) {
      final matchSearch =
          _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _filterCat == 'All' || item.category == _filterCat;
      final matchStatus =
          _filterStatus == 'All' ||
          (_filterStatus == 'Expired' && item.isExpired) ||
          (_filterStatus == 'Expiring' && item.isExpiringSoon) ||
          (_filterStatus == 'Good' && !item.isExpired && !item.isExpiringSoon);
      return matchSearch && matchCat && matchStatus;
    }).toList();
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'No items found',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label, current;
  final VoidCallback onTap;
  final Color? color;

  const _FilterBtn(this.label, this.current, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) {
    final active = label == current;
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? c : AppTheme.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final FridgeItem item;
  final VoidCallback onDelete;

  const _ItemCard({required this.item, required this.onDelete});

  Color get _statusColor => item.isExpired
      ? AppTheme.danger
      : item.isExpiringSoon
      ? AppTheme.warning
      : AppTheme.safe;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('Remove "${item.name}" from inventory?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.danger),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_catIcon(), color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.category}',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.isExpired
                          ? 'Expired'
                          : item.daysUntilExpiry == 0
                          ? 'Today'
                          : '${item.daysUntilExpiry}d left',
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _catIcon() {
    switch (item.category) {
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