import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/suggestions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_edit_subscription_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/import_subscriptions_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/ai_suggestions_screen.dart';
import 'screens/account_screen.dart';
import 'notifiers/shared_refresh_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth_screen.dart' as local_auth;
import 'utils/constants.dart' as constants;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print("FlutterError: ${details.exceptionAsString()}");
    print("Stack trace: ${details.stack}");
  };

  runZonedGuarded(() {
     runApp(
        ChangeNotifierProvider(
          create: (_) => RefreshNotifier(),
          child: MyApp(),
        ),
      );

  }, (error, stackTrace) {
    print("Uncaught error: $error");
    print("Stack trace: $stackTrace");
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return SubscriptionTrackerApp(preferencesCompleted: snapshot.data as bool);
        }
      },
    );
  }

  Future<bool> initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    print("Attempting to initialize Supabase with:");
    print("URL: '${constants.supabaseUrl}'");
    print(
      "Anon Key: '${constants.anonKey}'",
    ); // Good to check this isn't empty/null too

    try {
      await Supabase.initialize(
        url: constants.supabaseUrl,
        anonKey: constants.anonKey,
      );
      print("Supabase.initialize call completed successfully.");
    } catch (e) {
      print("Error during Supabase.initialize: $e");
      // If host lookup fails here, this catch block should grab it.
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('preferencesCompleted') ?? false;
  }
}

class SubscriptionTrackerApp extends StatelessWidget {
  final bool preferencesCompleted;

  SubscriptionTrackerApp({required this.preferencesCompleted});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.indigo),
      debugShowCheckedModeBanner: false,
      home: // Show UserPreferencesScreen in debug mode
          (session == null
              ? local_auth.AuthScreen()
              : (kDebugMode
                  ? UserPreferencesScreen() // Show UserPreferencesScreen in debug mode
                  : (preferencesCompleted
                      ? HomeScreen() // Show HomeScreen if preferences are completed
                      : UserPreferencesScreen()))), 
      routes: {
        '/home': (context) => HomeScreen(),
        '/auth': (context) => local_auth.AuthScreen(),
        '/add-edit': (context) => AddEditSubscriptionScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/account': (context) => AccountScreen(),
        '/preferences': (context) => UserPreferencesScreen(),
        '/ai-suggestions': (context) => AISuggestionsScreen(),
        '/suggestions': (context) => SuggestionsScreen(
          onSubscriptionAdded: () {
            // Handle the subscription added logic here
            // For example, you can navigate to the home screen or show a message
            Navigator.pushReplacementNamed(context, '/home');
            print('Subscription added');
          },
        ),
        '/import': (context) => ImportSubscriptionsScreen(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
