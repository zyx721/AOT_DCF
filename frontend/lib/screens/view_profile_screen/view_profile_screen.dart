import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../association_screen.dart';
import '../follow_list_screen.dart';

class ViewProfileScreen extends StatefulWidget {
  final String userId;

  const ViewProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _ViewProfileScreenState createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStatItem(String title, String count) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF57AB7D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChip(String label) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          color: const Color(0xFF57AB7D),
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: const Color(0xFF57AB7D).withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF57AB7D).withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = firestore.batch();
      final currentUserRef = firestore.collection('users').doc(currentUser.uid);
      final targetUserRef = firestore.collection('users').doc(widget.userId);

      final currentUserDoc = await currentUserRef.get();
      final following = List<String>.from(currentUserDoc.data()?['following'] ?? []);

      if (following.contains(widget.userId)) {
        batch.update(currentUserRef, {
          'following': FieldValue.arrayRemove([widget.userId])
        });
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        batch.update(currentUserRef, {
          'following': FieldValue.arrayUnion([widget.userId])
        });
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayUnion([currentUser.uid])
        });
      }

      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF57AB7D)));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final interests = List<String>.from(userData['interests'] ?? []);
          final aboutMe = userData['aboutMe'] as String? ?? "No description provided yet.";
          final followers = (userData['followers'] as List?)?.length ?? 0;
          final following = (userData['following'] as List?)?.length ?? 0;
          final fundraisersCount = (userData['fundraisers'] as List?)?.length ?? 0;
          final name = userData['name'] ?? 'User';
          final location = _getLocation(userData);
          final memberSince = userData['createdAt'] != null 
              ? DateFormat('MMMM yyyy').format((userData['createdAt'] as Timestamp).toDate())
              : 'Unknown';
          final photoURL = userData['photoURL'] ?? '';

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250.0, // Increased height
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF57AB7D),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Profile Image
                        Hero(
                          tag: 'profile-${widget.userId}',
                          child: CachedNetworkImage(
                            imageUrl: photoURL,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF57AB7D),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF57AB7D),
                              child: const Icon(Icons.person, size: 80, color: Colors.white54),
                            ),
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share, color: Colors.white, size: 20),
                      ),
                      onPressed: () {
                        // Share profile functionality
                      },
                    ),
                  ],
                ),
              ];
            },
            body: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (location.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: Color(0xFF57AB7D)),
                                      const SizedBox(width: 4),
                                      Text(
                                        location,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF57AB7D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Member since $memberSince',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<DocumentSnapshot>(
                            stream: firestore
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .snapshots(),
                            builder: (context, currentUserSnapshot) {
                              if (!currentUserSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              // Don't show follow button if viewing own profile
                              if (widget.userId == FirebaseAuth.instance.currentUser?.uid) {
                                return ElevatedButton(
                                  onPressed: () {
                                    // Navigate to edit profile
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: Text(
                                    'Edit Profile',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }

                              final currentUserData = currentUserSnapshot.data!.data() as Map<String, dynamic>;
                              final isFollowing = (currentUserData['following'] as List?)?.contains(widget.userId) ?? false;

                              return ElevatedButton(
                                onPressed: _isLoading ? null : _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.white : const Color(0xFF57AB7D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: isFollowing ? const BorderSide(color: Color(0xFF57AB7D)) : BorderSide.none,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  elevation: isFollowing ? 0 : 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF57AB7D)),
                                        ),
                                      )
                                    : Text(
                                        isFollowing ? 'Following' : 'Follow',
                                        style: GoogleFonts.poppins(
                                          color: isFollowing ? const Color(0xFF57AB7D) : Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem("Fundraisers", fundraisersCount.toString()),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowListScreen(
                                    userId: widget.userId,
                                    isFollowers: true,
                                  ),
                                ),
                              ),
                              child: _buildStatItem("Followers", followers.toString()),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FollowListScreen(
                                    userId: widget.userId,
                                    isFollowers: false,
                                  ),
                                ),
                              ),
                              child: _buildStatItem("Following", following.toString()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF57AB7D),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF57AB7D),
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: "About"),
                      Tab(text: "Fundraisers"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // About tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "About Me",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF57AB7D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                aboutMe,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (interests.isNotEmpty) ...[
                              Text(
                                "Interests",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF57AB7D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: interests.map((interest) => _buildInterestChip(interest)).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Fundraisers tab
                      StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('fundraisers')
                            .where('creatorId', isEqualTo: widget.userId)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final fundraisers = snapshot.data!.docs;
                          
                          if (fundraisers.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.volunteer_activism_outlined, 
                                    size: 64, 
                                    color: Colors.grey[400]
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No fundraisers yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: fundraisers.length,
                            itemBuilder: (context, index) {
                              final fundraiser = fundraisers[index].data() as Map<String, dynamic>;
                              fundraiser['id'] = fundraisers[index].id; // Add document ID
                              final goalAmount = (fundraiser['donationAmount'] ?? 0).toDouble();
                              final raisedAmount = (fundraiser['funding'] ?? 0).toDouble();
                              final progress = goalAmount > 0 ? (raisedAmount / goalAmount) : 0.0;
                              final daysLeft = fundraiser['expirationDate'] != null 
                                ? DateTime.now().difference((fundraiser['expirationDate'] as Timestamp).toDate()).inDays.abs()
                                : 0;

                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssociationScreen(fundraiser: fundraiser),
                                  ),
                                ),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Cover Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                        child: CachedNetworkImage(
                                          imageUrl: fundraiser['mainImageUrl'] ?? '',
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: Center(child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[200],
                                            child: Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Category and Status
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF57AB7D).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    fundraiser['category'] ?? 'No Category',
                                                    style: GoogleFonts.poppins(
                                                      color: Color(0xFF57AB7D),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(fundraiser['status']).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    fundraiser['status']?.toUpperCase() ?? 'PENDING',
                                                    style: GoogleFonts.poppins(
                                                      color: _getStatusColor(fundraiser['status']),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 12),
                                            // Title
                                            Text(
                                              fundraiser['title'] ?? 'Untitled Fundraiser',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 12),
                                            // Progress Bar
                                            LinearPercentIndicator(
                                              padding: EdgeInsets.zero,
                                              lineHeight: 8,
                                              percent: progress.clamp(0.0, 1.0),
                                              backgroundColor: Color(0xFF57AB7D).withOpacity(0.1),
                                              progressColor: Color(0xFF57AB7D),
                                              barRadius: Radius.circular(4),
                                            ),
                                            SizedBox(height: 12),
                                            // Amount and Days Left
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '\$${NumberFormat('#,##0').format(raisedAmount)}',
                                                      style: GoogleFonts.poppins(
                                                        color: Color(0xFF57AB7D),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      'of \$${NumberFormat('#,##0').format(goalAmount)}',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '$daysLeft days left',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
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
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLocation(Map<String, dynamic> userData) {
    final city = userData['city'] as String?;
    final country = userData['country'] as String?;
    
    if (city != null && country != null) {
      return '$city, $country';
    } else if (city != null) {
      return city;
    } else if (country != null) {
      return country;
    }
    return '';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}