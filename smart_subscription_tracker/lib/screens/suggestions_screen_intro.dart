import 'package:uuid/uuid.dart'; // Only used for mock user_id if kDebugMode and user is null
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:smart_subscription_tracker/utils/api_helper.dart'; // Assuming this path is correct
import 'package:provider/provider.dart';
import '../notifiers/shared_refresh_notifier.dart';
import '../utils/constants.dart' as constants;

void _onSuggestionComplete(BuildContext context) {
  final notifier = Provider.of<RefreshNotifier>(context, listen: false);
  notifier.triggerRefresh();

  // Optional: Switch tab if needed
  // bottomNavController.jumpToTab(0);
}

// Assuming you might have a SuggestedSubscription model,
// but for this example, we'll work directly with Map<String, dynamic>
// from ApiHelper for simplicity in the popup.
// If you have a model, it's better to parse into it.

class SuggestionsScreenIntro extends StatefulWidget {
  // Changed to StatefulWidget
  final VoidCallback onSubscriptionAdded;

  SuggestionsScreenIntro({required this.onSubscriptionAdded, Key? key})
    : super(key: key);

  @override
  _SuggestionsScreenIntroState createState() => _SuggestionsScreenIntroState();
}

class _SuggestionsScreenIntroState extends State<SuggestionsScreenIntro> {
  late Future<Map<String, dynamic>> _futureSuggestions;

  @override
  void initState() {
    super.initState();
    _futureSuggestions = _fetchSuggestionsWithProfile();
  }

  Future<Map<String, dynamic>> _fetchSuggestionsWithProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in.");
    }

    // Fetch user profile from Supabase
    final profileResponse =
        await Supabase.instance.client
            .from('user_profiles')
            .select('interests, budget, country')
            .eq('id', user.id)
            .maybeSingle();

    if (profileResponse == null) {
      throw Exception("User profile not found.");
    }

    final interests = profileResponse['interests'] ?? ['general'];
    final budget = profileResponse['budget'] ?? 50;
    final country = profileResponse['country'] ?? 'US';

    // Now call the Edge Function with all required fields
    return await ApiHelper.fetchData(
      url:
          'https://pjwaiolqaegmcgjvyxdh.functions.supabase.co/suggest_subscriptions',
      headers: {'Content-Type': 'application/json'},
      body: {
        'user_id': user.id,
        'interests': interests,
        'budget': budget,
        'country': country,
      },
      mockData: {
        'suggestions': [
          {
            'id': Uuid().v4(),
            'name': 'Mock Service 1 (Debug)',
            'description': 'This is a mock description for Service 1.',
            'price': 9.99,
            'billing_cycle': 'Monthly',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': Uuid().v4(),
            'name': 'Mock Service 2 (Debug)',
            'description': 'This is a mock description for Service 2.',
            'price': 19.99,
            'billing_cycle': 'Yearly',
            'created_at': DateTime.now().toIso8601String(),
          },
        ],
      },
    );
  }

  // Method to show suggestion details in a dialog
  void _showSuggestionDetails(
    BuildContext context,
    Map<String, dynamic> suggestion,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(suggestion['name'] ?? 'Suggestion Details'),
          content: SingleChildScrollView(
            // In case description is long
            child: ListBody(
              children: <Widget>[
                Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(suggestion['description'] ?? 'No description available.'),
                SizedBox(height: 10),
                Text('Price:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('\$${(suggestion['price'] ?? 0.0).toStringAsFixed(2)}'),
                SizedBox(height: 10),
                Text(
                  'Billing Cycle:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(suggestion['billing_cycle'] ?? 'N/A'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            // Optionally, add the "Add to Subscriptions" button here as well
            TextButton(
              child: Text('Add to My Subscriptions'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog first
                _handleAddSubscriptionAction(
                  context,
                  suggestion,
                ); // Call the add action
              },
            ),
          ],
        );
      },
    );
  }

  // Extracted the logic for adding a subscription to be callable from multiple places
  Future<void> _handleAddSubscriptionAction(
    BuildContext screenContext,
    Map<String, dynamic> suggestion,
  ) async {
    // Use screenContext for ScaffoldMessenger and Navigator that are not nested inside the dialog
    final scaffoldMessenger = ScaffoldMessenger.of(screenContext);
    final navigator = Navigator.of(screenContext);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print("No user is logged in.");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('You must be logged in to add a subscription.')),
      );
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: screenContext, // Use the main screen's context for this dialog
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Add Subscription'),
            content: Text(
              'Do you want to add "${suggestion['name']}" to your subscriptions?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Add'),
              ),
            ],
          ),
    );

    if (shouldAdd != true) return;

    try {
      final subscriptionData = {
        'name': suggestion['name'],
        'price': suggestion['price'],
        'billing_cycle':
            suggestion['billing_cycle']?.toString().toLowerCase() == 'yearly'
                ? 'Yearly'
                : 'Monthly', // Ensure correct casing
        'next_payment_date':
            DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'is_shared': false,
        'user_id': user.id,
      };

      print("Inserting subscription data: $subscriptionData");

      // Use .select() to get the inserted data back, which helps confirm success
      // The actual response type will be List<Map<String, dynamic>>
      final responseList =
          await Supabase.instance.client
              .from('subscriptions')
              .insert(subscriptionData)
              .select(); // Requesting the inserted row(s) back

      // Check if the list is empty, which might indicate an issue if select() was intended
      // to confirm the insert by returning data. For insert, a non-error is usually success.
      if (responseList.isEmpty &&
          Supabase.instance.client
                  .from('subscriptions')
                  .insert(subscriptionData)
                  .select()
                  .count() ==
              0) {
        // This check is a bit complex. A simpler check is just to rely on no exception.
        // If an error occurs (like RLS), it will throw PostgrestException.
        print(
          "Supabase insert might have had an issue, or select() returned empty unexpectedly.",
        );
        // Consider if this case should be an error or if no data returned is fine for insert.
      } else {
        _onSuggestionComplete(screenContext);
        print("Supabase insert successful. Response data: $responseList");
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${suggestion['name']} added to subscriptions!'),
        ),
      );

      widget.onSubscriptionAdded(); // Call the callback

      // Pop the SuggestionsScreenIntro itself after adding
      // Or, if you want to stay on this screen, remove this pop.
      // This pop assumes SuggestionsScreenIntro was pushed onto the stack.
      // If it's a tab in HomeScreen, you might not want to pop.
      // Based on your previous context, this screen might be a tab.
      // Let's assume for now we stay on the screen or the parent handles navigation.
      // Navigator.pop(screenContext, true); // Example if it was pushed and should return a result
    } on PostgrestException catch (e) {
      print("Error adding subscription (PostgrestException): ${e.message}");
      print("Details: ${e.details}, Code: ${e.code}, Hint: ${e.hint}");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to add subscription: ${e.message}')),
      );
    } catch (e) {
      print("Error adding subscription (General Exception): $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to add subscription: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI Suggestions")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _futureSuggestions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Error fetching suggestions: ${snapshot.error}",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Ensure your Edge Function is deployed and environment variables (especially OpenAI API key) are set.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        SizedBox(height: 20),
                        if (kDebugMode)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/home');
                            },
                            child: Text("Go Home (Debug)"),
                          ),
                      ],
                    );
                  } else if (!snapshot.hasData ||
                      snapshot.data == null ||
                      snapshot.data!['suggestions'] == null) {
                    return Center(
                      child: Text(
                        "No suggestions available or data is in unexpected format.",
                      ),
                    );
                  } else {
                    final data = snapshot.data!;
                    final suggestionsList = data['suggestions'];
                    if (suggestionsList == null || suggestionsList is! List) {
                      return Center(
                        child: Text(
                          "Suggestions data is not in the expected list format.",
                        ),
                      );
                    }
                    final suggestions = List<Map<String, dynamic>>.from(
                      suggestionsList,
                    );

                    if (suggestions.isEmpty) {
                      return Center(child: Text("No suggestions found."));
                    }

                    return ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(suggestion['name'] ?? 'N/A'),
                            subtitle: Text(
                              suggestion['description'] ?? 'No description',
                            ),
                            onTap: () {
                              _showSuggestionDetails(context, suggestion);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "\$${(suggestion['price'] as num? ?? 0.0).toStringAsFixed(2)}",
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline),
                                  color: Theme.of(context).primaryColor,
                                  tooltip: 'Add to My Subscriptions',
                                  onPressed: () async {
                                    _handleAddSubscriptionAction(
                                      context,
                                      suggestion,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
                print("Navigated to the dashboard.");
              },
              child: Text("Done / Skip"),
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionsScreen extends StatefulWidget {
  @override
  _SuggestionsScreenState createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  late Future<List<dynamic>> _futureSuggestions;

  @override
  void initState() {
    super.initState();
    _futureSuggestions = ApiHelper.fetchData(
      url: 'https://pjwaiolqaegmcgjvyxdh.functions.supabase.co/ai-suggestions',
      headers: {
        'Authorization':
            'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
        'apikey':
            '${constants.anonKey}', // Replace with your actual Supabase anon key
        'Content-Type': 'application/json',
      },
      body: {
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'subscriptions': [], // Add actual subscriptions if available
        'interests':
            [], // Replace with actual interests or initialize _selectedInterests
        'budget':
            0.0, // Replace with actual budget or initialize _budgetController
        'country': 'US', // Replace with actual country or initialize _country
      },
    ).then((response) {
      // Assuming the response is a Map<String, dynamic> with a 'suggestions' key
      return List<Map<String, dynamic>>.from(response['suggestions'] ?? []);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI Suggestions")),
      body: FutureBuilder<List<dynamic>>(
        future: _futureSuggestions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No suggestions available."));
          }

          final suggestions = snapshot.data!;
          return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                title: Text(suggestion['name']),
                subtitle: Text(suggestion['description']),
                trailing: Text("\$${suggestion['price']}"),
              );
            },
          );
        },
      ),
    );
  }
}
