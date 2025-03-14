import 'package:flutter/material.dart';
import 'package:frontend/screens/map_screen.dart';
import 'Home_screen/home_screen.dart';
import 'Chatbot_screen/chatbot.dart'; // Updated import
import 'Fundraising_screen/fundraising_screen.dart';
import 'Chat_screen/chat_screen.dart';
import 'Profile_screen/profile_screen.dart';

class NavBarScreen extends StatefulWidget {
  const NavBarScreen({Key? key}) : super(key: key);

  @override
  _NavBarScreenState createState() => _NavBarScreenState();
}

class _NavBarScreenState extends State<NavBarScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    const MapScreen(),
    FundraisingScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  Widget _buildNavItem(IconData icon, int index, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF57AB7D)
                  : const Color(0xFF57AB7D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF57AB7D),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF57AB7D) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 0, 'Home'),
            _buildNavItem(Icons.map_rounded, 1, 'Map'),
            _buildNavItem(Icons.volunteer_activism_rounded, 2, 'Fundraise'),
            _buildNavItem(Icons.chat_rounded, 3, 'Chat'),
            _buildNavItem(Icons.person_rounded, 4, 'Profile'),
          ],
        ),
      ),
    );
  }
}
