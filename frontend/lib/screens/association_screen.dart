import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/donation_screen/donation_screen.dart';

class AssociationScreen extends StatelessWidget {
  final Map<String, dynamic> fundraiser;

  AssociationScreen({required this.fundraiser});

  @override
  Widget build(BuildContext context) {
    double progress = fundraiser['funding'] / fundraiser['donationAmount'];

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
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'fundraiser-${fundraiser['id']}',
              child: CachedNetworkImage(
                imageUrl:
                    fundraiser['mainImageUrl'] ?? 'assets/placeholder.jpg',
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fundraiser['title'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '\$${fundraiser['funding'].toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      Text(
                        ' fund raised from \$${fundraiser['donationAmount'].toStringAsFixed(0)}',
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
                      Text('${fundraiser['donators']} Donators',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          )),
                      Text('${fundraiser['daysLeft']} days left',
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
                            builder: (context) => DonationScreen(),
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
                      child: Text(
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
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.home, color: Colors.white),
                    ),
                    title: Text(
                      fundraiser['organization'] ?? 'Healthy Home',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Verified'),
                      ],
                    ),
                    trailing: OutlinedButton(
                      onPressed: () {},
                      child: Text('Follow'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green),
                      ),
                    ),
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
        Text('Patient Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.person, color: Colors.blue),
          ),
          title: Text(fundraiser['patientName'] ?? 'Patient Name',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Identity verified according to documents'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.red[100],
            child: Icon(Icons.local_hospital, color: Colors.red),
          ),
          title: Text(fundraiser['diagnosis'] ?? 'Medical Condition',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Accompanied by medical documents'),
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
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.visibility, size: 18),
              label: Text('View Plan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: BorderSide(color: Colors.green),
              ),
            ),
          ],
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
          fundraiser['story'] ?? 'No story available...',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Prayers from Good People',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {},
              child: Text('See all'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildPrayerCard(
            'Esther Howard',
            'Hopefully the patient can get surgery soon, recover from illness.',
            48),
        _buildPrayerCard('Robert Brown', 'Praying for a quick recovery.', 39),
      ],
    );
  }

  Widget _buildPrayerCard(String name, String message, int likes) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  child: Text(name[0],
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 12),
                Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.black87, height: 1.4)),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('$likes people sent this prayer',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
