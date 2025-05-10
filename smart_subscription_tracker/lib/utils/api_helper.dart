import 'dart:convert'; // Import for jsonDecode
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiHelper {
  // Changed return type from Future<dynamic> to Future<Map<String, dynamic>>
  static Future<Map<String, dynamic>> fetchData({
    required String url,
    Map<String, String>? headers,
    Map<String, dynamic>? body, // For POST requests
    Map<String, dynamic>? mockData,
  }) async {
    if (kDebugMode && mockData != null) {
      print("Debug mode: Returning mock data for $url");
      // Ensure mockData is returned as a Future<Map<String, dynamic>>
      return Future.value(mockData);
    }

    // Make actual API call
    try {
      http.Response response;
      final uri = Uri.parse(url);

      if (body != null) {
        print("API Helper: Making POST request to $url with body: $body");
        response = await http.post(
          uri,
          headers: headers ?? {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        print("API Helper: Making GET request to $url");
        response = await http.get(uri, headers: headers);
      }

      print(
        "API Helper: Response status code: ${response.statusCode} for $url",
      );

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        // Ensure the decoded body is a Map<String, dynamic>
        if (decodedBody is Map<String, dynamic>) {
          return decodedBody;
        } else {
          // This case might happen if the API returns a JSON list or a primitive directly,
          // which would not match Future<Map<String, dynamic>>.
          // Adjust based on your actual API response structure.
          // For the AI suggestions, the root is expected to be a map like {"suggestions": [...]}.
          print(
            "API Helper: Decoded JSON is not a Map<String, dynamic>. Actual type: ${decodedBody.runtimeType}",
          );
          throw Exception(
            "API returned data in an unexpected format. Expected a JSON object.",
          );
        }
      } else {
        print(
          "API Helper: Failed to fetch data from $url. Status: ${response.statusCode}, Body: ${response.body}",
        );
        throw Exception(
          "Failed to fetch data: ${response.statusCode} - ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      print("Error fetching data from $url: $e");
      throw Exception("Error fetching data: $e");
    }
  }
}
