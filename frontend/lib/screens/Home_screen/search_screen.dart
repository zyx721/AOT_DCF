import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../association_screen.dart';
import '../reels_screen/reels_screen.dart';

class SearchPage extends StatefulWidget {
  final int initialTabIndex;

  const SearchPage({
    Key? key,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  Stream<QuerySnapshot> getFundraisersStream() {
    Query query = FirebaseFirestore.instance.collection('fundraisers')
        .where('status', isEqualTo: 'pending'); // Only show pending fundraisers

    // Apply category filter if not 'All'
    if (_selectedFilter != 'All') {
      query = query.where('category', isEqualTo: _selectedFilter);
    }

    return query.orderBy('createdAt', descending: true).limit(20).snapshots();
  }

  Stream<QuerySnapshot> getVideosStream() {
    Query query = FirebaseFirestore.instance.collection('videos');

    return query.orderBy('createdAt', descending: true).limit(20).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Fundraisers'),
              Tab(text: 'Videos'),
            ],
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            indicatorWeight: 3,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFundraisersTab(),
                  _buildVideosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundraisersTab() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
            ].map((filter) => Padding(
              padding: EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color: _selectedFilter == filter ? Colors.white : Colors.black,
                  ),
                ),
                selected: _selectedFilter == filter,
                selectedColor: Colors.green,
                backgroundColor: Colors.grey[200],
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = selected ? filter : 'All';
                  });
                },
              ),
            )).toList(),
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: getFundraisersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Something went wrong'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No fundraisers found'));
              }

              // Perform client-side filtering for multiple field search
              var filteredDocs = snapshot.data!.docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                String searchLower = _searchQuery.toLowerCase();
                String title = (data['title'] ?? '').toLowerCase();
                String story = (data['story'] ?? '').toLowerCase();
                String recipientName = (data['recipientName'] ?? '').toLowerCase();
                
                return title.contains(searchLower) ||
                       story.contains(searchLower) ||
                       recipientName.contains(searchLower);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(child: Text('No fundraisers found'));
              }

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var fundraiser = filteredDocs[index];
                  return _buildFundraiserCard(fundraiser);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getVideosStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No videos found'));
        }

        // Perform client-side filtering for multiple field search
        var filteredDocs = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String searchLower = _searchQuery.toLowerCase();
          String title = (data['title'] ?? '').toLowerCase();
          String creatorName = (data['creatorName'] ?? '').toLowerCase();
          
          return title.contains(searchLower) ||
                 creatorName.contains(searchLower);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text('No videos found'));
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var video = filteredDocs[index];
            return _buildVideoCard(video, filteredDocs);
          },
        );
      },
    );
  }

  void _navigateToReelsWithSearch(DocumentSnapshot currentVideo, List<DocumentSnapshot> allVideos) {
    int initialIndex = allVideos.indexWhere((video) => video.id == currentVideo.id);
    if (initialIndex == -1) initialIndex = 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReelsScreen(
          initialIndex: initialIndex,
          videos: allVideos,
          searchQuery: _searchQuery,
        ),
      ),
    );
  }

  Widget _buildFundraiserCard(DocumentSnapshot fundraiser) {
    Map<String, dynamic> data = fundraiser.data() as Map<String, dynamic>;
    double progress = data['funding'] / data['donationAmount'];
    DateTime expirationDate = (data['expirationDate'] as Timestamp).toDate();
    bool isExpired = expirationDate.isBefore(DateTime.now());
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssociationScreen(
              fundraiser: {
                'id': fundraiser.id,
                ...data,
              },
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: data['mainImageUrl'] ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.error),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$${data['funding'].toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(' of \$${data['donationAmount'].toStringAsFixed(0)}'),
                        Spacer(),
                        Icon(Icons.people, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('${data['donators']} donors'),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Expires: ${expirationDate.toString().split(' ')[0]}',
                      style: TextStyle(
                        color: isExpired ? Colors.red : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(DocumentSnapshot video, List<DocumentSnapshot> allVideos) {
    Map<String, dynamic> data = video.data() as Map<String, dynamic>;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToReelsWithSearch(video, allVideos),
        child: Stack(
          children: [
            // Cover Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: data['mainImageUrl'] ?? '',
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.error),
                ),
              ),
            ),
            // Gradient overlay and text
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Text content
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(data['creatorId'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.grey[200],
                            );
                          }
                          
                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          final userPhotoURL = userData?['photoURL'] as String? ?? '';
                          
                          return CircleAvatar(
                            radius: 10,
                            backgroundImage: userPhotoURL.isNotEmpty 
                              ? NetworkImage(userPhotoURL)
                              : null,
                            child: userPhotoURL.isEmpty 
                              ? Icon(Icons.person, size: 12)
                              : null,
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'By ${data['creatorName'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
