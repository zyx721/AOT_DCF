import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/notification.dart';
import 'package:frontend/screens/association_screen.dart';
import 'package:frontend/screens/Chat_screen/chat_detail_screen.dart';
import 'package:frontend/screens/reels_screen/reels_screen.dart';
import '../view_profile_screen/view_profile_screen.dart';

class NotificationScreen extends StatelessWidget {
  // Define colors for different notification types
  final Map<String, Color> _typeColors = {
    'MESSAGE': Colors.blue.shade100,
    'LIKE': Colors.pink.shade100,
    'VIDEO_LIKE': Colors.purple.shade100,
    'PRAYER': Colors.amber.shade100,
    'PRAYER_LIKE': Colors.orange.shade100,
    'FOLLOW': Colors.green.shade100,
  };

  // Define icons for different notification types
  final Map<String, IconData> _typeIcons = {
    'MESSAGE': Icons.chat_bubble_outline,
    'LIKE': Icons.favorite_border,
    'VIDEO_LIKE': Icons.play_circle_outline,
    'PRAYER': Icons.volunteer_activism,
    'PRAYER_LIKE': Icons.favorite_border,
    'FOLLOW': Icons.person_add_alt_1_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications')),
        body: Center(child: Text('Please login to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.green,
        actions: [
          TextButton.icon(
        onPressed: () async {
          // Mark all as read
          final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();
          
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in notifications.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
            ),
          );
        },
        icon: Icon(Icons.done_all, color: Colors.white),
        label: Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PushNotificationService.getNotificationsStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState('Error loading notifications');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading notifications...'),
                ],
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          // Group notifications by date
          final Map<String, List<DocumentSnapshot>> groupedNotifications = {};
          
          for (var notification in notifications) {
            final data = notification.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            if (timestamp == null) continue;
            
            final date = _getDateKey(timestamp.toDate());
            if (!groupedNotifications.containsKey(date)) {
              groupedNotifications[date] = [];
            }
            groupedNotifications[date]!.add(notification);
          }

          // Sort dates by most recent first
          final sortedDates = groupedNotifications.keys.toList()
            ..sort((a, b) => _getDateFromKey(b).compareTo(_getDateFromKey(a)));

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final dateNotifications = groupedNotifications[date]!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  ...dateNotifications.map((notification) {
                    final data = notification.data() as Map<String, dynamic>;
                    return _buildNotificationItem(context, notification, data);
                  }).toList(),
                  Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When you receive notifications, they will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, 
    DocumentSnapshot notification, 
    Map<String, dynamic> data
  ) {
    final timestamp = data['timestamp'] as Timestamp?;
    final isRead = data['isRead'] as bool? ?? true;
    final type = data['type'] as String? ?? 'MESSAGE';
    
    // Get background color and icon based on notification type
    final bgColor = isRead ? Colors.transparent : _typeColors[type] ?? Colors.grey.shade100;
    final icon = _typeIcons[type] ?? Icons.notifications_none;
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(notification.id)
            .delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification removed'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        elevation: isRead ? 0 : 1,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isRead 
              ? BorderSide(color: Colors.grey.shade200, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Mark as read
            await FirebaseFirestore.instance
                .collection('notifications')
                .doc(notification.id)
                .update({'isRead': true});

            // Navigate based on notification type
            await _handleNotificationTap(context, data);
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: data['senderPhoto'] != null && data['senderPhoto'].toString().isNotEmpty
                          ? NetworkImage(data['senderPhoto'])
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: data['senderPhoto'] == null || data['senderPhoto'].toString().isEmpty
                          ? Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(type),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          icon,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(color: Colors.black87),
                                children: [
                                  TextSpan(
                                    text: data['senderName'] ?? 'User',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: ' '),
                                  TextSpan(text: _getNotificationAction(type)),
                                  if (data['additionalData']?['content'] != null)
                                    TextSpan(
                                      text: ' "${data['additionalData']['content']}"',
                                      style: TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (timestamp != null)
                            Text(
                              _formatTimestamp(timestamp.toDate()),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
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
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, h:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  DateTime _getDateFromKey(String key) {
    return DateFormat('yyyy-MM-dd').parse(key);
  }

  String _formatDateHeader(String dateKey) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'MESSAGE':
        return Colors.blue;
      case 'LIKE':
        return Colors.pink;
      case 'VIDEO_LIKE':
        return Colors.purple;
      case 'PRAYER':
        return Colors.amber;
      case 'PRAYER_LIKE':
        return Colors.orange;
      case 'FOLLOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getNotificationAction(String type) {
    switch (type) {
      case 'MESSAGE':
        return 'sent you a message';
      case 'LIKE':
        return 'liked your post';
      case 'VIDEO_LIKE':
        return 'liked your video';
      case 'PRAYER':
        return 'prayed for your fundraiser';
      case 'PRAYER_LIKE':
        return 'liked your prayer';
      case 'FOLLOW':
        return 'started following you';
      default:
        return 'sent you a notification';
    }
  }

  Future<void> _handleNotificationTap(BuildContext context, Map<String, dynamic> data) async {
    final type = data['type'];
    final targetId = data['targetId'];
    if (targetId == null) return;

    try {
      switch (type) {
        case 'MESSAGE':
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(targetId)
              .get();
          
          if (chatDoc.exists) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  chatId: targetId,
                  otherUserId: data['senderId'],
                  name: data['senderName'] ?? 'User',
                  imageUrl: data['senderPhoto'] ?? '',
                ),
              ),
            );
          }
          break;

        case 'LIKE':
        case 'PRAYER':
        case 'PRAYER_LIKE':
          final fundraiserDoc = await FirebaseFirestore.instance
              .collection('fundraisers')
              .doc(targetId)
              .get();
          
          if (fundraiserDoc.exists) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssociationScreen(
                  fundraiser: {
                    'id': targetId,
                    ...fundraiserDoc.data()!,
                  },
                ),
              ),
            );
          }
          break;

        case 'VIDEO_LIKE':
          final videoDoc = await FirebaseFirestore.instance
              .collection('videos')
              .doc(targetId)
              .get();
          
          if (videoDoc.exists) {
            final videosQuery = await FirebaseFirestore.instance
                .collection('videos')
                .orderBy('createdAt', descending: true)
                .get();
            
            final index = videosQuery.docs.indexWhere((doc) => doc.id == targetId);
            if (index != -1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReelsScreen(
                    initialIndex: index,
                    videos: videosQuery.docs,
                  ),
                ),
              );
            }
          }
          break;

        case 'FOLLOW':
          if (data['additionalData']?['fundraiserTitle'] != null) {
            // Follow from fundraiser - navigate to fundraiser
            final fundraiserDoc = await FirebaseFirestore.instance
                .collection('fundraisers')
                .doc(targetId)
                .get();
            
            if (fundraiserDoc.exists) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssociationScreen(
                    fundraiser: {
                      'id': targetId,
                      ...fundraiserDoc.data()!,
                    },
                  ),
                ),
              );
            }
          } else {
            // Regular follow - navigate to profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ViewProfileScreen(
                  userId: data['senderId'],
                ),
              ),
            );
          }
          break;
      }
    } catch (e) {
      print('Error handling notification tap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open notification content'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}