import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> users = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        users = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _sendNotification(String deviceToken, String userId) async {
    if (_isSending) return;

    setState(() => _isSending = true);
    try {
      await PushNotificationService.sendNotification(
        deviceToken,
        'New Document Notification',
        'A new document has been uploaded',
        {
          'userId': userId,
          'type': 'document_upload',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending notification: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final deviceToken = user['deviceToken'];
          
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['photoURL'] ?? ''),
              child: user['photoURL'] == null ? Text(user['name']?[0] ?? '?') : null,
            ),
            title: Text(user['name'] ?? 'Unknown'),
            subtitle: Text(user['email'] ?? ''),
            trailing: IconButton(
              icon: _isSending 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.notifications_active),
              onPressed: deviceToken == null
                ? null
                : () => _sendNotification(deviceToken, user['id']),
            ),
          );
        },
      ),
    );
  }
}
