import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

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

  static Future<void> createNotification({
    required String receiverId,
    required String senderId,
    required String type,
    required String content,
    String? targetId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get sender info
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      
      final senderName = senderDoc.data()?['name'] ?? 'Someone';
      final senderPhoto = senderDoc.data()?['photoURL'];

      // Create notification document
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'receiverId': receiverId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'type': type,
        'content': content,
        'targetId': targetId,
        'additionalData': additionalData,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Get receiver's device token
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      final deviceToken = receiverDoc.data()?['deviceToken'];

      if (deviceToken != null) {
        // Send push notification
        await sendNotification(
          deviceToken,
          'New ${type.toLowerCase()}',
          content,
          {
            'type': type,
            'targetId': targetId ?? '',
            'senderId': senderId,
            ...?additionalData,
          },
        );
      }
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  static Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
