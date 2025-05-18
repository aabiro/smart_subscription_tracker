import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart' as constants;
import 'package:smart_subscription_tracker/utils/api_helper.dart';

class UserPreferencesScreen extends StatefulWidget {
  @override
  _UserPreferencesScreenState createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final _budgetController = TextEditingController(text: '50');
  final List<String> _availableInterests = List.from(constants.kAllInterests);
  List<String> _selectedInterests = [];
  String _country = 'US';
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _savePreferences() async {
    if (_selectedInterests.isEmpty) {
      // Show an error message if no interests are selected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select at least one interest."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'preferences_completed': true})
          .eq('id', user.id);
    }

    // Navigate to the main app screen
    if (mounted) {
      _loadPreferences();
      Navigator.pushReplacementNamed(context, '/suggestions');
    }
  }

  Future<void> _loadPreferences() async {
    if (!mounted) return; // Ensure the widget is still in the tree
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responseData = await ApiHelper.fetchDataList(
        url:
            'https://pjwaiolqaegmcgjvyxdh.supabase.co/rest/v1/user_profiles?id=eq.${supabase.auth.currentUser!.id}&select=*',
        headers: {
          'Authorization':
              'Bearer ${supabase.auth.currentSession?.accessToken}',
          'apikey': constants.anonKey,
          'Content-Type': 'application/json',
        },
      );

      if (responseData.isNotEmpty) {
        final data = responseData[0] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _selectedInterests = List<String>.from(data['interests']);
            _budgetController.text = data['budget'].toString();
            _country = data['country'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "No preferences found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading preferences: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Preferences"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Your Interests",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _availableInterests.map((interest) {
                    final selected = _selectedInterests.contains(interest);
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: FilterChip(
                        label: Text(
                          interest,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedInterests.add(interest);
                            } else {
                              _selectedInterests.remove(interest);
                            }
                          });
                        },
                        selectedColor:
                            Colors.blue, // Background color when selected
                        backgroundColor:
                            Colors
                                .grey[300], // Background color when not selected
                        checkmarkColor: Colors.white, // Checkmark color
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    );
                  }).toList(),
            ),
            SizedBox(height: 20),
            Text(
              "Set Your Monthly Budget",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _budgetController,
              decoration: InputDecoration(labelText: 'Monthly Budget (\$)'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            Text(
              "Set Your Country",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(labelText: 'Country'),
              onChanged: (val) => _country = val,
              controller: TextEditingController(text: _country),
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text("Save Preferences"),
                onPressed:
                    _selectedInterests.isEmpty
                        ? null // Disable the button if no interests are selected
                        : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedInterests.isEmpty
                          ? Colors
                              .grey // Grey out the button when disabled
                          : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
