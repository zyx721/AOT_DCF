import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';  // Add this import
import '../../widgets/modern_app_bar.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final currentUser = FirebaseAuth.instance.currentUser;

  Stream<List<String>> get _followedUsersStream {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser?.uid)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['following'] ?? []));
  }

  Stream<QuerySnapshot> get _chatsStream {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser?.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<void> _searchUsers(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => UserSearchDialog(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: ModernAppBar(title: 'Inbox', showLogo: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _searchUsers(context),
                    icon: Icon(Icons.search, color: Colors.white),
                    label: Text(
                      "Search users",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF57AB7D),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF57AB7D),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: () {
                      // Add filter functionality here
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _followedUsersStream,
              builder: (context, followedSnapshot) {
                if (followedSnapshot.hasError) {
                  return Center(child: Text('Error loading followed users'));
                }

                if (!followedSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final followedUsers = followedSnapshot.data!;

                if (followedUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_outlined, 
                             size: 48, 
                             color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Follow some users to start chatting',
                             style: TextStyle(color: Colors.grey[600])),
                        TextButton(
                          onPressed: () => _searchUsers(context),
                          child: Text('Find users to follow'),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _chatsStream,
                  builder: (context, chatSnapshot) {
                    if (chatSnapshot.hasError) {
                      return Center(child: Text('Something went wrong'));
                    }

                    if (chatSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, 
                                 size: 48, 
                                 color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No conversations yet',
                                 style: TextStyle(color: Colors.grey[600])),
                            TextButton(
                              onPressed: () => _searchUsers(context),
                              child: Text('Find people to chat with'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chatSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final chatDoc = chatSnapshot.data!.docs[index];
                        final chatData = chatDoc.data() as Map<String, dynamic>;
                        final otherUserId = (chatData['participants'] as List)
                            .firstWhere((id) => id != currentUser?.uid);

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(otherUserId)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return SizedBox.shrink();
                            }

                            final userData = userSnapshot.data!.data() 
                                as Map<String, dynamic>;
                            final isOnline = userData['isConnected'] ?? false;

                            return _buildChatTile(
                              chatDoc.id,
                              userData['name'] ?? 'Unknown',
                              chatData['lastMessage'] ?? '',
                              chatData['lastMessageTime'] as Timestamp,
                              chatData['unreadCount'] ?? 0,
                              isOnline,
                              userData['photoURL'] ?? '',
                              otherUserId,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(messageTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(messageTime);
    } else {
      return DateFormat('MMM d').format(messageTime);
    }
  }

  Widget _buildChatTile(String chatId, String name, String lastMessage, 
                       Timestamp time, int unreadCount, bool isOnline, 
                       String photoUrl, String otherUserId) {
    final timeFormatted = _formatTimestamp(time);
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              otherUserId: otherUserId,
              name: name,
              imageUrl: photoUrl,
              isOnline: isOnline,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(photoUrl),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timeFormatted,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserSearchDialog extends StatefulWidget {
  @override
  _UserSearchDialogState createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
  final _searchController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  
  // Define theme colors
  final Color primaryGreen = Colors.green.shade600;
  final Color lightGreen = Colors.green.shade50;
  final Color mediumGreen = Colors.green.shade100;
  
  Future<String> _createOrGetChat(String otherUserId, String currentUserId) async {
    // Sort IDs to ensure consistent chat ID
    final sortedIds = [currentUserId, otherUserId]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': sortedIds,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });
    }

    return chatId;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with more visual appeal
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_search, color: Colors.white, size: 28),
                  SizedBox(width: 16),
                  Text(
                    'Find People',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Search bar with enhanced styling
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: primaryGreen),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryGreen, width: 2),
                  ),
                  filled: true,
                  fillColor: lightGreen,
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            
            // Results section with improved layout
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('name', isGreaterThanOrEqualTo: _searchController.text)
                    .where('name', isLessThan: _searchController.text + 'z')
                    .where('uid', isNotEqualTo: currentUser?.uid)
                    .limit(20)  // Increased limit
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                    );
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser?.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      final data = userSnapshot.data?.data() as Map<String, dynamic>?;
                      final following = List<String>.from(data?['following'] ?? []);

                      return ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        shrinkWrap: true,
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 80,
                          endIndent: 16,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          final userData = snapshot.data!.docs[index].data() 
                              as Map<String, dynamic>;
                          final isFollowing = following.contains(userData['uid']);

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: index.isEven ? lightGreen : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Profile Picture
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: mediumGreen,
                                      backgroundImage: userData['photoURL'] != null && 
                                                    userData['photoURL'].isNotEmpty
                                          ? NetworkImage(userData['photoURL'])
                                          : null,
                                      child: userData['photoURL'] == null || 
                                            userData['photoURL'].isEmpty
                                          ? Icon(Icons.person, color: primaryGreen, size: 36)
                                          : null,
                                    ),
                                    SizedBox(width: 16),
                                    // Name and Email Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData['name'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            userData['email'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                // Actions Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () async {
                                final userRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser?.uid);
                                final otherUserRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userData['uid']);
                                
                                if (isFollowing) {
                                  // Remove from following and followers lists
                                  await userRef.update({
                                    'following': FieldValue.arrayRemove([userData['uid']])
                                  });
                                  await otherUserRef.update({
                                    'followers': FieldValue.arrayRemove([currentUser?.uid])
                                  });
                                } else {
                                  // Add to following and followers lists
                                  await userRef.update({
                                    'following': FieldValue.arrayUnion([userData['uid']])
                                  });
                                  await otherUserRef.update({
                                    'followers': FieldValue.arrayUnion([currentUser?.uid])
                                  });
                                }
                              },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing 
                                            ? Colors.grey.shade100
                                            : primaryGreen,
                                        foregroundColor: isFollowing 
                                            ? primaryGreen
                                            : Colors.white,
                                        elevation: isFollowing ? 0 : 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: isFollowing
                                              ? BorderSide(color: primaryGreen)
                                              : BorderSide.none,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(
                                        isFollowing ? 'Unfollow' : 'Follow',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isFollowing)
                                      Padding(
                                        padding: EdgeInsets.only(left: 12),
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.chat_bubble_outline,
                                            color: primaryGreen,
                                            size: 28,
                                          ),
                                          onPressed: () async {
                                            final chatId = await _createOrGetChat(
                                                userData['uid'], currentUser!.uid);
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatDetailScreen(
                                                  chatId: chatId,
                                                  otherUserId: userData['uid'],
                                                  name: userData['name'] ?? 'Unknown',
                                                  imageUrl: userData['photoURL'] ?? '',
                                                  isOnline: userData['isConnected'] ?? false,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
}

Future<String> _createOrGetChat(String user1Id, String user2Id) async {
  // Sort IDs to ensure consistent chat ID
  final sortedIds = [user1Id, user2Id]..sort();
  final chatId = '${sortedIds[0]}_${sortedIds[1]}';

  final chatDoc = await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .get();

  if (!chatDoc.exists) {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': sortedIds,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': 0,
    });
  }

  return chatId;
}
