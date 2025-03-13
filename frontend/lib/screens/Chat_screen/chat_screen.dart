import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/modern_app_bar.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> chats = const [
    {
      "name": "Kathryn Murphy",
      "message": "I will make a donatio...",
      "time": "20.00",
      "unread": 2,
      "isOnline": true
    },
    {
      "name": "Darrell Steward",
      "message": "Perfect!",
      "time": "16.47",
      "unread": 0,
      "isOnline": false
    },
    {
      "name": "Jane Cooper",
      "message": "Omg, this is amazing",
      "time": "13.36",
      "unread": 1,
      "isOnline": false
    },
    {
      "name": "Eleanor Pena",
      "message": "Just ideas for next time",
      "time": "Yesterday",
      "unread": 0,
      "isOnline": false
    },
    {
      "name": "Annette Black",
      "message": "Wow, this is really epic",
      "time": "Yesterday",
      "unread": 0,
      "isOnline": false
    },
    {
      "name": "Guy Hawkins",
      "message": "That's awesome!",
      "time": "2 days ago",
      "unread": 0,
      "isOnline": false
    },
    {
      "name": "Jenny Wilson",
      "message": "See you soon!",
      "time": "3 days ago",
      "unread": 0,
      "isOnline": false
    },
  ];

  List<Map<String, dynamic>> get filteredChats => chats.where((chat) {
        final name = chat["name"].toString().toLowerCase();
        final message = chat["message"].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || message.contains(query);
      }).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Changed to light grey
      appBar: ModernAppBar(
        title: 'Inbox',
        showLogo: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      prefixIcon:
                          Icon(Icons.search, color: const Color(0xFF57AB7D)),
                      hintText: "Search",
                      hintStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF57AB7D),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: () {
                      // Add filter functionality here
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredChats.length,
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: const AssetImage('assets/images/profile.jpg'),
                        ),
                        if (chat["isOnline"])
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF57AB7D),
                                border: Border.all(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        chat["name"],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      chat["message"],
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          chat["time"],
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        if (chat["unread"] > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF57AB7D),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              chat["unread"].toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            name: chat["name"],
                            imageUrl: 'assets/images/profile.jpg',
                            isOnline: chat["isOnline"],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
