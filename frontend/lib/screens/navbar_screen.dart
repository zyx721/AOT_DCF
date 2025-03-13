import 'package:flutter/material.dart';

import 'notification_screen.dart';
import 'profile_screen.dart';
import 'forum_screens/create_forum_screen.dart';
import 'forum_screens/forums_screen.dart';
import 'map_screen.dart';

class NavBarScreen extends StatefulWidget {
  const NavBarScreen({Key? key}) : super(key: key);

  @override
  _NavBarScreenState createState() => _NavBarScreenState();
}

class _NavBarScreenState extends State<NavBarScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const MapScreen(),
   FundraisingHomePage(),
    const NotificationScreen(),
     ProfileScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateFundraisingScreen(),
            ),
          );
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, size: 32),
        tooltip: 'Create Forum',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8.0,
        shape: const CircularNotchedRectangle(),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left side icons
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.map,
                        color: _selectedIndex == 0 ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.forum,
                        color: _selectedIndex == 1 ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 1),
                    ),
                  ],
                ),
              ),
              
              // Middle space for FAB
              const SizedBox(width: 48.0),
              
              // Right side icons
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications,
                        color: _selectedIndex == 2 ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 2),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.person,
                        color: _selectedIndex == 3 ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 3),
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
}