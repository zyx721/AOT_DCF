import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/drive.dart';
import '../../widgets/modern_app_bar.dart';
import '../select_interest_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instance;
  final GoogleDriveService _driveService = GoogleDriveService();
  bool _isUploading = false;

  Widget _buildStatItem(String title, String count) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey,
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
        ),
      ),
      backgroundColor: const Color(0xFF57AB7D).withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF57AB7D)),
      ),
    );
  }

  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final file = File(image.path);
        final imageUrl = await _driveService.uploadFile(file);
        
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(imageUrl);
        await firestore.collection('users').doc(user?.uid).update({
          'photoURL': imageUrl,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile picture: $e')),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _updateAboutMe() async {
    final TextEditingController _aboutController = TextEditingController();
    final userData = await firestore.collection('users').doc(user?.uid).get();
    _aboutController.text = (userData.data() as Map<String, dynamic>)['aboutMe'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit About Me', style: GoogleFonts.poppins()),
        content: TextField(
          controller: _aboutController,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {  // Added async here
              await firestore.collection('users').doc(user?.uid).update({
                'aboutMe': _aboutController.text,
              });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editInterests() async {
    final userSnapshot = await firestore.collection('users').doc(user?.uid).get();
    final currentInterests = userSnapshot.data()?['interests'] ?? [];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectInterestScreen(
          isEditing: true,
          currentInterests: currentInterests,
        ),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: ModernAppBar(
        title: "Profile",
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final interests = (userData['interests'] as List<dynamic>?) ?? [];
          final aboutMe = userData['aboutMe'] as String? ?? "No description provided yet.";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundImage: NetworkImage(user?.photoURL ?? ''),
                        child: _isUploading
                            ? CircularProgressIndicator()
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: Icon(Icons.edit, color: const Color(0xFF57AB7D)),
                            onPressed: _updateProfilePicture,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          user?.displayName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _updateAboutMe,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "About Me",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF57AB7D),
                                      ),
                                    ),
                                    Icon(Icons.edit, 
                                        color: const Color(0xFF57AB7D),
                                        size: 18),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  aboutMe,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem("Fundraising", "0"),
                            _buildStatItem("Followers", "0"),
                            _buildStatItem("Following", "0"),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet,
                                        color: const Color(0xFF57AB7D)),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "\$0",
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "My wallet balance",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF57AB7D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text("Top up",
                                      style: GoogleFonts.poppins(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _editInterests(),  // Fixed here
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Interest",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.edit, color: const Color(0xFF57AB7D)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests
                              .map((e) => _buildInterestChip(e.toString()))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
