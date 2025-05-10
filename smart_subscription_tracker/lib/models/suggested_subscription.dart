// ../models/suggested_subscription.dart

class SuggestedSubscription {
  final String id; // UUID from Supabase
  final String name;
  final String? description; // Nullable
  final double price; // Dart double, Supabase NUMERIC
  final String billingCycle; // 'Monthly' or 'Yearly'
  final DateTime createdAt; // Supabase TIMESTAMPTZ

  SuggestedSubscription({
    required this.id,
    required this.name,
    this.description, // Nullable
    required this.price,
    required this.billingCycle,
    required this.createdAt,
  });

  // Factory constructor to create a SuggestedSubscription from JSON
  factory SuggestedSubscription.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null ||
        json['name'] == null ||
        json['price'] == null ||
        json['billing_cycle'] == null ||
        json['created_at'] == null) {
      throw FormatException(
        "One or more required fields are null in the JSON data for SuggestedSubscription: $json",
      );
    }
    return SuggestedSubscription(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?, // Handle nullable field
      price: (json['price'] as num).toDouble(), // Cast NUMERIC/FLOAT from DB to double
      billingCycle: json['billing_cycle'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
