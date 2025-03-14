import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class ConversationManager {
  static List<Map<String, dynamic>> _conversationHistory = [];
  static bool _isInitialized = false;

  static final _historyController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static Stream<List<Map<String, dynamic>>> get historyStream =>
      _historyController.stream;

  static List<Map<String, dynamic>> get history => _conversationHistory;

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/conversation_history.json');
  }

  static Future<void> initialize() async {
    if (!_isInitialized) {
      await loadHistory();
      _isInitialized = true;
    }
  }

  static Future<void> loadHistory() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents);
        _conversationHistory = 
            List<Map<String, dynamic>>.from(data['history'] ?? []);
      }
    } catch (e) {
      print('Error loading conversation history: $e');
      _conversationHistory = [];
    }
  }

  static Future<void> saveHistory() async {
    try {
      final file = await _localFile;
      await file.writeAsString(json.encode({'history': _conversationHistory}));
    } catch (e) {
      print('Error saving conversation history: $e');
    }
  }

  static void addMessage(Map<String, dynamic> message) {
    _conversationHistory.add(message);
    saveHistory();
    _historyController.add(_conversationHistory);
  }

  static String getContextPrompt() {
    if (_conversationHistory.isEmpty) return '';
    
    final buffer = StringBuffer();
    final recentMessages = _conversationHistory.reversed.take(5);
    for (var msg in recentMessages) {
      buffer.writeln('${msg['isUser'] ? 'User' : 'Assistant'}: ${msg['text']}');
    }
    return buffer.toString();
  }

  static Future<void> clearHistory() async {
    _conversationHistory.clear();
    await saveHistory();
    _historyController.add(_conversationHistory);
  }

  // Add this method
  static void updateHistory(List<Map<String, dynamic>> newHistory) {
    _conversationHistory = List.from(newHistory);
    saveHistory();
    _historyController.add(_conversationHistory);
  }

  static void dispose() {
    _historyController.close();
  }
}
