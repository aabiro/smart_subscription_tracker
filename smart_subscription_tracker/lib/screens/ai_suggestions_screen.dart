import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Assuming you have this for charts
import 'package:provider/provider.dart'; // Import Provider
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/suggested_subscription.dart';
import '../models/subscription.dart'; // For the chart part
import '../services/supabase_service.dart'; // For fetchSubscriptions
import '../notifiers/shared_refresh_notifier.dart'; // Import your RefreshNotifier

// Define a simple UserProfile model to hold preference data
class UserProfile {
  final List<String> interests;
  final double? budget; // Budget can be optional
  final String? country; // Country can be optional

  UserProfile({required this.interests, this.budget, this.country});

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      interests:
          map['interests'] != null
              ? List<String>.from(
                map['interests'].map((item) => item.toString()),
              )
              : [],
      budget: (map['budget'] as num?)?.toDouble(),
      country: map['country'] as String?,
    );
  }

  factory UserProfile.defaultValues() {
    return UserProfile(interests: ['general'], budget: 50.0, country: 'US');
  }
}

class AISuggestionsScreen extends StatefulWidget {
  // Removed direct refreshNotifier parameter if using Provider globally
  // final RefreshNotifier refreshNotifier;

  // const AISuggestionsScreen({Key? key, required this.refreshNotifier}) : super(key: key);

  @override
  _AISuggestionsScreenState createState() => _AISuggestionsScreenState();
}

class _AISuggestionsScreenState extends State<AISuggestionsScreen> {
  late Future<List<Subscription>> _futureSubs;
  Future<List<SuggestedSubscription>>? _futureSuggestions;
  final supabase = Supabase.instance.client;
  UserProfile? _userProfile;
  bool _isLoadingProfileAndSuggestions = true;
  String? _errorMessage;
  RefreshNotifier? _refreshNotifier; // To hold the notifier instance

  @override
  void initState() {
    super.initState();
    print("AISuggestionsScreen: initState called");
    _futureSubs = SupabaseService().fetchSubscriptions();

    // Initial load
    _initializeProfileAndSuggestions();

    // Listen to RefreshNotifier after the first frame to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotifier = Provider.of<RefreshNotifier>(context, listen: false);
      _refreshNotifier?.addListener(_handleProfileRefreshTrigger);
      print("AISuggestionsScreen: Added listener to RefreshNotifier.");
    });
  }

  @override
  void dispose() {
    print("AISuggestionsScreen: dispose called");
    _refreshNotifier?.removeListener(_handleProfileRefreshTrigger);
    print("AISuggestionsScreen: Removed listener from RefreshNotifier.");
    super.dispose();
  }

  void _handleProfileRefreshTrigger() {
    print(
      "AISuggestionsScreen: Refresh triggered from notifier. Reloading profile and suggestions.",
    );
    _initializeProfileAndSuggestions();
  }

  Future<void> _initializeProfileAndSuggestions() async {
    if (!mounted) return;
    print("AISuggestionsScreen: Initializing profile and suggestions...");
    setState(() {
      _isLoadingProfileAndSuggestions = true;
      _errorMessage = null;
    });

    try {
      await _fetchUserProfile();
      if (mounted) {
        setState(() {
          _futureSuggestions = _fetchAISuggestions();
        });
      }
    } catch (e) {
      print("AISuggestionsScreen: Error during initial load: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load data: ${e.toString()}";
        });
      }
    } finally {
      // Set loading to false after _fetchAISuggestions future is set,
      // the FutureBuilder will handle its own loading state for suggestions.
      if (mounted) {
        setState(() {
          _isLoadingProfileAndSuggestions = false;
        });
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print(
        "AISuggestionsScreen: User not authenticated. Using default profile.",
      );
      _userProfile = UserProfile.defaultValues();
      return;
    }

    print("AISuggestionsScreen: Fetching user profile for $userId");
    try {
      final response =
          await supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (mounted) {
        if (response != null) {
          _userProfile = UserProfile.fromMap(response);
          print(
            "AISuggestionsScreen: User profile loaded: Interests: ${_userProfile?.interests}, Budget: ${_userProfile?.budget}, Country: ${_userProfile?.country}",
          );
        } else {
          print(
            "AISuggestionsScreen: No user profile found for user $userId. Using default profile.",
          );
          _userProfile = UserProfile.defaultValues();
        }
      }
    } catch (e) {
      print(
        "AISuggestionsScreen: Error fetching user profile: $e. Using default profile.",
      );
      if (mounted) {
        _userProfile = UserProfile.defaultValues();
      }
    }
  }

  Future<List<SuggestedSubscription>> _fetchAISuggestions() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print(
        "AISuggestionsScreen: Cannot fetch AI suggestions, user not authenticated.",
      );
      throw Exception('User is not authenticated.');
    }

    final profileToUse = _userProfile ?? UserProfile.defaultValues();

    print(
      "AISuggestionsScreen: Fetching AI suggestions with profile: Interests: ${profileToUse.interests}, Budget: ${profileToUse.budget}, Country: ${profileToUse.country}",
    );

    List<String> currentSubscriptionNames = [];
    try {
      final subsResponse = await supabase
          .from('subscriptions')
          .select('name')
          .eq('user_id', userId);
      currentSubscriptionNames =
          (subsResponse as List).map((s) => s['name'] as String).toList();
    } catch (e) {
      print(
        "AISuggestionsScreen: Error fetching current subscriptions for AI prompt: $e. Proceeding without them.",
      );
    }

    final payload = {
      'user_id': userId,
      'subscriptions':
          currentSubscriptionNames.isNotEmpty ? currentSubscriptionNames : null,
      'interests': profileToUse.interests,
      'budget': profileToUse.budget,
      'country': profileToUse.country,
    };
    print(
      "AISuggestionsScreen: Sending payload to Edge Function 'ai-suggestions': $payload",
    );

    try {
      final res = await supabase.functions.invoke(
        'ai-suggestions',
        body: payload,
      );

      if (res.status == 200) {
        final responseData = res.data as Map<String, dynamic>;
        if (responseData.containsKey('suggestions')) {
          final suggestionsList = responseData['suggestions'];
          if (suggestionsList is List) {
            print("AISuggestionsScreen: AI suggestions received and parsed.");
            return suggestionsList
                .map(
                  (item) => SuggestedSubscription.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList();
          } else {
            throw Exception(
              "'suggestions' field from Edge Function is not a list.",
            );
          }
        } else {
          throw Exception(
            "Edge Function response data does not contain 'suggestions' key.",
          );
        }
      } else {
        print(
          "AISuggestionsScreen: Edge function returned error status: ${res.status}, data: ${res.data}",
        );
        throw Exception(
          'Failed to fetch suggestions. Status: ${res.status}, Error: ${res.data?['error'] ?? 'Unknown server error'}',
        );
      }
    } catch (e) {
      print(
        "AISuggestionsScreen: Error invoking edge function or parsing response: $e",
      );
      throw e;
    }
  }

  Future<void> _addSuggestedSubToSupabase(SuggestedSubscription s) async {
    final userId = supabase.auth.currentUser?.id;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final currentContext = context;

    if (userId == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('User is not authenticated.')),
      );
      return;
    }

    try {
      DateTime nextPaymentDate;
      final billingCycleLower = s.billingCycle.toLowerCase();
      if (billingCycleLower == 'monthly') {
        nextPaymentDate = DateTime.now().add(const Duration(days: 30));
      } else if (billingCycleLower == 'yearly') {
        nextPaymentDate = DateTime.now().add(const Duration(days: 365));
      } else {
        print(
          "AISuggestionsScreen: Unknown billing cycle: ${s.billingCycle}, defaulting to monthly.",
        );
        nextPaymentDate = DateTime.now().add(const Duration(days: 30));
      }

      await supabase.from('subscriptions').insert({
        'user_id': userId,
        'name': s.name,
        'price': s.price,
        'billing_cycle':
            s.billingCycle.toLowerCase() == 'monthly' ? 'Monthly' : 'Yearly',
        'next_payment_date': nextPaymentDate.toIso8601String(),
        'is_shared': false,
      });

      if (!currentContext.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("${s.name} added to your subscriptions!")),
      );
      setState(() {
        _futureSubs = SupabaseService().fetchSubscriptions();
        // Optionally trigger a full profile and suggestions reload if adding a sub changes context for AI
        // _initializeProfileAndSuggestions();
      });
    } on PostgrestException catch (e) {
      if (!currentContext.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Failed to add: ${e.message}")),
      );
    } catch (e) {
      if (!currentContext.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Failed to add: $e")),
      );
    }
  }

  void _showSuggestionDetailsModal(SuggestedSubscription s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 12),
              Text(
                s.description.isNotEmpty
                    ? s.description
                    : 'No description available.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Price:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    "\$${s.price.toStringAsFixed(2)}",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Billing Cycle:",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    s.billingCycle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
                onPressed: () async {
                  Navigator.pop(modalContext);
                  await _addSuggestedSubToSupabase(s);
                },
                child: Text("Add to My Subscriptions"),
              ),
              SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
                onPressed: () => Navigator.pop(modalContext),
                child: Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSection() {
    return FutureBuilder<List<Subscription>>(
      future: _futureSubs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text("Error loading subscriptions chart: ${snapshot.error}"),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "No subscription data for chart. Add some subscriptions first!",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data!;
        final monthlyTotal = data
            .where((sub) => sub.billingCycle.toLowerCase() == 'monthly')
            .fold(0.0, (sum, sub) => sum + sub.price);
        final yearlyMonthlyAvg = data
            .where((sub) => sub.billingCycle.toLowerCase() == 'yearly')
            .fold(0.0, (sum, sub) => sum + sub.price / 12);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY:
                  (monthlyTotal > yearlyMonthlyAvg
                          ? monthlyTotal
                          : yearlyMonthlyAvg) *
                      1.3 +
                  20,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      switch (value.toInt()) {
                        case 0:
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("Monthly"),
                          );
                        case 1:
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text("Yearly (Avg)"),
                          );
                        default:
                          return Text("");
                      }
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Text(
                          _formatNumber(value),
                          style: TextStyle(
                            fontSize: 12, // Smaller font to prevent overflow
                            color: Colors.grey[700],
                          ),
                        ),
                      );
                    },
                    interval:
                        ((monthlyTotal > yearlyMonthlyAvg
                                    ? monthlyTotal
                                    : yearlyMonthlyAvg) *
                                1.3 +
                            20) /
                        5,
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: monthlyTotal,
                      width: 22,
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: yearlyMonthlyAvg,
                      width: 22,
                      color: Colors.lightBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    ((monthlyTotal > yearlyMonthlyAvg
                                ? monthlyTotal
                                : yearlyMonthlyAvg) *
                            1.3 +
                        20) /
                    5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsSection() {
    if (_isLoadingProfileAndSuggestions && _futureSuggestions == null) {
      return Center(
        child: CircularProgressIndicator(key: Key("initialSuggestionsLoader")),
      );
    }
    if (_errorMessage != null && _futureSuggestions == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initializeProfileAndSuggestions,
                child: Text("Retry Loading"),
              ),
            ],
          ),
        ),
      );
    }
    if (_futureSuggestions == null) {
      return Center(child: Text("Press 'Get New AI Suggestions' or refresh."));
    }

    return FutureBuilder<List<SuggestedSubscription>>(
      future: _futureSuggestions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(key: Key("suggestionsListLoader")),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Error loading suggestions: ${snapshot.error}",
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _futureSuggestions = _fetchAISuggestions();
                      });
                    },
                    child: Text("Retry Suggestions"),
                  ),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("No suggestions available right now."),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _futureSuggestions = _fetchAISuggestions();
                    });
                  },
                  child: Text("Get New Suggestions"),
                ),
              ],
            ),
          );
        }

        final suggestions = snapshot.data!;
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final s = suggestions[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(
                  s.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  s.description.isNotEmpty
                      ? s.description
                      : 'No description available',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${s.price.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).primaryColor,
                      ),
                      tooltip: 'Add to My Subscriptions',
                      onPressed: () => _addSuggestedSubToSupabase(s),
                    ),
                  ],
                ),
                onTap: () => _showSuggestionDetailsModal(s),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      "AISuggestionsScreen: build called. isLoadingProfileAndSuggestions: $_isLoadingProfileAndSuggestions",
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Suggestions'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh All Data',
            onPressed:
                _isLoadingProfileAndSuggestions
                    ? null
                    : _initializeProfileAndSuggestions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 2, child: _buildChartSection()),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "Recommended For You",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(flex: 3, child: _buildSuggestionsSection()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.auto_awesome),
          label: Text('Get New AI Suggestions'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12),
            textStyle: TextStyle(fontSize: 16),
          ),
          onPressed:
              _isLoadingProfileAndSuggestions
                  ? null
                  : () {
                    setState(() {
                      _isLoadingProfileAndSuggestions = true;
                      _futureSuggestions = _fetchAISuggestions().whenComplete(
                        () {
                          if (mounted) {
                            setState(
                              () => _isLoadingProfileAndSuggestions = false,
                            );
                          }
                        },
                      );
                    });
                  },
        ),
      ),
    );
  }
}

String _formatNumber(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  } else {
    return value.toStringAsFixed(0);
  }
}
