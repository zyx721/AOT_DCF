import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/Chatbot_screen/chatbot.dart';
import 'package:frontend/screens/reels_screen/reels_screen.dart';
import '../../widgets/modern_app_bar.dart'; // Add this import
import '../association_screen.dart'; // Add this import
import 'search_screen.dart';
import 'package:frontend/screens/payment_screen/top_up_screen.dart'; // Ad

class HomeScreen extends StatefulWidget {
  @override
  _FundraisingHomePageState createState() => _FundraisingHomePageState();
}

class VideoCard extends StatelessWidget {
  final String image;
  final String title;
  final VoidCallback onTap;

  const VideoCard({
    required this.image,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200, // Increased width
        margin: EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image.startsWith('assets/')
                        ? Image.asset(
                            image,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.error),
                            ),
                          ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Watch Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundraisingHomePageState extends State<HomeScreen> {
  String _selectedFilter = 'All';
  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> toggleFavorite(String fundraiserId) async {
    if (currentUser == null) return;

    final userFavoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('favorites')
        .doc(fundraiserId);

    final doc = await userFavoriteRef.get();
    if (doc.exists) {
      await userFavoriteRef.delete();
    } else {
      await userFavoriteRef.set({
        'fundraiserId': fundraiserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<bool> isFavorite(String fundraiserId) {
    if (currentUser == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('favorites')
        .doc(fundraiserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<QuerySnapshot> getFundraisersStream() {
    if (_selectedFilter == 'All') {
      return FirebaseFirestore.instance
          .collection('fundraisers')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('fundraisers')
          .where('category', isEqualTo: _selectedFilter)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Stream<QuerySnapshot> getVideoReels() {
    return FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Stream<QuerySnapshot> getMoreFundraisersStream(
      DocumentSnapshot lastDocument) {
    return FirebaseFirestore.instance
        .collection('fundraisers')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(10)
        .snapshots();
  }

  Stream<QuerySnapshot> getPaginatedFundraisers() {
    return FirebaseFirestore.instance
        .collection('fundraisers')
        .orderBy('createdAt', descending: true)
        .limit(5) // Get only first 5 for urgent
        .snapshots();
  }

  Stream<QuerySnapshot> getMoreFundraisers() {
    return FirebaseFirestore.instance
        .collection('fundraisers')
        .orderBy('donators',
            descending: true) // Order by number of donors first
        .orderBy('funding', descending: true) // Then by amount raised
        .limit(10)
        .snapshots();
  }

  void setFilter(String? filter) {
    setState(() {
      _selectedFilter = filter ?? 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Home',
        showLogo: true,
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchPage()),
              );
            },
          ),
          SizedBox(width: 15),
          Icon(Icons.notifications, size: 28),
          SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12), // Reduced spacing
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.0), // Reduced padding
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$0',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text('My wallet balance')
                      ],
                    ),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopUpScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text('Top up',
                            style: TextStyle(color: Colors.white)))
                  ],
                ),
              ),
            ),
            SizedBox(height: 16), // Reduced spacing
            _buildImageSlider(),
            SizedBox(height: 16), // Reduced spacing
            StreamBuilder<QuerySnapshot>(
                stream: getPaginatedFundraisers(),
                builder: (context, snapshot) {
                  return _buildFundraisingSection('Urgent Fundraising', [
                    'All',
                    'Medical',
                    'Disaster',
                    'Education',
                    'Environment',
                    'Social',
                    'Sick child',
                    'Infrastructure',
                    'Art',
                    'Orphanage',
                    'Difable',
                    'Humanity',
                    'Others'
                  ]);
                }),
            SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
                stream: getMoreFundraisers(),
                builder: (context, snapshot) {
                  return _buildFundraisingSection('More to Help', [
                    'All',
                    'Medical',
                    'Education',
                    'Environment',
                    'Social',
                    'Others'
                  ]);
                }),
            SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Watch the Impact of Your Donation",
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to search page with videos tab
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchPage(initialTabIndex: 1),
                        ),
                      );
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: getVideoReels(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final videos = snapshot.data?.docs ?? [];

                if (videos.isEmpty) {
                  return Center(child: Text('No videos available'));
                }

                return SizedBox(
                  height: 320,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final videoData =
                          videos[index].data() as Map<String, dynamic>;
                      return VideoCard(
                        image: videoData['mainImageUrl'] ??
                            'assets/images/placeholder.jpg',
                        title: videoData['title'] ?? 'Untitled',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReelsScreen(
                              initialIndex: index,
                              videos: videos,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fundraisers')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var fundraisers = snapshot.data!.docs;

        return CarouselSlider(
          options: CarouselOptions(
            height: 200.0,
            enlargeCenterPage: true,
            autoPlay: true,
            aspectRatio: 16 / 9,
            autoPlayInterval: Duration(seconds: 4),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            viewportFraction: 0.92, // Add this to reduce space between edges
          ),
          items: fundraisers.map((fundraiser) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        fundraiser['mainImageUrl'] ?? 'assets/placeholder.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                  Container(
                    alignment: Alignment.bottomLeft,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      fundraiser['title'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFundraisingSection(String title, List<String> filters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  )),
              TextButton.icon(
                onPressed: () {
                  // Navigate to search page with fundraisers tab
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchPage(initialTabIndex: 0),
                    ),
                  );
                },
                icon: Icon(Icons.arrow_forward, size: 16, color: Colors.green),
                label: Text('See all',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    )),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            ],
          ),
        ),

        // Improved filter chips with more modern styling
        if (filters.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: filters
                    .map((filter) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _selectedFilter == filter
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: _selectedFilter == filter,
                            onSelected: (bool selected) {
                              setFilter(selected ? filter : 'All');
                            },
                            backgroundColor: Colors.grey[200],
                            selectedColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            pressElevation: 2,
                            shadowColor: Colors.black26,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

        // Improved StreamBuilder with better error handling and loading state
        StreamBuilder<QuerySnapshot>(
          stream: getFundraisersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Something went wrong',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No fundraisers available'),
                ),
              );
            }

            var fundraisers = snapshot.data!.docs;

            // Improved card list with better styling and animations
            return Container(
              height: 265, // Reduced from 320 to 280
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: fundraisers.length,
                itemBuilder: (context, index) {
                  var fundraiser = fundraisers[index];
                  double progress =
                      fundraiser['funding'] / fundraiser['donationAmount'];
                  DateTime expirationDate =
                      (fundraiser['expirationDate'] as Timestamp).toDate();
                  int daysLeft =
                      expirationDate.difference(DateTime.now()).inDays;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                    child: Container(
                      width: 260, // Reduced from 280 to 260
                      constraints: BoxConstraints(
                        minHeight: 260, // Reduced from 300
                        maxHeight: 280, // Reduced from 320
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        // Changed from ClipRRect to Stack
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              children: [
                                // Main card content
                                Expanded(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AssociationScreen(
                                              fundraiser: {
                                                'id': fundraiser.id,
                                                ...fundraiser.data()
                                                    as Map<String, dynamic>,
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      splashColor:
                                          Colors.green.withOpacity(0.1),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            children: [
                                              // Improved image display with shimmer loading
                                              Container(
                                                height: 140,
                                                width: double.infinity,
                                                child: CachedNetworkImage(
                                                  imageUrl: fundraiser[
                                                          'mainImageUrl'] ??
                                                      'assets/placeholder.jpg',
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Container(
                                                    color: Colors.grey[300],
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors.green),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Container(
                                                    color: Colors.grey[300],
                                                    child: Icon(Icons.error,
                                                        color: Colors.red),
                                                  ),
                                                ),
                                              ),

                                              // Better overlay indicators
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Row(
                                                  children: [
                                                    // Days left indicator
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.7),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons.access_time,
                                                              color:
                                                                  Colors.white,
                                                              size: 12),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            '$daysLeft days left',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),

                                                    // Improved favorite button
                                                    StreamBuilder<bool>(
                                                      stream: isFavorite(
                                                          fundraiser.id),
                                                      builder:
                                                          (context, snapshot) {
                                                        final isFavorited =
                                                            snapshot.data ??
                                                                false;
                                                        return Material(
                                                          color: Colors.black
                                                              .withOpacity(0.7),
                                                          shape: CircleBorder(),
                                                          child: InkWell(
                                                            onTap: () =>
                                                                toggleFavorite(
                                                                    fundraiser
                                                                        .id),
                                                            customBorder:
                                                                CircleBorder(),
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(6),
                                                              child:
                                                                  AnimatedSwitcher(
                                                                duration: Duration(
                                                                    milliseconds:
                                                                        300),
                                                                transitionBuilder:
                                                                    (child,
                                                                        animation) {
                                                                  return ScaleTransition(
                                                                      scale:
                                                                          animation,
                                                                      child:
                                                                          child);
                                                                },
                                                                child: Icon(
                                                                  isFavorited
                                                                      ? Icons
                                                                          .favorite
                                                                      : Icons
                                                                          .favorite_border,
                                                                  color: isFavorited
                                                                      ? Colors
                                                                          .red
                                                                      : Colors
                                                                          .white,
                                                                  size: 18,
                                                                  key: ValueKey<
                                                                          bool>(
                                                                      isFavorited),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Category tag (assuming 'category' field exists)
                                              if (fundraiser['category'] !=
                                                  null)
                                                Positioned(
                                                  left: 8,
                                                  top: 8,
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(
                                                              0.7), // Changed from green to black with opacity
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: Text(
                                                      fundraiser['category'],
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),

                                          // Improved content section
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical:
                                                    4.0, // Reduced from 8.0
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fundraiser['title'],
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          4), // Reduced from 6

                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    child:
                                                        LinearProgressIndicator(
                                                      value: progress,
                                                      backgroundColor:
                                                          Colors.grey[200],
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        progress >= 1.0
                                                            ? Colors.blue
                                                            : Colors.green,
                                                      ),
                                                      minHeight:
                                                          4, // Reduced from 6
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height:
                                                          4), // Reduced from 6

                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            '\$${fundraiser['funding'].toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.green,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          Text(
                                                            ' of \$${fundraiser['donationAmount'].toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.people,
                                                            size: 13,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            '${fundraiser['donators']} donors',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Gradient button at the bottom with no margin
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF66BB6A), // Light green
                                        Color(0xFF4CAF50), // Medium green
                                        Color(0xFF388E3C), // Dark green
                                        Color(0xFF2E7D32), // Darker green
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          'Become a Part',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
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
              ),
            );
          },
        ),
      ],
    );
  }
}
