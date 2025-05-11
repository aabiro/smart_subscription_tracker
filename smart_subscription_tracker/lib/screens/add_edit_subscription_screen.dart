import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';

class AddEditSubscriptionScreen extends StatefulWidget {
  final Subscription? existingSub;

  const AddEditSubscriptionScreen({Key? key, this.existingSub})
    : super(key: key);

  @override
  _AddEditSubscriptionScreenState createState() =>
      _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState extends State<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _nextPaymentDate;
  String _billingCycle = 'Monthly';
  bool _isShared = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSub != null) {
      _nameController.text = widget.existingSub!.name;
      _priceController.text = widget.existingSub!.price.toStringAsFixed(2);
      _nextPaymentDate = widget.existingSub!.nextPaymentDate;
      _billingCycle = widget.existingSub!.billingCycle;
      _isShared = widget.existingSub!.isShared;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (_nextPaymentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a next payment date.")),
      );
      return;
    }

    final newSub = Subscription(
      id: widget.existingSub?.id ?? '',
      name: name,
      price: price,
      nextPaymentDate: _nextPaymentDate!,
      billingCycle: _billingCycle,
      isShared: _isShared,
    );

    final service = SupabaseService();
    if (widget.existingSub == null) {
      print("Adding new subscription: $newSub");
      await service.addSubscription(newSub);
    } else {
      print("Updating subscription: $newSub");
      await service.updateSubscription(newSub);
    }

    Navigator.pop(context, true);
    print("Navigated back with result: true");
  }

  Future<void> _pickNextPaymentDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextPaymentDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );

    if (pickedDate != null) {
      setState(() {
        _nextPaymentDate = pickedDate;
      });
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
              // Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16), // Add spacing
              // Price Input
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
              SizedBox(height: 16), // Add spacing
              // Billing Cycle Dropdown
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
              SizedBox(height: 16), // Add spacing
              // Shared Subscription Switch
              SwitchListTile(
                value: _isShared,
                onChanged: (v) => setState(() => _isShared = v),
                title: Text('Shared Subscription'),
              ),
              SizedBox(height: 16), // Add spacing
              // Next Payment Date Picker
              ListTile(
                title: Text(
                  "Next Payment: ${_nextPaymentDate?.toLocal().toString().split(' ')[0] ?? 'No date selected'}",
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: _pickNextPaymentDate,
              ),
              SizedBox(height: 24), // Add spacing
              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveSubscription,
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
