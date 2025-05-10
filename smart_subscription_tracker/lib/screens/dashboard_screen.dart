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
      final refreshNotifier = Provider.of<RefreshNotifier>(context, listen: false);
      refreshNotifier.addListener(_handleRefreshTrigger);
    });
  }

  @override
  void dispose() {
    print("DashboardScreen: dispose called (Instance: ${hashCode})");
    final refreshNotifier = Provider.of<RefreshNotifier>(context, listen: false);
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
      _futureSubscriptions = _supabaseService.fetchSubscriptions();
    });
  }

  Future<List<Subscription>> _loadInitial() async {
    return await _supabaseService.fetchSubscriptions();
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
      builder: (ctx) => AlertDialog(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name deleted successfully!')));
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscriptions());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete subscription: ${e.toString()}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadSubscriptions),
        ],
      ),
      body: FutureBuilder<List<Subscription>>(
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

          return ListView.builder(
            key: PageStorageKey(
              'dashboard_list',
            ), // Helps preserve scroll state
            controller: _scrollController,
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              return ListTile(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(null),
        child: Icon(Icons.add),
        tooltip: 'Add Subscription',
      ),
    );
  }
}
