import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';

class AddEditSubscriptionScreen extends StatefulWidget {
  final Subscription? existingSub;

  AddEditSubscriptionScreen({this.existingSub});

  @override
  _AddEditSubscriptionScreenState createState() =>
      _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends State<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late DateTime _nextDate;
  String _billingCycle = 'Monthly';
  bool _isShared = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final sub = widget.existingSub;
    _nameController = TextEditingController(text: sub?.name ?? '');
    _priceController = TextEditingController(
      text: sub?.price.toStringAsFixed(2) ?? '',
    );
    _nextDate = sub?.nextPaymentDate ?? DateTime.now();
    _billingCycle = sub?.billingCycle ?? 'Monthly';
    _isShared = sub?.isShared ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final sub = Subscription(
        id: widget.existingSub?.id ?? '',
        name: _nameController.text,
        price: double.parse(_priceController.text),
        billingCycle: _billingCycle,
        nextPaymentDate: _nextDate,
        isShared: _isShared,
      );

      final service = SupabaseService();
      if (widget.existingSub == null) {
        print("Adding new subscription: $sub");
        await service.addSubscription(sub);
      } else {
        print("Updating subscription: $sub");
        await service.updateSubscription(sub);
      }

      // Return true to indicate a subscription was added or updated
      Navigator.pop(context, true);
      print("Navigated back with result: true");
    } catch (e) {
      print("Error saving subscription: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save subscription: $e")),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSub != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Subscription' : 'Add Subscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        double.tryParse(v ?? '') == null
                            ? 'Enter a valid number'
                            : null,
              ),
              DropdownButtonFormField(
                value: _billingCycle,
                items:
                    ['Monthly', 'Yearly', 'Weekly']
                        .map(
                          (cycle) => DropdownMenuItem(
                            value: cycle,
                            child: Text(cycle),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _billingCycle = val!),
                decoration: InputDecoration(labelText: 'Billing Cycle'),
              ),
              SwitchListTile(
                value: _isShared,
                onChanged: (v) => setState(() => _isShared = v),
                title: Text('Shared Subscription'),
              ),
              ListTile(
                title: Text(
                  "Next Payment: ${_nextDate.toLocal().toString().split(' ')[0]}",
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDate,
                    firstDate: DateTime.now().subtract(Duration(days: 365)),
                    lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                  );
                  if (picked != null) setState(() => _nextDate = picked);
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving
                      ? 'Saving...'
                      : isEditing
                      ? 'Update'
                      : 'Add Subscription',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
