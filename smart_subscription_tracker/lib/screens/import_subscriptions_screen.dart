import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../models/subscription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../notifiers/shared_refresh_notifier.dart';

void _onImportComplete(BuildContext context) {
  final notifier = Provider.of<RefreshNotifier>(context, listen: false);
  notifier.triggerRefresh();

  // Optional: Switch tab if needed
  // bottomNavController.jumpToTab(0);
}

class ImportSubscriptionsScreen extends StatefulWidget {
  @override
  _ImportSubscriptionsScreenState createState() =>
      _ImportSubscriptionsScreenState();
}

class _ImportSubscriptionsScreenState extends State<ImportSubscriptionsScreen> {
  bool _isImporting = false;

  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  );

  List<Map<String, dynamic>> parsedSubs = [];
  List<bool> selected = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _fetchMockSubscriptions(); // Use mock data in debug mode
    } else {
      _fetchSubscriptionsFromGmail(); // Fetch real data in production
    }
  }

  void _fetchMockSubscriptions() {
    setState(() {
      parsedSubs = [
        {
          'id': '1',
          'name': 'Netflix',
          'price': 15.99,
          'billingCycle': 'Monthly',
          'nextPaymentDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'isShared': false,
        },
        {
          'id': '2',
          'name': 'Spotify',
          'price': 9.99,
          'billingCycle': 'Monthly',
          'nextPaymentDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'isShared': false,
        },
      ];
      selected = List.filled(parsedSubs.length, true);
    });
  }

  Future<void> _fetchSubscriptionsFromGmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception("Google Sign-In canceled by user.");
      }

      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);

      final gmailApi = gmail.GmailApi(client);
      final messages = await gmailApi.users.messages.list(
        'me',
        q: "receipt OR subscription",
      );

      final List<Map<String, dynamic>> subscriptions = [];
      for (var msg in messages.messages ?? []) {
        final fullMessage = await gmailApi.users.messages.get('me', msg.id!);
        final snippet = fullMessage.snippet ?? '';

        // Parse the snippet to extract subscription details
        final parsedSubscription = _parseSubscriptionFromSnippet(snippet);
        if (parsedSubscription != null) {
          subscriptions.add(parsedSubscription);
        }
      }

      setState(() {
        parsedSubs = subscriptions;
        selected = List.filled(parsedSubs.length, true);
      });

      print("ImportSubscriptionsScreen: Fetched subscriptions: $parsedSubs");
    } catch (e) {
      print("Error fetching subscriptions from Gmail: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch subscriptions: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _parseSubscriptionFromSnippet(String snippet) {
    // Placeholder parsing logic
    // Replace this with actual logic to extract subscription details
    if (snippet.contains("Supabase Pro")) {
      return {
        'id': DateTime.now().toIso8601String(), // Generate a unique ID
        'name': 'Supabase Pro',
        'price': 15.99,
        'billingCycle': 'Monthly',
        'nextPaymentDate':
            DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'isShared': false,
      };
    }
    return null;
  }

  void _importSelected() async {
    setState(() {
      _isImporting = true;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You must be logged in to import subscriptions."),
        ),
      );
      setState(() {
        _isImporting = false;
      });
      return;
    }

    final importedSubs = <Subscription>[];

    for (int i = 0; i < parsedSubs.length; i++) {
      if (selected[i]) {
        final sub = parsedSubs[i];
        final newSub = Subscription(
          id: sub['id'] ?? DateTime.now().toIso8601String(),
          name: sub['name'] ?? 'Unnamed Subscription',
          price: (sub['price'] ?? 0).toDouble(),
          billingCycle: sub['billingCycle'] ?? 'Monthly',
          nextPaymentDate:
              DateTime.tryParse(sub['nextPaymentDate'] ?? '') ??
              DateTime.now().add(Duration(days: 30)),
          isShared: sub['isShared'] == true,
        );

        await Supabase.instance.client.from('subscriptions').insert({
          'name': newSub.name,
          'price': newSub.price,
          'billing_cycle': newSub.billingCycle,
          'next_payment_date': newSub.nextPaymentDate.toIso8601String(),
          'is_shared': newSub.isShared,
          'user_id': user.id,
        });

        importedSubs.add(newSub);
      }
    }

    if (importedSubs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${importedSubs.length} subscriptions imported!"),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No subscriptions selected.")));
    }

    setState(() {
      _isImporting = false;
    });
    _onImportComplete(context);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import from Gmail')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : parsedSubs.isEmpty
              ? Center(child: Text("No subscriptions found."))
              : ListView.builder(
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
                    title: Text(sub['name']?.toString() ?? 'Unnamed'),
                    subtitle: Text(
                      '\$${(sub['price'] ?? 0).toString()} • ${sub['billingCycle']?.toString() ?? 'Monthly'}',
                    ),

                  );
                },
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isImporting ? null : _importSelected,
          child:
              _isImporting
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text('Import Selected'),
        ),
      ),

    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
