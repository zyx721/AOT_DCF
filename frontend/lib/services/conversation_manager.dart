import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationManager {
  static final List<Map<String, dynamic>> _history = [];
  static final _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  static const String _storageKey = 'chat_history';

  static Stream<List<Map<String, dynamic>>> get historyStream => _historyController.stream;
  static List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  static Future<void> initialize() async {
    await loadHistory();
  }

  static void addMessage(Map<String, dynamic> message) {
    _history.add(message);
    _historyController.add(_history);
    saveHistory();
  }

  static Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedHistory = prefs.getString(_storageKey);
      if (storedHistory != null) {
        final List<dynamic> decoded = json.decode(storedHistory);
        _history.clear();
        _history.addAll(decoded.cast<Map<String, dynamic>>());
        _historyController.add(_history);
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  static Future<void> saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json.encode(_history));
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  static Future<void> clearHistory() async {
    _history.clear();
    _historyController.add(_history);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  static void updateHistory(List<Map<String, dynamic>> newHistory) {
    _history.clear();
    _history.addAll(newHistory);
    _historyController.add(_history);
    saveHistory();
  }

  static void dispose() {
    _historyController.close();
  }
}
