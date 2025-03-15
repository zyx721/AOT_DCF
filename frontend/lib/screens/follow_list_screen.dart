import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'view_profile_screen/view_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final bool isFollowers; // true for followers, false for following
  
  const FollowListScreen({
    Key? key, 
    required this.userId,
    required this.isFollowers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFollowers ? 'Followers' : 'Following',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF57AB7D),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final List<String> userIds = List<String>.from(
            isFollowers ? (userData['followers'] ?? []) : (userData['following'] ?? [])
          );

          if (userIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFollowers ? Icons.people_outline : Icons.person_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFollowers ? 'No followers yet' : 'Not following anyone yet',
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
            padding: const EdgeInsets.all(8),
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userIds[index])
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final followData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = followData['name'] ?? 'User';
                  final photoURL = followData['photoURL'] ?? '';
                  final location = _getLocation(followData);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewProfileScreen(
                              userId: userIds[index],
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundImage: photoURL.isNotEmpty
                            ? CachedNetworkImageProvider(photoURL)
                            : null,
                        child: photoURL.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: location.isNotEmpty
                          ? Text(
                              location,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            },
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
}
