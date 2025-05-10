import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_subscription_tracker/utils/api_helper.dart';

class UserPreferencesScreen extends StatefulWidget {
  @override
  _UserPreferencesScreenState createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final _budgetController = TextEditingController(text: '50');
  final List<String> _availableInterests = [
    'Entertainment',
    'Fitness',
    'Productivity',
    'Learning',
    'Finance',
  ];
  List<String> _selectedInterests = [];
  String _country = 'US';
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _savePreferences() async {
    final budget = double.tryParse(_budgetController.text) ?? 0;

    await supabase.from('user_profiles').upsert({
      'id': supabase.auth.currentUser!.id,
      'interests': _selectedInterests,
      'budget': budget,
      'country': _country,
    });

    // Mark preferences as completed or reset in debug mode
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      await prefs.setBool('preferencesCompleted', false);
      print("Debug mode: preferencesCompleted set to false");
    } else {
      await prefs.setBool('preferencesCompleted', true);
    }

    // Navigate to the main app screen
    Navigator.pushReplacementNamed(context, '/suggestions');
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiHelper.fetchData(
        url: 'https://pjwaiolqaegmcgjvyxdh.supabase.co/rest/v1/user_preferences',
        headers: {'Authorization': 'Bearer YOUR_API_KEY'},
        mockData: {
          'interests': ['Technology', 'Fitness'],
          'budget': 50.0,
          'country': 'USA',
        },
      );

      setState(() {
        _selectedInterests = List<String>.from(data['interests']);
        _budgetController.text = data['budget'].toString();
        _country = data['country'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Preferences")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Select Your Interests",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 10,
              children: _availableInterests.map((interest) {
                final selected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val)
                        _selectedInterests.add(interest);
                      else
                        _selectedInterests.remove(interest);
                    });
                  },
                );
              }).toList(),
            ),
            TextField(
              controller: _budgetController,
              decoration: InputDecoration(labelText: 'Monthly Budget (\$)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Country'),
              onChanged: (val) => _country = val,
              controller: TextEditingController(text: _country),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePreferences,
              child: Text("Save Preferences"),
            ),
          ],
        ),
      ),
    );
  }
}
