import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/subscription.dart';
import '../notifiers/shared_refresh_notifier.dart';
import 'add_edit_subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin<DashboardScreen> {
  late Future<List<Subscription>> _futureSubscriptions;
  late ScrollController _scrollController;
  final SupabaseService _supabaseService = SupabaseService();
  List<Subscription> _subscriptions = [];
  String? _totalDropdownValue = 'Per Month';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("DashboardScreen: initState called (Instance: ${hashCode})");
    _scrollController = ScrollController();
    _futureSubscriptions = _loadInitial();

    // Listen for external refresh trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final refreshNotifier = Provider.of<RefreshNotifier>(
        context,
        listen: false,
      );
      refreshNotifier.addListener(_handleRefreshTrigger);
    });
  }

  @override
  void dispose() {
    print("DashboardScreen: dispose called (Instance: ${hashCode})");
    final refreshNotifier = Provider.of<RefreshNotifier>(
      context,
      listen: false,
    );
    refreshNotifier.removeListener(_handleRefreshTrigger);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRefreshTrigger() {
    print("DashboardScreen: Refresh triggered externally.");
    _loadSubscriptions();
  }

  void _loadSubscriptions() {
    if (!mounted) return;
    setState(() {
      _futureSubscriptions = _supabaseService.fetchSubscriptions().then((subs) {
        setState(() {
          _subscriptions = subs;
        });
        return subs;
      });
    });
  }

  Future<List<Subscription>> _loadInitial() async {
    final subscriptions = await _supabaseService.fetchSubscriptions();
    setState(() {
      _subscriptions = subscriptions;
    });
    return subscriptions;
  }

  Future<void> _navigateToEditScreen(Subscription? sub) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: AddEditSubscriptionScreen(existingSub: sub),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscriptions());
    }
  }

  Future<void> _deleteSubscription(String id, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete Subscription'),
            content: Text('Are you sure you want to delete "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete != true) return;

    try {
      await _supabaseService.deleteSubscription(id);
      if (!mounted) return;
      // Show SnackBar immediately after confirming widget is mounted
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name deleted successfully!')));
      // Refresh subscriptions after the frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSubscriptions();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete subscription: ${e.toString()}'),
        ),
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _subscriptions.removeAt(oldIndex);
      _subscriptions.insert(newIndex, item);
    });
    // Optionally: Save the new order to Supabase here
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadSubscriptions),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Subscription>>(
              key: ValueKey(_futureSubscriptions.hashCode),
              future: _futureSubscriptions,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Error: ${snapshot.error}"),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSubscriptions,
                          child: Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }

                final subscriptions = snapshot.data;
                if (subscriptions == null || subscriptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("No subscriptions found."),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _navigateToEditScreen(null),
                          child: Text("Add Subscription"),
                        ),
                      ],
                    ),
                  );
                }

                return ReorderableListView.builder(
                  key: PageStorageKey(
                    'dashboard_list',
                  ), // Helps preserve scroll state
                  // controller: _scrollController,
                  itemCount: _subscriptions.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    return ListTile(
                      key: ValueKey(sub.id),
                      title: Text(sub.name),
                      subtitle: Text(
                        "Price: \$${sub.price.toStringAsFixed(2)} | Next: ${sub.nextPaymentDate.toLocal().toString().split(' ')[0]}",
                      ),
                      onTap: () => _navigateToEditScreen(sub),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSubscription(sub.id, sub.name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildTotalSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(null),
        child: Icon(Icons.add),
        tooltip: 'Add Subscription',
      ),
    );
  }

  Widget _buildTotalSection() {
    double totalPerMonth = _subscriptions.fold(0.0, (sum, sub) {
      if (sub.billingCycle == 'Monthly') return sum + sub.price;
      if (sub.billingCycle == 'Yearly') return sum + (sub.price / 12);
      if (sub.billingCycle == 'Weekly') return sum + (sub.price * 4.34524);
      return sum;
    });

    double totalPerWeek = totalPerMonth / 4.34524;
    double totalPerYear = totalPerMonth * 12;

    String dropdownValue = _totalDropdownValue ?? 'Per Month';
    double displayTotal;
    switch (dropdownValue) {
      case 'Per Week':
        displayTotal = totalPerWeek;
        break;
      case 'Per Year':
        displayTotal = totalPerYear;
        break;
      default:
        displayTotal = totalPerMonth;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            'Total:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(width: 12),
          DropdownButton<String>(
            value: dropdownValue,
            items:
                ['Per Week', 'Per Month', 'Per Year']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
            onChanged: (val) {
              setState(() {
                _totalDropdownValue = val;
              });
            },
          ),
          SizedBox(width: 12),
          Text(
            '\$${displayTotal.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubscription(Subscription newSub) async {
    setState(() {
      _subscriptions.add(newSub); // Always add to the end
    });
    // Save to Supabase as needed
  }
}
