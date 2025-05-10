import 'dart:convert'; // Import for jsonDecode
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase for auth token

class ApiHelper {
  // Changed return type from Future<dynamic> to Future<Map<String, dynamic>>
  static Future<Map<String, dynamic>> fetchData({
    required String url,
    Map<String, String>? headers, // Allow passing custom headers
    Map<String, dynamic>? body, // For POST requests
    Map<String, dynamic>? mockData,
    bool requiresAuth = true, // Add a flag to indicate if auth is needed
  }) async {
    // In debug mode, if mockData is provided, return it.
    if (kDebugMode && mockData != null) {
      print("ApiHelper (Debug): Returning mock data for $url");
      // Ensure mockData is returned as a Future<Map<String, dynamic>>
      return Future.value(mockData);
    }

    // Prepare headers
    // Create a new map to avoid modifying the original headers map if passed in.
    final Map<String, String> requestHeaders = Map<String, String>.from(
      headers ?? {},
    );

    if (!requestHeaders.containsKey('Content-Type') && body != null) {
      requestHeaders['Content-Type'] = 'application/json';
    }

    // Add Supabase Auth token if required
    if (requiresAuth) {
      final supabaseInstance = Supabase.instance.client;
      final session = supabaseInstance.auth.currentSession;

      if (session?.accessToken == null) {
        print(
          "ApiHelper: Auth required but no active session/access token found for $url",
        );
        // It's better to throw a specific error type or handle this more gracefully
        // depending on how the calling code expects to manage auth failures.
        throw Exception("Authentication required: No active session.");
      }
      requestHeaders['Authorization'] = 'Bearer ${session!.accessToken}';
      print("ApiHelper: Authorization header added for $url");
    }

    print("ApiHelper: Request Headers for $url: $requestHeaders");

    try {
      http.Response response;
      final uri = Uri.parse(url);

      if (body != null) {
        print(
          "ApiHelper: Making POST request to $url with body: ${jsonEncode(body)}",
        ); // Log encoded body
        response = await http.post(
          uri,
          headers: requestHeaders,
          body: jsonEncode(body),
        );
      } else {
        print("ApiHelper: Making GET request to $url");
        response = await http.get(uri, headers: requestHeaders);
      }

      print("ApiHelper: Response status code: ${response.statusCode} for $url");

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        // Ensure the decoded body is a Map<String, dynamic>
        if (decodedBody is Map<String, dynamic>) {
          print("ApiHelper: Successfully fetched and decoded data for $url");
          return decodedBody;
        } else {
          // This case might happen if the API returns a JSON list or a primitive directly,
          // which would not match Future<Map<String, dynamic>>.
          print(
            "ApiHelper: Decoded JSON is not a Map<String, dynamic>. Actual type: ${decodedBody.runtimeType}, Body: ${response.body}",
          );
          throw Exception(
            "API returned data in an unexpected format. Expected a JSON object (Map<String, dynamic>).",
          );
        }
      } else {
        // Attempt to parse error from response body
        String errorMessageFromServer = response.body; // Default to raw body
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map &&
              errorJson.containsKey('error') &&
              errorJson['error'] != null) {
            errorMessageFromServer = "Server error: ${errorJson['error']}";
          } else if (errorJson is Map &&
              errorJson.containsKey('message') &&
              errorJson['message'] != null) {
            errorMessageFromServer = "Server error: ${errorJson['message']}";
          }
        } catch (_) {
          // Ignore if body is not JSON or doesn't have expected error structure
          print(
            "ApiHelper: Response body was not valid JSON or did not contain a standard error message field.",
          );
        }
        print(
          "ApiHelper: Failed to fetch data from $url. Status: ${response.statusCode}, Reason: ${response.reasonPhrase}, Body: ${response.body}",
        );
        throw Exception(
          "Failed to fetch data: ${response.statusCode} - ${response.reasonPhrase}. $errorMessageFromServer",
        );
      }
    } catch (e) {
      // Catch network errors, JSON parsing errors, or exceptions re-thrown from above
      print(
        "ApiHelper: Error during network request or processing for $url: $e",
      );
      // Re-throw the exception so the FutureBuilder or calling code can catch it
      throw Exception("Error fetching data: $e");
    }
  }
}
