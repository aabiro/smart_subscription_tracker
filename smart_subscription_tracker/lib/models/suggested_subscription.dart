class SuggestedSubscription {
  final String name;
  final String description;
  final double price;
  final String billingCycle;

  SuggestedSubscription({
    required this.name,
    required this.description,
    required this.price,
    required this.billingCycle,
  });

  factory SuggestedSubscription.fromJson(Map<String, dynamic> json) {
    return SuggestedSubscription(
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      billingCycle: json['billing_cycle'],
    );
  }
}
