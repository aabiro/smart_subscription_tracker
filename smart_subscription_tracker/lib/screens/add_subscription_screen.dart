import 'package:flutter/material.dart';
import '../models/subscription.dart';

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? existingSub;

  AddSubscriptionScreen({this.existingSub});

  @override
  _AddSubscriptionScreenState createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late String _billingCycle;
  late DateTime _nextPaymentDate;
  late bool _isShared;

  @override
  void initState() {
    super.initState();
    // Initialize fields with existing subscription data if provided
    _nameController = TextEditingController(
        text: widget.existingSub?.name ?? '');
    _priceController = TextEditingController(
        text: widget.existingSub?.price.toString() ?? '');
    _billingCycle = widget.existingSub?.billingCycle ?? 'Monthly';
    _nextPaymentDate = widget.existingSub?.nextPaymentDate ?? DateTime.now();
    _isShared = widget.existingSub?.isShared ?? false;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newSub = Subscription(
        id: widget.existingSub?.id ?? UniqueKey().toString(),
        name: _nameController.text,
        price: double.parse(_priceController.text),
        billingCycle: _billingCycle,
        nextPaymentDate: _nextPaymentDate,
        isShared: _isShared,
      );
      Navigator.pop(context, newSub); // Send back the subscription
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextPaymentDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _nextPaymentDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existingSub == null ? 'Add Subscription' : 'Edit Subscription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Subscription Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price (USD)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) => double.tryParse(value!) == null ? 'Enter valid number' : null,
              ),
              DropdownButtonFormField<String>(
                value: _billingCycle,
                items: ['Monthly', 'Yearly'].map((cycle) {
                  return DropdownMenuItem(value: cycle, child: Text(cycle));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _billingCycle = value!;
                  });
                },
                decoration: InputDecoration(labelText: 'Billing Cycle'),
              ),
              ListTile(
                title: Text(
                  'Next Payment: ${_nextPaymentDate.month}/${_nextPaymentDate.day}/${_nextPaymentDate.year}',
                ),
                trailing: Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              SwitchListTile(
                title: Text('Shared Subscription?'),
                value: _isShared,
                onChanged: (value) {
                  setState(() {
                    _isShared = value;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text('Save Subscription'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}