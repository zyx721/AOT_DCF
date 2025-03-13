import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/modern_app_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> chats = const [
    {"name": "Kathryn Murphy", "message": "I will make a donatio...", "time": "20.00", "unread": 2},
    {"name": "Darrell Steward", "message": "Perfect!", "time": "16.47", "unread": 0},
    {"name": "Jane Cooper", "message": "Omg, this is amazing", "time": "13.36", "unread": 1},
    {"name": "Eleanor Pena", "message": "Just ideas for next time", "time": "Yesterday", "unread": 0},
    {"name": "Annette Black", "message": "Wow, this is really epic", "time": "Yesterday", "unread": 0},
    {"name": "Guy Hawkins", "message": "That's awesome!", "time": "2 days ago", "unread": 0},
    {"name": "Jenny Wilson", "message": "See you soon!", "time": "3 days ago", "unread": 0},
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
      backgroundColor: Colors.white,
      appBar: ModernAppBar(
        title: 'Inbox',
        showLogo: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                prefixIcon: Icon(Icons.search, color: const Color(0xFF57AB7D)),
                hintText: "Search",
                hintStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredChats.length,
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF57AB7D).withOpacity(0.1),
                    child: Icon(Icons.person, color: const Color(0xFF57AB7D), size: 30),
                  ),
                  title: Text(
                    chat["name"],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat["message"],
                    style: GoogleFonts.poppins(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        chat["time"],
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
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
                  onTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
