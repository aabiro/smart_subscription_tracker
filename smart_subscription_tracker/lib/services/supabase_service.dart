import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/suggested_subscription.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<List<SuggestedSubscription>> fetchSuggestions(
    String userId,
    List<String> subscriptions,
    List<String> interests,
    double budget,
    String country,
  ) async {
    final supabase = Supabase.instance.client;
    final jwtToken = supabase.auth.currentSession?.accessToken;

    if (jwtToken == null) {
      throw Exception("User is not authenticated. Missing JWT token.");
    }

    final url = Uri.parse(
      'https://pjwaiolqaegmcgjvyxdh.supabase.co/functions/v1/ai-suggestions',
    );
    final body = {
      'user_id': userId,
      'subscriptions': subscriptions,
      'interests': interests,
      'budget': budget,
      'country': country,
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwtToken',
    };

    print("SupabaseService: Making POST request to $url");
    print("SupabaseService: Request Headers: $headers");
    print("SupabaseService: Request Body: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    print("SupabaseService: Response Status Code: ${response.statusCode}");
    print("SupabaseService: Response Body: ${response.body}");

    if (response.statusCode == 429) {
      throw Exception(
        "Quota exceeded. Please check your OpenAI plan and billing details.",
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to fetch data: ${response.statusCode} - ${response.body}",
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map || decoded['suggestions'] is! List) {
      throw Exception("Unexpected response format: $decoded");
    }

    final data = decoded['suggestions'] as List<dynamic>;

    return data
        .map(
          (json) =>
              SuggestedSubscription.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<Subscription>> fetchSubscriptions() async {
    final response =
        await Supabase.instance.client.from('subscriptions').select();

    if (response == null || response is! List) {
      throw Exception(
        "Failed to fetch subscriptions: Unexpected response format",
      );
    }

    return response
        .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> addSubscription(Subscription sub) async {
    final userId = client.auth.currentUser!.id;
    await client.from('subscriptions').insert({
      'user_id': userId,
      'name': sub.name,
      'price': sub.price,
      'billing_cycle': sub.billingCycle,
      'next_payment_date': sub.nextPaymentDate.toIso8601String(),
      'is_shared': sub.isShared,
    });
  }

  Future<void> updateSubscription(Subscription sub) async {
    await client
        .from('subscriptions')
        .update({
          'name': sub.name,
          'price': sub.price,
          'billing_cycle': sub.billingCycle,
          'next_payment_date': sub.nextPaymentDate.toIso8601String(),
          'is_shared': sub.isShared,
        })
        .eq('id', sub.id ?? '');
  }

  Future<List<SuggestedSubscription>> fetchCachedSuggestions() async {
    final userId = client.auth.currentUser?.id;

    final response = await client
        .from('suggestions')
        .select('*')
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (data) => SuggestedSubscription(
            name: data['name'],
            description: data['description'],
            price: data['price'].toDouble(),
            billingCycle: data['billing_cycle'],
          ),
        )
        .toList();
  }

  Future<void> deleteSubscription(String subscriptionId) async {
    try {
      // Perform the delete operation.
      // No .execute() is needed here. Awaiting the builder directly executes it.
      await Supabase.instance.client
          .from('subscriptions')
          .delete()
          .eq(
            'id',
            subscriptionId,
          ); // Ensure 'id' is the correct primary key column name

      // If no exception is thrown, the deletion was successful (or no matching row was found, which isn't an error for delete).
      print(
        "Subscription with ID: $subscriptionId deleted successfully (or did not exist).",
      );
    } on PostgrestException catch (error) {
      // Handle specific PostgREST errors (e.g., RLS issues, network problems during the request)
      print("Failed to delete subscription: ${error.message}");
      print("PostgREST Error Code: ${error.code}");
      print("PostgREST Error Details: ${error.details}");
      print("PostgREST Error Hint: ${error.hint}");
      throw Exception("Failed to delete subscription: ${error.message}");
    } catch (error) {
      // Handle any other unexpected errors
      print("An unexpected error occurred while deleting subscription: $error");
      throw Exception("An unexpected error occurred: $error");
    }
  }
}
