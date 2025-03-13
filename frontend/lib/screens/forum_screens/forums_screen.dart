import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forum_detail_screen.dart';
import 'join_private_forum_screen.dart';

class ForumsScreen extends StatefulWidget {
  const ForumsScreen({Key? key}) : super(key: key);

  @override
  _ForumsScreenState createState() => _ForumsScreenState();
}

class _ForumsScreenState extends State<ForumsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _joinForum(String forumId, bool isPrivate) async {
    if (isPrivate) {
      // Navigate to join private forum screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JoinPrivateForumScreen(forumId: forumId),
        ),
      );
    } else {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Check if already a member
          final memberDoc = await FirebaseFirestore.instance
              .collection('forums')
              .doc(forumId)
              .collection('members')
              .doc(user.uid)
              .get();

          if (memberDoc.exists) {
            // Already a member, just navigate to the forum
            _navigateToForumDetail(forumId);
            return;
          }

          // Add user as a member
          await FirebaseFirestore.instance
              .collection('forums')
              .doc(forumId)
              .collection('members')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });

          // Add forum to user's forums
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('forums')
              .doc(forumId)
              .set({
            'forumId': forumId,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });

          // Update member count
          await FirebaseFirestore.instance.collection('forums').doc(forumId).update({
            'memberCount': FieldValue.increment(1),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined the forum!'),
              backgroundColor: Colors.green,
            ),
          );

          _navigateToForumDetail(forumId);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining forum: $e'),
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

  void _navigateToForumDetail(String forumId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumDetailScreen(forumId: forumId),
      ),
    );
  }

  void _showJoinByCodeDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join by Forum Code'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Enter forum code',
              hintText: 'e.g. ABC123',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isNotEmpty) {
                  Navigator.pop(context);
                  // Search for forum with this code
                  try {
                    final forumQuery = await FirebaseFirestore.instance
                        .collection('forums')
                        .where('forumCode', isEqualTo: codeController.text.toUpperCase())
                        .limit(1)
                        .get();

                    if (forumQuery.docs.isNotEmpty) {
                      final forumDoc = forumQuery.docs.first;
                      final forumData = forumDoc.data();
                      
                      if (forumData['visibility'] == 'PRIVATE') {
                        // Navigate to join private forum screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JoinPrivateForumScreen(forumId: forumDoc.id),
                          ),
                        );
                      } else {
                        // It's a public forum with code, join directly
                        _joinForum(forumDoc.id, false);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No forum found with this code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search forums...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: _showJoinByCodeDialog,
                    tooltip: 'Join by code',
                  ),
                ],
              ),
            ),
            
            // Forums list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('forums')
                          .where('visibility', isEqualTo: 'ALL')
                          .orderBy('lastActivity', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No forums available'),
                          );
                        }

                        // Filter forums based on search query
                        final forums = snapshot.data!.docs.where((doc) {
                          final forumData = doc.data() as Map<String, dynamic>;
                          final title = forumData['title'] as String? ?? '';
                          final description = forumData['description'] as String? ?? '';
                          
                          if (_searchQuery.isEmpty) {
                            return true;
                          }
                          
                          return title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                              description.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();

                        if (forums.isEmpty) {
                          return const Center(
                            child: Text('No matching forums found'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: forums.length,
                          itemBuilder: (context, index) {
                            final forumDoc = forums[index];
                            final forumData = forumDoc.data() as Map<String, dynamic>;
                            final isAnonymous = forumData['isAnonymous'] as bool? ?? false;
                            final isPrivate = forumData['visibility'] == 'PRIVATE';
                            final memberCount = forumData['memberCount'] as int? ?? 0;
                            
                            // Get timestamp and convert to DateTime
                            final timestamp = forumData['lastActivity'] as Timestamp?;
                            final lastActivity = timestamp != null 
                                ? timestamp.toDate()
                                : DateTime.now();
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () {
                                  _navigateToForumDetail(forumDoc.id);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Forum header with icon
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isAnonymous 
                                            ? Colors.purple.shade50 
                                            : Colors.blue.shade50,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isAnonymous ? Icons.masks : Icons.public,
                                            color: isAnonymous ? Colors.purple : Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              forumData['title'] as String? ?? 'Untitled Forum',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isPrivate)
                                            const Icon(Icons.lock, size: 18, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                    
                                    // Forum description
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            forumData['description'] as String? ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$memberCount members',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getTimeAgo(lastActivity),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Join button
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _joinForum(forumDoc.id, isPrivate),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isAnonymous ? Colors.purple : Colors.blue,
                                              side: BorderSide(
                                                color: isAnonymous ? Colors.purple : Colors.blue,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                            ),
                                            child: Text(isPrivate ? 'Request to Join' : 'Join Forum'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}