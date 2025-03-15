import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/Chatbot_screen/chatbot.dart';
import 'package:frontend/screens/donation_screen/donation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/pdf_viewer_screen.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/view_profile_screen/view_profile_screen.dart';
import 'package:frontend/services/notification.dart';

class AssociationScreen extends StatefulWidget {
  final Map<String, dynamic> fundraiser;

  AssociationScreen({required this.fundraiser});

  @override
  _AssociationScreenState createState() => _AssociationScreenState();
}

class _AssociationScreenState extends State<AssociationScreen> {
  bool _isLoadingProposalPdf = false;
  bool _isLoadingAdditionalPdf = false;
  bool _isFollowing = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        List<String> following = List<String>.from(userDoc.data()?['following'] ?? []);
        setState(() {
          _isFollowing = following.contains(widget.fundraiser['creatorId']);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to follow creators')),
      );
      return;
    }

    if (currentUser.uid == widget.fundraiser['creatorId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot follow yourself')),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid);
    
    final creatorRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.fundraiser['creatorId']);

    try {
      if (!_isFollowing) {
        // Create notification when following
        await PushNotificationService.createNotification(
          receiverId: widget.fundraiser['creatorId'],
          senderId: currentUser.uid,
          type: 'FOLLOW',
          content: '${currentUser.displayName ?? 'Someone'} started following you in fundraiser',
          targetId: widget.fundraiser['id'],
          additionalData: {
            'fundraiserTitle': widget.fundraiser['title'],
          },
        );
      }

      if (_isFollowing) {
        // Unfollow - remove from both following and followers lists
        await userRef.update({
          'following': FieldValue.arrayRemove([widget.fundraiser['creatorId']])
        });
        await creatorRef.update({
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        // Follow - add to both following and followers lists
        await userRef.update({
          'following': FieldValue.arrayUnion([widget.fundraiser['creatorId']])
        });
        await creatorRef.update({
          'followers': FieldValue.arrayUnion([currentUser.uid])
        });
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowing ? 'Following' : 'Unfollowed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating follow status: $e')),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _updateLoadingState(bool isProposal, bool isLoading) {
    setState(() {
      if (isProposal) {
        _isLoadingProposalPdf = isLoading;
      } else {
        _isLoadingAdditionalPdf = isLoading;
      }
    });
  }

  Future<File> _downloadPdf(String url, String filename) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Connection': 'keep-alive'},
    ).timeout(
      Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Connection timed out'),
    );
    
    if (response.statusCode != 200) {
      throw HttpException('Failed to load PDF (Status: ${response.statusCode})');
    }
    
    final bytes = response.bodyBytes;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    return await file.writeAsBytes(bytes);
  }

  Future<void> _openPdfFile(String? url, String title, bool isProposal) async {
    if (url == null || url.isEmpty) {
      _showErrorMessage('No document available');
      return;
    }

    _updateLoadingState(isProposal, true);

    try {
      final filename = '${title.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await _downloadPdf(url, filename);
      
      _updateLoadingState(isProposal, false);
      
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            filePath: file.path,
            title: title,
          ),
        ),
      );
    } catch (e) {
      _updateLoadingState(isProposal, false);
      _showErrorMessage('Error loading PDF: ${e.toString()}');
      print('PDF loading error: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchCreatorInfo() async {
    try {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fundraiser['creatorId'])
          .get();
      return creatorDoc.data();
    } catch (e) {
      print('Error fetching creator info: $e');
      return null;
    }
  }

  int _calculateDaysLeft(Timestamp expirationDate) {
    final now = DateTime.now();
    final expDate = expirationDate.toDate();
    final difference = expDate.difference(now);
    return difference.inDays < 0 ? 0 : difference.inDays;
  }

  List<String> _getAllImages() {
    List<String> images = [];
    if (widget.fundraiser['mainImageUrl'] != null) {
      images.add(widget.fundraiser['mainImageUrl']);
    }
    if (widget.fundraiser['secondaryImageUrls'] != null) {
      images.addAll(List<String>.from(widget.fundraiser['secondaryImageUrls'])
          .where((url) => url != null && url.isNotEmpty));
    }
    return images.isEmpty ? ['assets/placeholder.jpg'] : images;
  }

  Widget _buildImageSlider() {
    final images = _getAllImages();
    
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 250,
            viewportFraction: 1.0,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items: images.map((url) {
            return CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: Center(child: CircularProgressIndicator(color: Colors.green,)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: Icon(Icons.error),
              ),
            );
          }).toList(),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(
                      _currentImageIndex == entry.key ? 0.9 : 0.4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.fundraiser['funding'] / widget.fundraiser['donationAmount'];
    int daysLeft = _calculateDaysLeft(widget.fundraiser['expirationDate']);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSlider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fundraiser['title'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '\$${widget.fundraiser['funding'].toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      Text(
                        ' fund raised from \$${widget.fundraiser['donationAmount'].toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${widget.fundraiser['donators']} Donators',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          )),
                      Text('$daysLeft days left',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          )),
                    ],
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DonationScreen(
                              fundraiserId: widget.fundraiser['id'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      ),
                      child: const Text(
                        'Donate Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Divider(height: 1),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchCreatorInfo(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: Colors.green,));
                      }
                      
                      if (!snapshot.hasData || snapshot.data == null) {
                        return SizedBox();
                      }

                      final creator = snapshot.data!;
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            creator['photoURL'] ?? 'assets/images/profile.jpg',
                          ),
                        ),
                        title: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewProfileScreen(
                                  userId: widget.fundraiser['creatorId'],
                                ),
                              ),
                            );
                          },
                          child: Text(
                            creator['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          '${creator['city']}, ${creator['country']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _toggleFollow,
                          child: Text(_isFollowing ? 'Following' : 'Follow'),
                          style: OutlinedButton.styleFrom(
                          foregroundColor: _isFollowing ? Colors.white : Colors.green,
                          backgroundColor: _isFollowing ? Colors.green : null,
                          side: BorderSide(color: Colors.green),
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(height: 32),
                  _buildPatientSection(),
                  _buildFundUsageSection(),
                  _buildStorySection(),
                  _buildPrayersSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recipient Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.person, color: Colors.blue),
          ),
          title: Text(widget.fundraiser['recipientName'] ?? 'Patient Name',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Identity verified according to documents'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.red[100],
            child: Icon(Icons.description, color: Colors.red),
          ),
          title: Text('Additional Documents',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('View additional documents'),
          trailing: _isLoadingAdditionalPdf
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,color: Colors.green,),
                )
              : null,
          onTap: () => _openPdfFile(
            widget.fundraiser['additionalDocUrl'],
            'Additional Documents',
            false,
          ),
        ),
        Divider(height: 32),
      ],
    );
  }

  Widget _buildFundUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Text('Fund Usage Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _isLoadingProposalPdf
          ? CircularProgressIndicator(color: Colors.green,)
          : OutlinedButton.icon(
            onPressed: () => _openPdfFile(
              widget.fundraiser['proposalDocUrl'],
              'Fund Usage Plan',
              true,
            ),
            icon: Icon(Icons.visibility, size: 18, color: Colors.white),
            label: Text('View Plan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.green,
              side: BorderSide(color: Colors.green),
            ),
            ),
        ],
      ),
      if (widget.fundraiser['fundUsage'] != null)
        Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          widget.fundraiser['fundUsage'],
          style: TextStyle(fontSize: 14),
        ),
        ),
      Divider(height: 32),
      ],
    );
  }

  Widget _buildStorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Story',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text(
          widget.fundraiser['story'] ?? 'No story available...',
          style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        TextButton(
          onPressed: () {},
          child: Text('Read more...'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
            padding: EdgeInsets.zero,
          ),
        ),
        Divider(height: 32),
      ],
    );
  }

Widget _buildPrayersSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prayers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showAddPrayerDialog(),
              icon: Icon(Icons.add, color: Colors.green),
              label: Text('Add Prayer'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fundraisers')
            .doc(widget.fundraiser['id'])
            .collection('prayers')
            .orderBy('timestamp', descending: true)
            .limit(8) // Increased limit for more cards
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Something went wrong');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.volunteer_activism, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No prayers yet. Be the first to share.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return SizedBox(
            height: 230, // Slightly increased height for date/time
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final prayer = snapshot.data!.docs[index];
                final timestamp = prayer['timestamp'] as Timestamp?;
                final DateTime dateTime = timestamp?.toDate() ?? DateTime.now();
                
                return _buildPrayerCard(
                  prayer.id,
                  prayer['userName'] ?? 'Anonymous',
                  prayer['message'],
                  prayer['likes'] ?? 0,
                  (prayer['likedBy'] ?? []).contains(FirebaseAuth.instance.currentUser?.uid),
                  prayer['photoURL'] ?? 'assets/images/profile.jpg',
                  dateTime,
                );
              },
            ),
          );
        },
      ),
    ],
  );
}

void _showAddPrayerDialog() {
  final TextEditingController messageController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add Prayer'),
      content: TextField(
        controller: messageController,
        decoration: InputDecoration(
          hintText: 'Enter your prayer message',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (messageController.text.isNotEmpty) {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await FirebaseFirestore.instance
                      .collection('fundraisers')
                      .doc(widget.fundraiser['id'])
                      .collection('prayers')
                      .add({
                    'userId': user.uid,
                    'userName': user.displayName ?? 'Anonymous',
                    'photoURL': user.photoURL,
                    'message': messageController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                    'likes': 0,
                    'likedBy': [],
                  });

                  // Send notification for new prayer
                  if (widget.fundraiser['creatorId'] != user.uid) {
                    await PushNotificationService.createNotification(
                      receiverId: widget.fundraiser['creatorId'],
                      senderId: user.uid,
                      type: 'PRAYER',
                      content: '${user.displayName ?? 'Someone'} prayed for your fundraiser',
                      targetId: widget.fundraiser['id'],
                      additionalData: {
                        'fundraiserTitle': widget.fundraiser['title'],
                        'prayer': messageController.text,
                      },
                    );
                  }

                  Navigator.pop(context);
                } catch (e) {
                  print('Error adding prayer: $e');
                }
              }
            }
          },
          child: Text('Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

Future<void> _toggleLike(String prayerId, bool isLiked) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final prayerRef = FirebaseFirestore.instance
      .collection('fundraisers')
      .doc(widget.fundraiser['id'])
      .collection('prayers')
      .doc(prayerId);

  try {
    final prayerDoc = await prayerRef.get();
    final prayerData = prayerDoc.data();
    
    if (!isLiked && prayerData != null && prayerData['userId'] != user.uid) {
      // Send notification when liking a prayer (not for own prayers)
      await PushNotificationService.createNotification(
        receiverId: prayerData['userId'],
        senderId: user.uid,
        type: 'PRAYER_LIKE',
        content: '${user.displayName ?? 'Someone'} liked your prayer',
        targetId: widget.fundraiser['id'],
        additionalData: {
          'fundraiserTitle': widget.fundraiser['title'],
          'prayer': prayerData['message'],
        },
      );
    }

    if (isLiked) {
      await prayerRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      await prayerRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([user.uid]),
      });
    }
  } catch (e) {
    print('Error toggling prayer like: $e');
  }
}

// Format date helper function
String _formatDate(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inDays == 0) {
    // Today - show time only
    return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
  } else if (difference.inDays == 1) {
    // Yesterday
    return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
  } else if (difference.inDays < 7) {
    // This week
    return DateFormat('EEEE').format(dateTime); // Day name
  } else {
    // Older than a week
    return DateFormat('MMM d').format(dateTime); // e.g. Mar 14
  }
}

Widget _buildPrayerCard(String prayerId, String name, String message, int likes, bool isLiked, String photoURL, DateTime timestamp) {
  return Container(
    width: 280, // Fixed width for cards
    margin: EdgeInsets.only(right: 12),
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(photoURL),
                  radius: 18,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatDate(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(color: Colors.black87, height: 1.4),
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => _toggleLike(prayerId, isLiked),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  }
