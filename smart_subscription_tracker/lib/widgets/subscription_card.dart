import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../screens/add_edit_subscription_screen.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;

  SubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(Icons.subscriptions),
        title: Text(subscription.name),
        subtitle: Text(
          '${subscription.billingCycle} • \$${subscription.price.toStringAsFixed(2)}',
        ),
        trailing: Text(
          'Due: ${subscription.nextPaymentDate.month}/${subscription.nextPaymentDate.day}',
          style: TextStyle(color: Colors.redAccent),
        ),
        onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AddEditSubscriptionScreen(existingSub: subscription),
  ),
)

      ),
    );
  }
}
