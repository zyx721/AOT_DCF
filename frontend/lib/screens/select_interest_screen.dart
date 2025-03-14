import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectInterestScreen extends StatefulWidget {
  final bool isEditing;
  final List<dynamic> currentInterests;

  const SelectInterestScreen({
    Key? key, 
    this.isEditing = false,
    this.currentInterests = const [],
  }) : super(key: key);

  @override
  _SelectInterestScreenState createState() => _SelectInterestScreenState();
}

class _SelectInterestScreenState extends State<SelectInterestScreen> {
  // Interest data with icons
  final List<Map<String, dynamic>> interests = [
    {'name': 'Education', 'icon': Icons.school},
    {'name': 'Environment', 'icon': Icons.public},
    {'name': 'Social', 'icon': Icons.groups},
    {'name': 'Sick child', 'icon': Icons.child_care},
    {'name': 'Medical', 'icon': Icons.medical_services},
    {'name': 'Infrastructure', 'icon': Icons.business},
    {'name': 'Art', 'icon': Icons.palette},
    {'name': 'Disaster', 'icon': Icons.warning},
    {'name': 'Orphanage', 'icon': Icons.home},
    {'name': 'Difable', 'icon': Icons.accessible},
    {'name': 'Humanity', 'icon': Icons.diversity_3},
    {'name': 'Others', 'icon': Icons.category},
  ];

  final Set<String> selectedInterests = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      selectedInterests.addAll(widget.currentInterests.cast<String>());
    }
  }

  Future<void> _saveInterests() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'interests': selectedInterests.toList(),
        'interestsUpdatedAt': DateTime.now(),
      });

      if (mounted) {
        // Show success dialog before navigation
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const FadeInSuccessDialog(),
        );
        if (widget.isEditing && mounted) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacementNamed(context, '/navbar');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving interests: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Your Interest', style: GoogleFonts.poppins()),
        centerTitle: true,
        backgroundColor: const Color(0xFF57AB7D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose your interests to donate. Don't worry, you can always change them later.",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85, // Adjusted for the added icon
                ),
                itemCount: interests.length,
                itemBuilder: (context, index) {
                  final interest = interests[index]['name'] as String;
                  final icon = interests[index]['icon'] as IconData;
                  final isSelected = selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedInterests.remove(interest);
                        } else {
                          selectedInterests.add(interest);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFF57AB7D) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF57AB7D)),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF57AB7D).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 32,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF57AB7D),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            interest,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF57AB7D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedInterests.isNotEmpty && !_isLoading
                    ? _saveInterests
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF57AB7D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FadeInSuccessDialog extends StatefulWidget {
  const FadeInSuccessDialog({Key? key}) : super(key: key);

  @override
  _FadeInSuccessDialogState createState() => _FadeInSuccessDialogState();
}

class _FadeInSuccessDialogState extends State<FadeInSuccessDialog>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _opacity,
      curve: Curves.easeInOut,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF57AB7D).withOpacity(0.1),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF57AB7D),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Great!",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF57AB7D),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Your interests have been saved successfully",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF57AB7D),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "Continue",
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
