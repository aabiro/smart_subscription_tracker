import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart' as constants;

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final supabase = Supabase.instance.client;
  // Consider making this list configurable or fetched if it can change
  final List<String> _availableInterests = List.from(constants.kAllInterests);
  List<String> _selectedInterests = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSavingInterests = false; // For the save button loading state

  @override
  void initState() {
    super.initState();
    print("AccountScreen: initState called");
    _loadUserInterests();
  }

  Future<void> _loadUserInterests() async {
    if (!mounted) return;
    print("AccountScreen: Loading user interests...");
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "User not logged in. Please log in to see and update interests.";
          _isLoading = false;
        });
      }
      print("AccountScreen: User not logged in.");
      return;
    }

    try {
      // Fetch the user's profile. .select().eq().single() will throw
      // a PostgrestException if no row is found or more than one row is found.
      final response =
          await supabase
              .from('user_profiles')
              .select('interests') // Only select the interests column
              .eq('id', userId)
              .single(); // Expects exactly one row

      // If .single() doesn't throw, 'response' is the Map<String, dynamic> for the row
      print("AccountScreen: Fetched interests data: $response");

      if (mounted) {
        // The 'interests' column in user_profiles is TEXT[] which Supabase client
        // typically returns as List<dynamic>. We need to cast it to List<String>.
        final interestsData = response['interests'];
        if (interestsData != null && interestsData is List) {
          _selectedInterests = List<String>.from(
            interestsData.map((item) => item.toString()),
          );
          print(
            "AccountScreen: Selected interests loaded: $_selectedInterests",
          );
        } else {
          _selectedInterests =
              []; // Default to empty list if null or not a list
          print(
            "AccountScreen: No interests found in profile or incorrect format, defaulting to empty.",
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        // Handle cases like PGRST116 (0 rows requested, but 0 rows found) if profile doesn't exist
        if (e.code == 'PGRST116') {
          print(
            "AccountScreen: No user profile found for user $userId. User can set interests.",
          );
          _selectedInterests = []; // Default to empty list
        } else {
          print(
            "AccountScreen: PostgrestException loading interests: ${e.message}",
          );
          _errorMessage = "Error loading interests: ${e.message}";
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print("AccountScreen: Generic error loading interests: $e");
        setState(() {
          _errorMessage = "Error loading interests: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserInterests() async {
    if (!mounted) return;
    setState(() => _isSavingInterests = true);

    final userId = supabase.auth.currentUser?.id;
    final scaffoldMessenger = ScaffoldMessenger.of(
      context,
    ); // Capture for async gap

    if (userId == null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("User not logged in. Cannot save.")),
        );
        setState(() => _isSavingInterests = false);
      }
      return;
    }

    print(
      "AccountScreen: Updating interests for user $userId with: $_selectedInterests",
    );

    try {
      // .update() does not return data by default.
      // It will throw a PostgrestException if the update fails (e.g., RLS, constraint violation).
      await supabase
          .from('user_profiles')
          .update({'interests': _selectedInterests})
          .eq('id', userId); // Ensure this targets the correct user profile row

      // If no exception is thrown, the update was successful.
      if (mounted) {
        print("AccountScreen: Interests updated successfully on Supabase.");
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Interests updated successfully!")),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        print(
          "AccountScreen: PostgrestException updating interests: ${e.message}",
        );
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Failed to update interests: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        print("AccountScreen: Generic error updating interests: $e");
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Failed to update interests: ${e.toString()}"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingInterests = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "AccountScreen: build method called. isLoading: $_isLoading, errorMessage: $_errorMessage",
    );
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Account & Preferences'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUserInterests,
            tooltip: "Refresh Interests",
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadUserInterests,
                        child: Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
              : SingleChildScrollView(
                // Added SingleChildScrollView for scrollability
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email: ${user?.email ?? 'Not logged in'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Your Interests:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _availableInterests.map((interest) {
                            final selected = _selectedInterests.contains(
                              interest,
                            );
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: FilterChip(
                                label: Text(
                                  interest,
                                  style: TextStyle(
                                    color:
                                        selected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedInterests.add(interest);
                                    } else {
                                      _selectedInterests.remove(interest);
                                    }
                                  });
                                },
                                selectedColor:
                                    Colors
                                        .blue, // Background color when selected
                                backgroundColor:
                                    Colors
                                        .grey[300], // Background color when not selected
                                checkmarkColor: Colors.white, // Checkmark color
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          _isSavingInterests ? null : _updateUserInterests,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                      ),
                      child:
                          _isSavingInterests
                              ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : Text(
                                'Save Interests',
                                style: TextStyle(fontSize: 16),
                              ),
                    ),
                    SizedBox(height: 30),
                    Center(
                      // Center the logout button
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.logout),
                        label: Text('Log out'),
                        onPressed: () async {
                          try {
                            await supabase.auth.signOut();
                            // Ensure context is still valid before navigating
                            if (mounted) {
                              Navigator.pushReplacementNamed(context, '/auth');
                            }
                          } catch (e) {
                            print("Error during sign out: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error signing out: ${e.toString()}',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
