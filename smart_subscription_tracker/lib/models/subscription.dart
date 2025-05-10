class Subscription {
  final String id;
  final String name;
  final double price;
  final String billingCycle;
  final DateTime nextPaymentDate;
  final bool isShared; // Added the missing field

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.nextPaymentDate,
    required this.isShared, // Added the field to the constructor
  });

   // Add your existing fields here

  // Factory constructor to create a Subscription from JSON
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      // Replace these fields with the actual fields in your Subscription class
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      billingCycle: json['billing_cycle'] as String,
      nextPaymentDate: DateTime.parse(json['next_payment_date'] as String),
      isShared: json['is_shared'] as bool,
    );
  }
}
