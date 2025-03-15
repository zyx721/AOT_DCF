import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../screens/Chat_screen/chat_detail_screen.dart';  // Add this import

class ActivityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<List<String>>(
      future: _getUserFundraisers(),
      builder: (context, fundraiserSnapshot) {
        if (fundraiserSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!fundraiserSnapshot.hasData || fundraiserSnapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No donation activity yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donations')
              .where('fundraiserId', whereIn: fundraiserSnapshot.data)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Something went wrong'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No donation activity yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final donation = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return FutureBuilder<DocumentSnapshot>(
                  future: _getFundraiserDetails(donation['fundraiserId']),
                  builder: (context, fundraiserSnapshot) {
                    if (!fundraiserSnapshot.hasData) {
                      return SizedBox.shrink();
                    }
                    
                    final fundraiserData = fundraiserSnapshot.data!.data() as Map<String, dynamic>;
                    
                    return FutureBuilder<DocumentSnapshot>(
                      future: donation['donatorId'] != 'anonymous' 
                          ? _getDonatorDetails(donation['donatorId'])
                          : null,
                      builder: (context, donatorSnapshot) {
                        final bool isAnonymous = donation['donatorId'] == 'anonymous';
                        final donatorData = !isAnonymous && donatorSnapshot.hasData 
                            ? donatorSnapshot.data!.data() as Map<String, dynamic>
                            : null;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    isAnonymous
                                        ? CircleAvatar(
                                            backgroundColor: Colors.green,
                                            child: Icon(
                                              Icons.person_outline,
                                              color: Colors.white,
                                            ),
                                          )
                                        : CircleAvatar(
                                            backgroundImage: donatorData != null
                                                ? NetworkImage(donatorData['photoURL'])
                                                : null,
                                            backgroundColor: Colors.green,
                                            child: donatorData?['photoURL'] == null
                                                ? Icon(Icons.person, color: Colors.white)
                                                : null,
                                          ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAnonymous
                                                ? 'Anonymous Donor'
                                                : donatorData?['name'] ?? 'Loading...',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Donated to: ${fundraiserData['title']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '\$${donation['amount'].toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          if (!isAnonymous && donatorData != null)
                                            ElevatedButton.icon(
                                              onPressed: () => _startChat(
                                                context,
                                                donation['donatorId'],
                                                donatorData['name'],
                                                donatorData['photoURL'] ?? '',
                                              ),
                                              icon: Icon(Icons.chat_bubble_outline, size: 18,color: Colors.white,),
                                              label: Text('Say Thanks'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(donation['timestamp']),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
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
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startChat(BuildContext context, String donatorId, String donatorName, String imageUrl) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check if chat already exists
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    String? existingChatId;
    for (var doc in chatQuery.docs) {
      List<String> participants = List<String>.from(doc['participants']);
      if (participants.contains(donatorId)) {
        existingChatId = doc.id;
        break;
      }
    }

    String chatId = existingChatId ?? '';
    
    if (existingChatId == null) {
      // Create new chat
      final chatRef = await FirebaseFirestore.instance
          .collection('chats')
          .add({
        'participants': [currentUser.uid, donatorId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });
      chatId = chatRef.id;
    }

    // Navigate to chat detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          chatId: chatId,
          otherUserId: donatorId,
          name: donatorName,
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  Future<List<String>> _getUserFundraisers() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) return [];
    
    final userData = userDoc.data() as Map<String, dynamic>;
    return List<String>.from(userData['fundraisers'] ?? []);
  }

  Future<DocumentSnapshot> _getFundraiserDetails(String fundraiserId) {
    return FirebaseFirestore.instance
        .collection('fundraisers')
        .doc(fundraiserId)
        .get();
  }

  Future<DocumentSnapshot> _getDonatorDetails(String donatorId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(donatorId)
        .get();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
