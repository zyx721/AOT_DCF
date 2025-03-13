import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class CreateForumScreen extends StatefulWidget {
  final bool isAnonymous;
  
  const CreateForumScreen({
    Key? key,
    required this.isAnonymous,
  }) : super(key: key);

  @override
  _CreateForumScreenState createState() => _CreateForumScreenState();
}

class _CreateForumScreenState extends State<CreateForumScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _visibility = 'ALL';
  bool _isLoading = false;
  final _uuid = const Uuid();
  String _forumCode = '';

  @override
  void initState() {
    super.initState();
    _forumCode = _generateForumCode();
  }

  String _generateForumCode() {
    return _uuid.v4().substring(0, 6).toUpperCase();
  }

  Future<void> _createForum() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final forumId = _uuid.v4();
          
          // Create forum document
          await FirebaseFirestore.instance.collection('forums').doc(forumId).set({
            'id': forumId,
            'title': _titleController.text,
            'description': _descriptionController.text,
            'isAnonymous': widget.isAnonymous,
            'visibility': _visibility,
            'forumCode': _forumCode,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'memberCount': 1,
            'lastActivity': FieldValue.serverTimestamp(),
          });
          
          // Add creator as a member
          await FirebaseFirestore.instance
              .collection('forums')
              .doc(forumId)
              .collection('members')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'role': 'admin',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          // Add forum to user's forum list
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('forums')
              .doc(forumId)
              .set({
            'forumId': forumId,
            'role': 'admin',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Forum created successfully! Forum code: $_forumCode'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to forums list
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating forum: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAnonymous ? 'Create Anonymous Forum' : 'Create Public Forum',
        ),
        backgroundColor: widget.isAnonymous ? Colors.purple : Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isAnonymous)
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.privacy_tip, color: Colors.purple),
                            SizedBox(height: 10),
                            Text(
                              'Anonymous Forum',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Personal details will be hidden to protect the dignity of those in need.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Forum Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    const Text(
                      'Forum Visibility:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    RadioListTile<String>(
                      title: const Text('Public (Visible to everyone)'),
                      subtitle: const Text('Anyone can find and join this forum'),
                      value: 'ALL',
                      groupValue: _visibility,
                      onChanged: (value) {
                        setState(() {
                          _visibility = value!;
                        });
                      },
                    ),
                    
                    RadioListTile<String>(
                      title: const Text('Private (Invitation only)'),
                      subtitle: const Text('Only people with the forum code can join'),
                      value: 'PRIVATE',
                      groupValue: _visibility,
                      onChanged: (value) {
                        setState(() {
                          _visibility = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Forum Code:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                _forumCode,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    _forumCode = _generateForumCode();
                                  });
                                },
                                tooltip: 'Generate new code',
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _visibility == 'PRIVATE'
                                ? 'Share this code with people you want to invite'
                                : 'Anyone can join, but they can also use this code',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _createForum,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isAnonymous ? Colors.purple : Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Create Forum',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}