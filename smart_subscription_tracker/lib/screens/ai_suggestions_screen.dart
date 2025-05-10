import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/suggested_subscription.dart';
import '../models/subscription.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AISuggestionsScreen extends StatefulWidget {
  @override
  _AISuggestionsScreenState createState() => _AISuggestionsScreenState();
}

class _AISuggestionsScreenState extends State<AISuggestionsScreen> {
  late Future<List<Subscription>> _futureSubs;
  late Future<List<SuggestedSubscription>> _futureSuggestions;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Initialize the futures
    _futureSubs = SupabaseService().fetchSubscriptions();
    _futureSuggestions = SupabaseService().fetchCachedSuggestions();
  }

  Future<void> addSuggestedSubToSupabase(SuggestedSubscription s) async {
    final response = await supabase.from('subscriptions').insert({
      'name': s.name,
      'price': s.price,
      'billing_cycle': 'Monthly',
      'next_payment_date': DateTime.now().toIso8601String(),
      'is_shared': false,
    });

    if (response.error != null) {
      throw Exception('Failed to add: ${response.error!.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Smart Suggestions')),
      body: Column(
        children: [
          // Bar chart for monthly and yearly totals
          Expanded(
            flex: 2,
            child: FutureBuilder<List<Subscription>>(
              future: _futureSubs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error loading subscriptions: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No subscriptions found."));
                }

                final data = snapshot.data!;
                final monthly = data
                    .where((sub) => sub.billingCycle == 'Monthly')
                    .fold(0.0, (sum, sub) => sum + sub.price);
                final yearly = data
                    .where((sub) => sub.billingCycle == 'Yearly')
                    .fold(0.0, (sum, sub) => sum + sub.price / 12);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BarChart(
                    BarChartData(
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              switch (value.toInt()) {
                                case 0:
                                  return Text("Monthly");
                                case 1:
                                  return Text("Yearly (monthly avg)");
                                default:
                                  return Text("");
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                      ),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [BarChartRodData(toY: monthly)],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [BarChartRodData(toY: yearly)],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Suggestions section
          Expanded(
            flex: 3,
            child: FutureBuilder<List<SuggestedSubscription>>(
              future: _futureSuggestions,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error loading suggestions: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No suggestions yet."));
                }

                final suggestions = snapshot.data!;
                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final s = suggestions[index];
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text(s.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${s.price.toStringAsFixed(2)}'),
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.green), // Add a + icon
                            onPressed: () async {
                              try {
                                await addSuggestedSubToSupabase(s);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${s.name} added to your subscriptions!"),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Failed to add: $e")),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
