import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Add this import

class FundraisingHomePage extends StatelessWidget {
  final List<String> imagePaths = [
    'assets/sample1.jpg',
    'assets/sample2.jpg',
    'assets/sample3.jpg',
  ];

  final List<String> imageCaptions = [
    'Help Alice Brain Surgery',
    'Support Flood Victims',
    'Education for All',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            Row(
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
            SizedBox(height: 20),
            Container(
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
            SizedBox(height: 20),
            _buildImageSlider(), // Image Slider added here
            SizedBox(height: 20),
            _buildFundraisingSection('Urgent Fundraising', ['All', 'Medical', 'Disaster', 'Education']),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider() {
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
      ),
      items: imagePaths.asMap().entries.map((entry) {
        int index = entry.key;
        String imagePath = entry.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity),
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
                  imageCaptions[index],
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
  }

  Widget _buildFundraisingSection(String title, List<String> filters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('See all', style: TextStyle(color: Colors.green))
          ],
        ),
        if (filters.isNotEmpty)
          Row(
            children: filters
                .map((filter) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(filter),
                        backgroundColor:
                            filter == 'All' ? Colors.green : Colors.grey[200],
                      ),
                    ))
                .toList(),
          ),
        SizedBox(height: 10),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Image.asset(
                            'assets/sample.jpg',
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Help Orphanage Children',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            LinearProgressIndicator(value: 0.6, color: Colors.green),
                            SizedBox(height: 5),
                            Text('\$2,379 raised from \$4,200',
                                style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
