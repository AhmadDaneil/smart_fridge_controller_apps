import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fridge_provider.dart';
import '../models/fridge_item.dart';
import '../theme.dart';

class AddItemScreen extends StatefulWidget {
  final FridgeItem? editItem;
  const AddItemScreen({super.key, this.editItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  String _category = 'Other';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      final item = widget.editItem!;
      _nameCtrl.text = item.name;
      _weightCtrl.text = item.weightGrams.toStringAsFixed(0);
      _notesCtrl.text = item.notes ?? '';
      _expiryDate = item.expiryDate;
      _category = item.category;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final item = FridgeItem(
        id: widget.editItem?.id ?? '',
        name: _nameCtrl.text.trim(),
        weightGrams: double.parse(_weightCtrl.text),
        expiryDate: _expiryDate,
        addedDate: widget.editItem?.addedDate ?? DateTime.now(),
        category: _category,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );

      final provider = context.read<FridgeProvider>();
      if (widget.editItem != null) {
        await provider.updateItem(item);
      } else {
        await provider.addItem(item);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editItem != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Item' : 'Add Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Name
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                prefixIcon: Icon(Icons.kitchen_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: kFoodCategories.map((cat) =>
                  DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 14),

            // Weight
            TextFormField(
              controller: _weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (grams) *',
                prefixIcon: Icon(Icons.scale_outlined),
                suffixText: 'g',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid weight';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Expiry date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Expiry Date',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMMM yyyy').format(_expiryDate),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppTheme.textSecondary),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isEdit ? Icons.save_outlined : Icons.add_rounded),
                label: Text(isEdit ? 'Save Changes' : 'Add to Fridge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
