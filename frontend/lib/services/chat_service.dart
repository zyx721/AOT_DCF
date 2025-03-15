import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static String generateChatId(String user1Id, String user2Id) {
    final sortedIds = [user1Id, user2Id]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  static Future<String> createOrGetChat(String user1Id, String user2Id) async {
    final chatId = generateChatId(user1Id, user2Id);

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();

    if (!chatDoc.exists) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [user1Id, user2Id],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });
    }

    return chatId;
  }
}
