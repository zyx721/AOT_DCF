import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this import

class FundraisingHomePage extends StatefulWidget {
  @override
  _FundraisingHomePageState createState() => _FundraisingHomePageState();
}

class _FundraisingHomePageState extends State<FundraisingHomePage> {
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

  void setFilter(String? filter) {
    setState(() {
      _selectedFilter = filter ?? 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        // Remove the default padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_people, color: Colors.green, size: 30),
                      SizedBox(width: 10),
                      Text('Wecare',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.search, size: 28),
                      SizedBox(width: 15),
                      Icon(Icons.notifications, size: 28),
                    ],
                  )
                ],
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
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
                          '\$349',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text('My wallet balance')
                      ],
                    ),
                    ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: Text('Top up'))
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildImageSlider(),
            SizedBox(height: 20),
            _buildFundraisingSection('Urgent Fundraising', ['All', 'Medical', 'Disaster', 'Education','Poverty']), // Removed Padding
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
                    imageUrl: fundraiser['mainImageUrl'] ?? 'assets/placeholder.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
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
      // Improved header with better spacing and typography
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title, 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              )
            ),
            TextButton.icon(
              onPressed: () {
                // Navigate to see all page
              },
              icon: Icon(Icons.arrow_forward, size: 16, color: Colors.green),
              label: Text(
                'See all', 
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                )
              ),
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
              children: filters.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedFilter == filter ? FontWeight.w600 : FontWeight.normal,
                      color: _selectedFilter == filter ? Colors.white : Colors.black87,
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
              )).toList(),
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
            height: 260, // Increased from 220 to accommodate content
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: fundraisers.length,
              itemBuilder: (context, index) {
                var fundraiser = fundraisers[index];
                double progress = fundraiser['funding'] / fundraiser['donationAmount'];
                DateTime expirationDate = (fundraiser['expirationDate'] as Timestamp).toDate();
                int daysLeft = expirationDate.difference(DateTime.now()).inDays;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                  child: Container(
                    width: 280, // Slightly wider for better proportions
                    // Add constraints to prevent overflow
                    constraints: BoxConstraints(
                      minHeight: 240,
                      maxHeight: 260,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Navigate to fundraiser detail page
                          },
                          splashColor: Colors.green.withOpacity(0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  // Improved image display with shimmer loading
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    child: CachedNetworkImage(
                                      imageUrl: fundraiser['mainImageUrl'] ?? 'assets/placeholder.jpg',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[300],
                                        child: Icon(Icons.error, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                  
                                  // Better overlay indicators
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        // Improved days left indicator
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.access_time, color: Colors.white, size: 12),
                                              SizedBox(width: 4),
                                              Text(
                                                '$daysLeft days left',
                                                style: TextStyle(
                                                  color: Colors.white, 
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        
                                        // Improved favorite button
                                        StreamBuilder<bool>(
                                          stream: isFavorite(fundraiser.id),
                                          builder: (context, snapshot) {
                                            final isFavorited = snapshot.data ?? false;
                                            return Material(
                                              color: Colors.black.withOpacity(0.7),
                                              shape: CircleBorder(),
                                              child: InkWell(
                                                onTap: () => toggleFavorite(fundraiser.id),
                                                customBorder: CircleBorder(),
                                                child: Padding(
                                                  padding: EdgeInsets.all(6),
                                                  child: AnimatedSwitcher(
                                                    duration: Duration(milliseconds: 300),
                                                    transitionBuilder: (child, animation) {
                                                      return ScaleTransition(scale: animation, child: child);
                                                    },
                                                    child: Icon(
                                                      isFavorited ? Icons.favorite : Icons.favorite_border,
                                                      color: isFavorited ? Colors.red : Colors.white,
                                                      size: 18,
                                                      key: ValueKey<bool>(isFavorited),
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
                                  if (fundraiser['category'] != null)
                                    Positioned(
                                      left: 8,
                                      top: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          fundraiser['category'],
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              
                              // Improved content section
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min, // Add this
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title with ellipsis for long text
                                      Text(
                                        fundraiser['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      
                                      // Better progress indicator
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            progress >= 1.0 ? Colors.blue : Colors.green,
                                          ),
                                          minHeight: 6,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      
                                      // Improved stats row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '\$${fundraiser['funding'].toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'of \$${fundraiser['donationAmount'].toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${fundraiser['donators']} donors',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
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
