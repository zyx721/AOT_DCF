import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinPrivateForumScreen extends StatefulWidget {
  final String forumId;

  const JoinPrivateForumScreen({Key? key, required this.forumId}) : super(key: key);

  @override
  _JoinPrivateForumScreenState createState() => _JoinPrivateForumScreenState();
}

class _JoinPrivateForumScreenState extends State<JoinPrivateForumScreen> {
  bool _isLoading = false;
  String _forumTitle = '';
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadForumDetails();
  }

  Future<void> _loadForumDetails() async {
    final forumDoc = await FirebaseFirestore.instance
        .collection('forums')
        .doc(widget.forumId)
        .get();
    
    if (forumDoc.exists) {
      setState(() {
        _forumTitle = forumDoc.data()?['title'] ?? 'Private Forum';
      });
    }
  }

  Future<void> _submitJoinRequest() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('forums')
            .doc(widget.forumId)
            .collection('joinRequests')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'message': _messageController.text,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Private Forum'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _forumTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'This is a private forum. Please enter a message for the admin to review your join request:',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message to admin',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitJoinRequest,
                      child: const Text('Submit Join Request'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
