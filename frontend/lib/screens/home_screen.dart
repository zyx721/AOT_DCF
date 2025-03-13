import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Widget _buildStoriesSection() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final user = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple.shade100,
                      backgroundImage: 
                          user['photoURL'] != null ? NetworkImage(user['photoURL']) : null,
                      child: user['photoURL'] == null 
                          ? Text(
                              user['name']?[0]?.toUpperCase() ?? '?',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user['name'] ?? 'Unknown').toString().split(' ')[0],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStoriesSection(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No posts yet'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final post = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(post['userPhotoURL'] ?? ''),
                            child: post['userPhotoURL'] == null 
                                ? Text(post['userName']?[0] ?? '?') 
                                : null,
                          ),
                          title: Text(post['userName'] ?? 'Unknown'),
                          subtitle: Text(
                            _getTimeAgo(post['timestamp']?.toDate() ?? DateTime.now()),
                          ),
                        ),
                        if (post['mediaUrl'] != null) ...[
                          if (post['mediaType'] == 'image')
                            Image.network(
                              post['mediaUrl'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 300,
                            )
                          else if (post['mediaType'] == 'video')
                            Container(
                              height: 300,
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.play_circle_fill, 
                                  color: Colors.white, 
                                  size: 50,
                                ),
                              ),
                            ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(post['description'] ?? ''),
                        ),
                        ButtonBar(
                          children: [
                            IconButton(
                              icon: Icon(
                                post['isLiked'] == true 
                                    ? Icons.favorite 
                                    : Icons.favorite_border,
                                color: post['isLiked'] == true 
                                    ? Colors.red 
                                    : null,
                              ),
                              onPressed: () {
                                // Add like functionality
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.comment_outlined),
                              onPressed: () {
                                // Add comment functionality
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () {
                                // Add share functionality
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
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
}
