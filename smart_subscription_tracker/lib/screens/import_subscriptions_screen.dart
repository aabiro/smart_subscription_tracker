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
  bool _isLoading = false;
  List<Map<String, dynamic>> parsedSubs = [];
  List<bool> selected = [];

  Future<String?> getGmailAccessToken() async {
    try {
      print('Starting Google sign-in...');
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn(
            scopes: ['email', 'https://www.googleapis.com/auth/gmail.readonly'],
          ).signIn();

      if (googleUser == null) {
        print('Google sign-in cancelled by user.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print('Google sign-in successful, got access token.');
      return googleAuth.accessToken;
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  Future<void> _fetchFromGmailEdgeFunction() async {
    setState(() => _isLoading = true);

    print('Fetching Gmail OAuth token...');
    final oauthToken = await getGmailAccessToken();
    print('OAuth token: $oauthToken');
    if (oauthToken == null) {
      print('No OAuth token, aborting.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed.")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      print('Calling Supabase Edge Function import_gmail...');
      final response = await Supabase.instance.client.functions.invoke(
        'import_gmail',
        body: {'oauth_token': oauthToken},
      );
      print('Edge Function response: ${response.data}');
      final data = response.data;
      if (data != null && data is List) {
        setState(() {
          parsedSubs = List<Map<String, dynamic>>.from(data);
          selected = List.filled(parsedSubs.length, true);
        });
      } else {
        print('No subscriptions found in response.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No subscriptions found from Gmail.")),
        );
      }
    } catch (e, st) {
      print('Error calling Edge Function: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calling Edge Function: $e')),
      );
    }

    setState(() => _isLoading = false);
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.email),
              label: Text("Fetch from Gmail"),
              onPressed: _isLoading ? null : _fetchFromGmailEdgeFunction,
            ),
          ),
          Expanded(
            child:
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
          ),
        ],
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
