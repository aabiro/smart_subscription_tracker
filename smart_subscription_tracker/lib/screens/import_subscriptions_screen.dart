import 'package:flutter/material.dart';
import '../services/gmail_parser.dart';
import '../models/subscription.dart';

class ImportSubscriptionsScreen extends StatefulWidget {
  @override
  _ImportSubscriptionsScreenState createState() =>
      _ImportSubscriptionsScreenState();
}

class _ImportSubscriptionsScreenState extends State<ImportSubscriptionsScreen> {
  List<Map<String, dynamic>> parsedSubs = [];
  List<bool> selected = [];

  @override
  void initState() {
    super.initState();
    final parser = GmailParser();
    parsedSubs = parser.parseEmails();
    selected = List.filled(parsedSubs.length, true);
  }

  void _importSelected() {
    final importedSubs = <Subscription>[];
    for (int i = 0; i < parsedSubs.length; i++) {
      if (selected[i]) {
        final sub = parsedSubs[i];
        importedSubs.add(
          Subscription(
            id: sub['id'], // Add the required 'id' parameter
            isShared: sub['isShared'], // Add the required 'isShared' parameter
            name: sub['name'],
            price: sub['price'],
            billingCycle: sub['billingCycle'],
            nextPaymentDate: sub['nextPaymentDate'],
          ),
        );
      }
    }

    // You can return this list or save it to Firebase/Supabase
    Navigator.pop(context, importedSubs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import from Gmail')),
      body: ListView.builder(
        itemCount: parsedSubs.length,
        itemBuilder: (context, index) {
          final sub = parsedSubs[index];
          return CheckboxListTile(
            value: selected[index],
            onChanged: (val) {
              setState(() {
                selected[index] = val!;
              });
            },
            title: Text(sub['name']),
            subtitle: Text('\$${sub['price']} • ${sub['billingCycle']}'),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _importSelected,
          child: Text('Import Selected'),
        ),
      ),
    );
  }
}
