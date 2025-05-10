class Subscription {
  final String id;
  final String name;
  final double price;
  final String billingCycle;
  final DateTime nextPaymentDate;
  final bool isShared; 
  Subscription({
    required this.id,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.nextPaymentDate,
    required this.isShared, 
  });

  @override
  String toString() {
    return 'Subscription(id: $id, name: $name, price: $price, billingCycle: $billingCycle, nextPaymentDate: $nextPaymentDate, isShared: $isShared)';
  }


  // Factory constructor to create a Subscription from JSON
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Subscription',
      price:
          (json['price'] is num)
              ? (json['price'] as num).toDouble()
              : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      billingCycle: json['billing_cycle']?.toString() ?? 'Monthly',
      nextPaymentDate:
          DateTime.tryParse(json['next_payment_date']?.toString() ?? '') ??
          DateTime.now().add(Duration(days: 30)),
      isShared: json['is_shared'] == true,
    );
  }

}
