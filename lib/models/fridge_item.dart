class FridgeItem {
  final String id;
  final String name;
  final double weightGrams;
  final DateTime expiryDate;
  final DateTime addedDate;
  final String category;
  final String? notes;

  FridgeItem({
    required this.id,
    required this.name,
    required this.weightGrams,
    required this.expiryDate,
    required this.addedDate,
    required this.category,
    this.notes,
  });

  factory FridgeItem.fromJson(Map<String, dynamic> json) {
    return FridgeItem(
      id: json['id'].toString(),
      name: json['name'] as String,
      weightGrams: (json['weight_grams'] as num).toDouble(),
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      addedDate: DateTime.parse(json['added_date'] as String),
      category: json['category'] as String? ?? 'Other',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight_grams': weightGrams,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'added_date': addedDate.toIso8601String().split('T').first,
      'category': category,
      'notes': notes,
    };
  }

  /// Days until expiry (negative = expired)
  int get daysUntilExpiry =>
      expiryDate.difference(DateTime.now()).inDays;

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
  bool get isLowWeight => weightGrams < 100;

  ExpiryStatus get expiryStatus {
    if (isExpired) return ExpiryStatus.expired;
    if (isExpiringSoon) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.good;
  }

  FridgeItem copyWith({
    String? id,
    String? name,
    double? weightGrams,
    DateTime? expiryDate,
    DateTime? addedDate,
    String? category,
    String? notes,
  }) {
    return FridgeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      weightGrams: weightGrams ?? this.weightGrams,
      expiryDate: expiryDate ?? this.expiryDate,
      addedDate: addedDate ?? this.addedDate,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }
}

enum ExpiryStatus { good, expiringSoon, expired }

const List<String> kFoodCategories = [
  'Dairy',
  'Meat',
  'Vegetables',
  'Fruits',
  'Beverages',
  'Leftovers',
  'Condiments',
  'Other',
];