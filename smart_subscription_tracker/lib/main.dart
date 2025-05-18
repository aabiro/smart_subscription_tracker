import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/suggestions_screen_intro.dart';
import 'screens/home_screen.dart';
import 'screens/add_edit_subscription_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/import_subscriptions_screen.dart';
import 'screens/user_preferences_screen.dart';
import 'screens/ai_suggestions_screen.dart';
import 'screens/account_screen.dart';
import 'notifiers/shared_refresh_notifier.dart';
import 'screens/auth_screen.dart' as local_auth;
import 'utils/constants.dart' as constants;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <-- Move this to the top!

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print("FlutterError: ${details.exceptionAsString()}");
    print("Stack trace: ${details.stack}");
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: '${constants.supabaseUrl}',
    anonKey: '${constants.anonKey}',
  );

  runZonedGuarded(
    () {
      runApp(
        ChangeNotifierProvider(
          create: (_) => RefreshNotifier(),
          child: MyApp(),
        ),
      );
    },
    (error, stackTrace) {
      print("Uncaught error: $error");
      print("Stack trace: $stackTrace");
    },
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: fetchPreferencesCompleted(),
      builder: (context, snapshot) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[100],
            textTheme: TextTheme(
              titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              bodyMedium: TextStyle(fontSize: 16),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.grey[200]!,
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(fontSize: 14),
            ),
          ),
          home: _buildHome(snapshot),
          routes: {
            '/home': (context) => HomeScreen(),
            '/auth': (context) => local_auth.AuthScreen(),
            '/add-edit': (context) => AddEditSubscriptionScreen(),
            '/dashboard': (context) => DashboardScreen(),
            '/account': (context) => AccountScreen(),
            '/preferences': (context) => UserPreferencesScreen(),
            '/ai-suggestions': (context) => AISuggestionsScreen(),
            '/suggestions':
                (context) => SuggestionsScreenIntro(
                  onSubscriptionAdded: () {
                    Navigator.pushReplacementNamed(context, '/home');
                    print('Subscription added');
                  },
                ),
            '/import': (context) => ImportSubscriptionsScreen(),
          },
        );
      },
    );
  }

  Widget _buildHome(AsyncSnapshot<bool> snapshot) {
    final session = Supabase.instance.client.auth.currentSession;
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    } else {
      final preferencesCompleted = snapshot.data ?? false;
      return (session == null
          ? local_auth.AuthScreen()
          : (kDebugMode
              ? UserPreferencesScreen()
              : (preferencesCompleted
                  ? HomeScreen()
                  : UserPreferencesScreen())));
    }
  }

  Future<bool> fetchPreferencesCompleted() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;
    final userId = session.user.id;
    final profile =
        await Supabase.instance.client
            .from('user_profiles')
            .select('preferences_completed')
            .eq('id', userId)
            .maybeSingle();
    return profile?['preferences_completed'] == true;
  }
}

class SubscriptionTrackerApp extends StatelessWidget {
  final bool preferencesCompleted;

  SubscriptionTrackerApp({required this.preferencesCompleted});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200]!,
          selectedColor: Colors.blue[100],
          labelStyle: TextStyle(fontSize: 14),
        ),
      ),
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
        '/suggestions':
            (context) => SuggestionsScreenIntro(
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
