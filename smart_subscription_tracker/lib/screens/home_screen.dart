import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'import_subscriptions_screen.dart';
import 'ai_suggestions_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    DashboardScreen(),
    AISuggestionsScreen(),
    ImportSubscriptionsScreen(),
  ];

  void _onMenuItemSelected(String value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (value == 'settings') {
        print("Navigating to Settings");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AccountScreen()),
        );
      } else if (value == 'logout') {
        print("Logging out");
        Supabase.instance.client.auth.signOut();
        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Building HomeScreen with currentIndex: $_currentIndex");
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Subscriptions'),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Icon(Icons.person, color: Colors.white),
            ),
            onSelected: _onMenuItemSelected,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          print("BottomNavigationBar tapped, new index: $index");
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'AI Suggestions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.import_export),
            label: 'Import',
          ),
        ],
      ),
    );
  }
}
