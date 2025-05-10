import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Get the Supabase auth client
  final GoTrueClient _auth = Supabase.instance.client.auth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      print("Attempting to sign in with email: $email");
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      print("Sign in successful for user: ${response.user?.email}");
      if (mounted) {
        if (response.user != null) {
          // Check if preferences are completed
          final prefs = await SharedPreferences.getInstance();
          final preferencesCompleted = prefs.getBool('preferencesCompleted') ?? false;

          if (preferencesCompleted) {
            // Navigate to the main app screen
            Navigator.pushReplacementNamed(context, '/');
          } else {
            // Navigate to the UserPreferencesScreen
            Navigator.pushReplacementNamed(context, '/preferences');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login successful, but user data is null. Please confirm your email if required.',
              ),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      print("Sign in error: ${e.message}, statusCode: ${e.statusCode}");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login Failed: ${e.message}')));
      }
    } catch (e) {
      print("Unexpected error during sign in: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      print("Attempting to sign up with email: $email");
      final response = await _auth.signUp(
        email: email,
        password: password,
        // You can add emailRedirectTo if you have email confirmation enabled
        // and want to redirect users after they click the confirmation link.
        // emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );

      print(
        "Sign up response for user: ${response.user?.email}, session: ${response.session}",
      );

      if (mounted) {
        if (response.user != null) {
           // Set preferencesCompleted to false for new users
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('preferencesCompleted', false);
          // User object exists. Check if email confirmation is required by your Supabase settings.
          // If "Confirm email" is ON in Supabase Auth settings, response.user will exist,
          // but response.session will be null until the email is confirmed.
          if (response.session == null &&
              response.user!.emailConfirmedAt == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sign up successful! Please check your email to confirm your account.',
                ),
              ),
            );
            // Optionally, navigate to a "please confirm email" page or stay on auth screen
          } else {
            // Email confirmation might be off, or user is already confirmed (less likely for immediate signUp)
            // or auto-confirmed.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign up successful!')),
            );
            Navigator.pushReplacementNamed(
              context,
              '/',
            ); // Navigate to home or main app screen
          }
        } else {
          // This case is unusual if signUp doesn't throw an error but user is null.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sign up completed, but no user data returned. Please try logging in.',
              ),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      print("Sign up error: ${e.message}, statusCode: ${e.statusCode}");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign Up Failed: ${e.message}')));
      }
    } catch (e) {
      print("Unexpected error during sign up: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: Center(
        // Center the content
        child: SingleChildScrollView(
          // Allow scrolling if content overflows
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: ConstrainedBox(
            // Limit the width of the form
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
              children: [
                Text(
                  'Welcome!',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _signIn,
                      child: const Text('Login'),
                    ),
                const SizedBox(height: 12),
                _isLoading
                    ? const SizedBox.shrink() // Hide sign up button when loading
                    : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                        backgroundColor:
                            Colors.green, // Different color for sign up
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _signUp,
                      child: const Text('Sign Up'),
                    ),
                // Optionally, add a "Forgot Password?" button or social logins here
              ],
            ),
          ),
        ),
      ),
    );
  }
}
