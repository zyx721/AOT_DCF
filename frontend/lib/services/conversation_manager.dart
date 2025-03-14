import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class ConversationManager {
  static List<Map<String, dynamic>> _conversationHistory = [];
  static Map<String, dynamic> _context = {};
  static bool _isInitialized = false;
  static String _currentName = '';

  static final _historyController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static Stream<List<Map<String, dynamic>>> get historyStream =>
      _historyController.stream;

  static List<Map<String, dynamic>> get history => _conversationHistory;
  static Map<String, dynamic> get context => _context;

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
        _context = Map<String, dynamic>.from(data['context'] ?? {});
      }
    } catch (e) {
      print('Error loading conversation history: $e');
      // Initialize with empty data if loading fails
      _conversationHistory = [];
      _context = {};
    }
  }

  static Future<void> saveHistory() async {
    try {
      final file = await _localFile;
      final data = {
        'history': _conversationHistory,
        'context': _context,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      print('Error saving conversation history: $e');
    }
  }

  static void addMessage(Map<String, dynamic> message) {
    _conversationHistory.add(message);
    _updateContext(message);
    saveHistory();
    _historyController.add(_conversationHistory); // Broadcast update
  }

  static void _updateContext(Map<String, dynamic> message) {
    if (!message['isUser']) return;

    final text = message['text'].toString().toLowerCase();

    // Update name with more patterns
    if (text.contains('my name is') ||
        text.contains('call me') ||
        text.contains('i am') ||
        text.contains('my new name is')) {
      String? name = _extractName(text);
      if (name != null) {
        _currentName = name;
        _context['user_name'] = name;
        _context['name_updated_at'] = DateTime.now().toIso8601String();
      }
    }
  }

  static String? _extractName(String text) {
    final patterns = [
      RegExp(r'(?:my name is|call me|i am|my new name is)\s+(\w+)',
          caseSensitive: false),
      RegExp(r"i'm\s+(\w+)", caseSensitive: false),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  static String getContextPrompt() {
    final buffer = StringBuffer();

    // Add persistent context
    buffer.writeln(
        'You are a helpful AI assistant. Maintain consistent information about the user.');

    if (_context.containsKey('user_name')) {
      buffer.writeln('The user\'s current name is "${_context['user_name']}".');
      buffer.writeln('Always remember and use their name when appropriate.');

      // Add recent conversation summary
      if (_conversationHistory.isNotEmpty) {
        buffer.writeln('\nRecent conversation context:');
        final recentMessages = _conversationHistory.reversed.take(5);
        for (var msg in recentMessages) {
          buffer.writeln(
              '${msg['isUser'] ? 'User' : 'Assistant'}: ${msg['text']}');
        }
      }
    }

    return buffer.toString();
  }

  static String? getCurrentName() =>
      _currentName.isNotEmpty ? _currentName : null;

  static Future<void> clearHistory() async {
    _conversationHistory.clear();
    _context.clear();
    _currentName = '';
    await saveHistory();
    _historyController.add(_conversationHistory); // Broadcast update
  }

  static void updateHistory(List<Map<String, dynamic>> newHistory) {
    _conversationHistory = newHistory;
    // Rebuild context from history
    _context.clear();
    for (final message in newHistory) {
      _updateContext(message);
    }
    saveHistory();
  }

  // Add dispose method
  static void dispose() {
    _historyController.close();
  }
}
