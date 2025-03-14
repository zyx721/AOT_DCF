import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/screens/Chatbot_screen/chatbot.dart';
import 'package:frontend/screens/donation_screen/donation_screen.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';

class AssociationScreen extends StatefulWidget {
  final Map<String, dynamic> fundraiser;

  AssociationScreen({required this.fundraiser});

  @override
  _AssociationScreenState createState() => _AssociationScreenState();
}

class _AssociationScreenState extends State<AssociationScreen> {
  bool _isLoadingPdf = false;
  int _currentImageIndex = 0;

  Future<void> _openPdfFile(String? url, String title) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document available')),
      );
      return;
    }

    setState(() => _isLoadingPdf = true);

    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/document.pdf');
      await file.writeAsBytes(bytes);

      setState(() => _isLoadingPdf = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(title),
            ),
            body: PDFView(
              filePath: file.path,
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoadingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading PDF: $e')),
      );
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
                child: Center(child: CircularProgressIndicator()),
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
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchCreatorInfo(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
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
                        title: Text(
                          creator['name'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${creator['city']}, ${creator['country']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () {},
                          child: Text('Follow'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
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
          onTap: () => _openPdfFile(
            widget.fundraiser['additionalDocUrl'],
            'Additional Documents',
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
            _isLoadingPdf
                ? CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: () => _openPdfFile(
                      widget.fundraiser['proposalDocUrl'],
                      'Fund Usage Plan',
                    ),
                    icon: Icon(Icons.visibility, size: 18),
                    label: Text('View Plan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
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
