import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/fridge_item.dart';
import '../providers/fridge_provider.dart';
import '../theme.dart';
import 'add_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final FridgeItem item;
  const ItemDetailScreen({super.key, required this.item});

  Color get _statusColor => item.isExpired
      ? AppTheme.danger
      : item.isExpiringSoon
      ? AppTheme.warning
      : AppTheme.safe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddItemScreen(editItem: item)),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.danger,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete item?'),
                  content: Text('Remove "${item.name}"?'),
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
              if (confirm == true && context.mounted) {
                await context.read<FridgeProvider>().deleteItem(item.id);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _statusColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_catIcon(), color: _statusColor, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.isExpired
                        ? 'Expired ${-item.daysUntilExpiry} day(s) ago'
                        : item.daysUntilExpiry == 0
                        ? 'Expires today!'
                        : 'Expires in ${item.daysUntilExpiry} day(s)',
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Details list
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _DetailRow('Category', item.category, Icons.category_outlined),
                if (item.weightGrams != null) ...[
                  const Divider(
                    height: 1,
                    color: AppTheme.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _DetailRow(
                    'Weight',
                    '${item.weightGrams!.toStringAsFixed(0)} g',
                    Icons.scale_outlined,
                  ),
                ],
                const Divider(
                  height: 1,
                  color: AppTheme.border,
                  indent: 16,
                  endIndent: 16,
                ),
                _DetailRow(
                  'Expiry Date',
                  DateFormat('dd MMMM yyyy').format(item.expiryDate),
                  Icons.calendar_today_outlined,
                ),
                const Divider(
                  height: 1,
                  color: AppTheme.border,
                  indent: 16,
                  endIndent: 16,
                ),
                _DetailRow(
                  'Added On',
                  DateFormat('dd MMMM yyyy').format(item.addedDate),
                  Icons.add_circle_outline_rounded,
                ),
                if (item.notes != null) ...[
                  const Divider(
                    height: 1,
                    color: AppTheme.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _DetailRow('Notes', item.notes!, Icons.notes_outlined),
                ],
              ],
            ),
          ),
        ],
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

class _DetailRow extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _DetailRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}