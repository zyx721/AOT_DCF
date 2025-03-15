import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_fund_screen.dart';
import 'edit_fund_screen.dart';  // Add this import
import '../../widgets/results.dart';  // Add this import

class FundraisingScreen extends StatefulWidget {
  @override
  _FundraisingScreenState createState() => _FundraisingScreenState();
}

class _FundraisingScreenState extends State<FundraisingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<QuerySnapshot>? _fundraisersStream;
  int totalCount = 0;
  int ongoingCount = 0;
  int pastCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    _fundraisersStream = FirebaseFirestore.instance
        .collection('fundraisers')
        .where('creatorId', isEqualTo: currentUser?.uid)
        .snapshots();

    // Calculate counts
    _updateCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateCounts() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('fundraisers')
        .where('creatorId', isEqualTo: currentUser.uid)
        .get();

    int ongoing = 0;
    int past = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final expirationDate = (data['expirationDate'] as Timestamp).toDate();
      if (expirationDate.isAfter(DateTime.now())) {
        ongoing++;
      } else {
        past++;
      }
    }

    setState(() {
      totalCount = snapshot.docs.length;
      ongoingCount = ongoing;
      pastCount = past;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 40),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.green, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'My Fundraising',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: 'Fundraisers'),
              Tab(text: 'Activity'),
            ],
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Fundraisers Tab
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            _buildFilterChip('All ($totalCount)', false),
                            SizedBox(width: 8),
                            _buildFilterChip('Ongoing ($ongoingCount)', true),
                            SizedBox(width: 8),
                            _buildFilterChip('Past ($pastCount)', false),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      // Existing StreamBuilder with fundraiser cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _fundraisersStream,
                          builder: (context, snapshot) {
                            // Trigger counts update when data changes
                            if (snapshot.hasData) {
                              _updateCounts();
                            }
                            if (snapshot.hasError) {
                              return Text('Something went wrong');
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No fundraisers yet. Create your first one!',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final fundraiserDoc = snapshot.data!.docs[index];
                                final fundraiserData = fundraiserDoc.data() as Map<String, dynamic>;
                                
                                // Calculate days left
                                final expirationDate = (fundraiserData['expirationDate'] as Timestamp).toDate();
                                final daysLeft = expirationDate.difference(DateTime.now()).inDays;

                                final fundraiser = {
                                  ...fundraiserData,
                                  'id': fundraiserDoc.id,
                                  'daysLeft': daysLeft,
                                  // Use default image if mainImageUrl is null
                                  'image': fundraiserData['mainImageUrl'] ?? 'assets/default_fundraiser.jpg',
                                };

                                return FundraisingCard(fundraiser);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Activity Tab (Empty for now)
                Center(
                  child: Text(
                    'Activity coming soon',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateFundraisingScreen()),
          );
        },
        child: Icon(Icons.add, size: 30),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {},
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.green,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      pressElevation: 2,
      shadowColor: Colors.black26,
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// Update FundraisingCard to handle the new data structure
class FundraisingCard extends StatelessWidget {
  final Map<String, dynamic> fundraiser;

  FundraisingCard(this.fundraiser);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12), // Reduced bottom margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10.0), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  flex: 25, // 25% of space
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: fundraiser['image'].startsWith('assets/')
                        ? Image.asset(
                            fundraiser['image'],
                            width: double.infinity,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: fundraiser['image'],
                            width: double.infinity,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error),
                          ),
                  ),
                ),
                SizedBox(width: 10), // Reduced spacing
                Flexible(
                  flex: 75, // 75% of space
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fundraiser['title'] ?? 'Untitled Fundraiser',
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6), // Reduced spacing
                      Text(
                        '\$${fundraiser['funding']?.toString() ?? '0'} raised of \$${fundraiser['donationAmount']?.toString() ?? '0'}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13, // Added smaller font size
                        ),
                      ),
                      SizedBox(height: 6), // Reduced spacing
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (fundraiser['funding'] ?? 0) / (fundraiser['donationAmount'] ?? 1),
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 4, // Reduced from 6
                        ),
                      ),
                      SizedBox(height: 6), // Reduced spacing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, size: 12, color: Colors.grey[600]), // Reduced icon size
                              SizedBox(width: 3),
                              Text(
                                '${fundraiser['donators'] ?? 0} donors',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            '${fundraiser['daysLeft']} days left',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 16), // Reduced divider height
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.edit, 'Edit'),
                _buildActionButton(Icons.share, 'Share'),
                TextButton(
                  onPressed: () {
                    showFundraisingDialog(context, fundraiser);  // Now this will work
                  },
                  child: Text(
                    'See Results',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Builder(  // Wrap with Builder to get context
      builder: (BuildContext context) {  // Get context here
        return TextButton.icon(
          onPressed: () {
            if (label == 'Edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditFundraisingScreen(
                    fundraiserId: fundraiser['id'],
                    fundraiserData: fundraiser,
                  ),
                ),
              );
            }
          },
          icon: Icon(icon, color: Colors.grey[600], size: 16), // Reduced icon size
          label: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13), // Added smaller font size
          ),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}
