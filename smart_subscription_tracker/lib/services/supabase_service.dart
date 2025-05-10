import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/suggested_subscription.dart';

class SupabaseService {
  final client = Supabase.instance.client;

  Future<List<SuggestedSubscription>> fetchSuggestions(
    List<String> subs,
    List<String> interests,
    double budget,
    String country,
  ) async {
    final response = await http.post(
      Uri.parse(
        'https://pjwaiolqaegmcgjvyxdh.functions.supabase.co/suggest_subscriptions',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subscriptions': subs,
        'interests': interests,
        'budget': budget,
        'country': country,
      }),
    );

    final text = jsonDecode(response.body)['suggestions'] as String;

    final suggestions = <SuggestedSubscription>[];

    final lines = text.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      final parts = RegExp(
        r'^(?:\d+\.\s*)?(.*?)[–\-](.*?)(\$\d+)?$',
      ).firstMatch(line);
      if (parts != null) {
        final name = parts.group(1)?.trim() ?? '';
        final desc = parts.group(2)?.trim() ?? '';
        final price =
            double.tryParse(
              parts.group(3)?.replaceAll(RegExp(r'[^\d.]'), '') ?? '0',
            ) ??
            0;
        suggestions.add(
          SuggestedSubscription(
            id: '', // Provide a default or appropriate value for id
            name: name,
            description: desc,
            price: price,
            billingCycle: 'Monthly', 
            createdAt: DateTime.timestamp(),
          ),
        );
      }
    }

    return suggestions;
  }

  Future<List<Subscription>> fetchSubscriptions() async {
    final response = await Supabase.instance.client
        .from('subscriptions')
        .select();

    if (response == null || response is! List) {
      throw Exception("Failed to fetch subscriptions: Unexpected response format");
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
            id: data['id'],
            name: data['name'],
            description: data['description'],
            price: data['price'].toDouble(),
            billingCycle: data['billing_cycle'], 
            createdAt: data['created_at']
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
