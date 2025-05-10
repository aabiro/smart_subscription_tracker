import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/material.dart';
import '../services/supabase_service.dart'; // Assuming this path is correct
import '../models/subscription.dart'; // Assuming this path is correct
import 'add_edit_subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin<DashboardScreen> {
  late Future<List<Subscription>> _futureSubscriptions;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  bool get wantKeepAlive => true; // Important for IndexedStack

  @override
  void initState() {
    super.initState();
    print("DashboardScreen: initState called (Instance: ${hashCode})");
    _loadSubscriptions();
  }

  @override
  void dispose() {
    print("DashboardScreen: dispose called (Instance: ${hashCode})");
    super.dispose();
  }

  void _loadSubscriptions() {
    print("DashboardScreen: _loadSubscriptions called (Instance: ${hashCode})");
    if (mounted) {
      print(
        "DashboardScreen: _loadSubscriptions - widget is mounted, calling setState (Instance: ${hashCode})",
      );
      setState(() {
        _futureSubscriptions = _supabaseService.fetchSubscriptions();
      });
    } else {
      print(
        "DashboardScreen: _loadSubscriptions - widget is NOT mounted, setState NOT called (Instance: ${hashCode})",
      );
    }
  }

  Future<void> _navigateToEditScreen(Subscription? sub) async {
    final BuildContext currentScreenContext = context;
    final currentInstanceHashCode = hashCode;
    print(
      "DashboardScreen: _navigateToEditScreen (as bottom sheet) called for sub: ${sub?.name ?? 'new'} (Instance: $currentInstanceHashCode)",
    );

    // Use showModalBottomSheet instead of Navigator.push
    final result = await showModalBottomSheet<bool>(
      context: currentScreenContext,
      isScrollControlled:
          true, // Allows the sheet to take up more screen height if needed
      backgroundColor: Colors.transparent, // Optional: for custom shaped sheets
      builder: (BuildContext bottomSheetContext) {
        // You might want to wrap AddEditSubscriptionScreen in a container
        // to give it specific height constraints or rounded corners for the bottom sheet aesthetic.
        // For simplicity, we'll directly return it.
        // AddEditSubscriptionScreen handles its own scrolling with a ListView.
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Start at 70% of screen height
          minChildSize: 0.4, // Min at 40%
          maxChildSize: 0.9, // Max at 90%
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      bottomSheetContext,
                    ).canvasColor, // Use theme's canvas color
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: AddEditSubscriptionScreen(existingSub: sub),
              // If AddEditSubscriptionScreen didn't have its own Scaffold/AppBar,
              // you might need to provide one here or structure it differently.
              // Since it has an AppBar, it will be part of the sheet's content.
            );
          },
        );
      },
    );

    print(
      "DashboardScreen: Returned from AddEditScreen (bottom sheet) with result: $result. Widget is mounted: $mounted (Instance: $currentInstanceHashCode)",
    );

    if (result == true && mounted) {
      print(
        "DashboardScreen: AddEditScreen (bottom sheet) reported success. Scheduling _loadSubscriptions. (Instance: $currentInstanceHashCode)",
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print(
          "DashboardScreen: PostFrameCallback executing. Widget is mounted: $mounted (Instance: $currentInstanceHashCode)",
        );
        if (mounted) {
          print(
            "DashboardScreen: PostFrameCallback - Calling _loadSubscriptions. (Instance: $currentInstanceHashCode)",
          );
          _loadSubscriptions();
        } else {
          print(
            "DashboardScreen: PostFrameCallback - Widget (Instance: $currentInstanceHashCode) became unmounted before _loadSubscriptions could be called.",
          );
        }
      });
    } else {
      if (!mounted) {
        print(
          "DashboardScreen: Widget (Instance: $currentInstanceHashCode) unmounted after returning from AddEditScreen (bottom sheet). Aborting refresh.",
        );
      } else {
        print(
          "DashboardScreen: AddEditScreen (bottom sheet) did not report success. Result: $result (Instance: $currentInstanceHashCode)",
        );
      }
    }
  }

  Future<void> _deleteSubscription(
    String subscriptionId,
    String subscriptionName,
  ) async {
    final currentScreenContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(currentScreenContext);
    final currentInstanceHashCode = hashCode;
    print(
      "DashboardScreen: _deleteSubscription called for ID: $subscriptionId, Name: $subscriptionName (Instance: $currentInstanceHashCode)",
    );

    final shouldDelete = await showDialog<bool>(
      context: currentScreenContext,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Delete Subscription'),
            content: Text(
              'Are you sure you want to delete "$subscriptionName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Delete'),
              ),
            ],
          ),
    );
    print(
      "DashboardScreen: Delete confirmation result: $shouldDelete (Instance: $currentInstanceHashCode)",
    );

    if (!mounted) {
      print(
        "DashboardScreen: Widget (Instance: $currentInstanceHashCode) unmounted after delete confirmation dialog. Aborting delete.",
      );
      return;
    }

    if (shouldDelete == true) {
      try {
        await _supabaseService.deleteSubscription(subscriptionId);
        print(
          "DashboardScreen: Subscription deleted successfully from service. (Instance: $currentInstanceHashCode)",
        );
        if (!mounted) {
          print(
            "DashboardScreen: Widget (Instance: $currentInstanceHashCode) not mounted after delete service call.",
          );
          return;
        }
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('$subscriptionName deleted successfully!')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print(
              "DashboardScreen: PostFrameCallback for delete - Calling _loadSubscriptions. (Instance: $currentInstanceHashCode)",
            );
            _loadSubscriptions();
          } else {
            print(
              "DashboardScreen: PostFrameCallback for delete - Widget (Instance: $currentInstanceHashCode) became unmounted.",
            );
          }
        });
      } catch (e) {
        if (!mounted) {
          print(
            "DashboardScreen: Widget (Instance: $currentInstanceHashCode) not mounted after delete service call error.",
          );
          return;
        }
        print(
          "Error deleting subscription on dashboard: $e (Instance: $currentInstanceHashCode)",
        );
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete subscription: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print("DashboardScreen: build method called (Instance: ${hashCode})");
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSubscriptions,
            tooltip: 'Refresh Subscriptions',
          ),
        ],
      ),
      body: FutureBuilder<List<Subscription>>(
        key: ValueKey(_futureSubscriptions.hashCode),
        future: _futureSubscriptions,
        builder: (context, snapshot) {
          print(
            "DashboardScreen: FutureBuilder builder called - ConnectionState: ${snapshot.connectionState} (Instance: ${hashCode})",
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
            print(
              "DashboardScreen: FutureBuilder - Waiting for data... (Instance: ${hashCode})",
            );
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print(
              "DashboardScreen: FutureBuilder - Error: ${snapshot.error} (Instance: ${hashCode})",
            );
            print(
              "DashboardScreen: FutureBuilder - Stack trace: ${snapshot.stackTrace} (Instance: ${hashCode})",
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Error loading subscriptions: ${snapshot.error}",
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadSubscriptions,
                      child: Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          final subscriptions = snapshot.data;
          print(
            "DashboardScreen: FutureBuilder - Snapshot data: ${subscriptions == null ? 'null' : 'received ${subscriptions.length} items'} (Instance: ${hashCode})",
          );

          if (subscriptions == null || subscriptions.isEmpty) {
            print(
              "DashboardScreen: FutureBuilder - No subscriptions found or data is null. (Instance: ${hashCode})",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("No subscriptions found. Add your first one!"),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _navigateToEditScreen(null),
                    child: Text("Add Subscription"),
                  ),
                ],
              ),
            );
          }

          print(
            "DashboardScreen: FutureBuilder - Rendering ListView with ${subscriptions.length} items. (Instance: ${hashCode})",
          );
          return ListView.builder(
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
                  tooltip: 'Delete Subscription',
                  onPressed: () => _deleteSubscription(sub.id, sub.name),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(null),
        tooltip: 'Add Subscription',
        child: Icon(Icons.add),
      ),
    );
  }
}
