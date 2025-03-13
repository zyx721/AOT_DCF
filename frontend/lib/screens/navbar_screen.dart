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
    const ForumsScreen(),
    const MapScreen(),
    const NotificationScreen(),
    ProfileScreen(),
  ];

  void _showCreateForumModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a Forum',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose forum type:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateForumScreen(isAnonymous: false),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.public, size: 50, color: Colors.blue),
                            SizedBox(height: 10),
                            Text(
                              'Public Forum',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Visible to everyone with all contributor details shown',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateForumScreen(isAnonymous: true),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.masks, size: 50, color: Colors.purple),
                            SizedBox(height: 10),
                            Text(
                              'Anonymous Forum',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Protects privacy of those in need by hiding personal details',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateForumModal,
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
                        Icons.forum,
                        color: _selectedIndex == 0 ? Colors.deepPurple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.map,
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