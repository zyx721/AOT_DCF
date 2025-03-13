import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;


class PushNotificationService {
  static Future<String> getAccessToken() async {
    // Load the service account JSON
    final serviceAccountJson =
        await rootBundle.loadString('assets/credentials/notification.json');

    // Define the required scopes
    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging"
    ];

    // Create a client using the service account credentials
    final auth.ServiceAccountCredentials credentials =
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson);

    final auth.AuthClient client =
        await auth.clientViaServiceAccount(credentials, scopes);

    // Retrieve the access token
    final String accessToken = client.credentials.accessToken.data;

    // Close the client to avoid resource leaks
    client.close();

    return accessToken;
  }

  static Future<void> sendNotification(String deviceToken, String title,
      String body, Map<String, dynamic> data) async {
    final String serverKey = await getAccessToken();
    String endpointFirebaseCloudMessaging =
        'https://fcm.googleapis.com/v1/projects/dcf-aot/messages:send';

    final Map<String, dynamic> message = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data,
      }
    };

    final http.Response response = await http.post(
      Uri.parse(endpointFirebaseCloudMessaging),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverKey',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification');
      print('Response: ${response.body}');
    }
  }
}
