import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/screens/Chatbot_screen/voice_chat_screen.dart';
import 'package:frontend/screens/colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:frontend/services/conversation_manager.dart';
import 'package:frontend/widgets/modern_app_bar.dart';
import 'package:lottie/lottie.dart'; // Add this import

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  late WebSocketChannel channel;
  final audioPlayer = AudioPlayer();
  bool _isProcessing = false; // Add this flag to prevent overlapping
  late Stream broadcastStream;
  List<Map<String, dynamic>> _conversationHistory = []; // Add this line
  late final genai.GenerativeModel model;
  bool _isGeneratingResponse = false;
  Timer? _autoSaveTimer;
  StreamSubscription? _historySubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Set up auto-save timer
    _autoSaveTimer = Timer.periodic(Duration(seconds: 1), (_) {
      ConversationManager.saveHistory();
    });
    // Subscribe to history updates
    _historySubscription = ConversationManager.historyStream.listen((history) {
      if (mounted) {
        setState(() {
          _conversationHistory = history;
          _messages.clear();
          for (var msg in history.reversed) {
            _messages.add(ChatMessage(
              text: msg['text'],
              isUser: msg['isUser'],
              timestamp: DateTime.parse(msg['timestamp']),
            ));
          }
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    await ConversationManager.initialize();
    await _loadConversationHistory();
    _initializeSpeech();
    _connectWebSocket();
    _setupAudioPlayerListeners();
    _initializeGemini();
  }

  Future<void> _loadConversationHistory() async {
    await ConversationManager.loadHistory();
    if (mounted) {
      setState(() {
        _conversationHistory = ConversationManager.history;
        _messages.clear();
        // Only add messages once from the history
        for (var msg in _conversationHistory.reversed) {
          _messages.add(ChatMessage(
            text: msg['text'],
            isUser: msg['isUser'],
            timestamp: DateTime.parse(msg['timestamp']),
          ));
        }
      });
    }
  }

  void _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      debugPrint("Speech recognition not available");
    }
  }

  void _setupAudioPlayerListeners() {
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Automatically start listening when audio finishes
        _startListening();
      }
    });
  }

  void _connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://10.222.202.216:8000/ws'),
      );

      broadcastStream = channel.stream.asBroadcastStream();

      broadcastStream.listen(
        (message) async {
          _logMessage('Received message: $message');
          if (_isProcessing) return;
          _isProcessing = true;

          try {
            final data = json.decode(message);
            if (data['type'] == 'response') {
              if (mounted) {
                // Remove direct message insertion here and only use ConversationManager
                final botMessage = {
                  'text': data['text'],
                  'isUser': false,
                  'timestamp': DateTime.now().toIso8601String(),
                };
                ConversationManager.addMessage(botMessage);
              }
            }
          } catch (e) {
            print('Error processing message: $e');
          } finally {
            _isProcessing = false;
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _reconnectWebSocket();
        },
        onDone: () {
          print('WebSocket connection closed');
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _reconnectWebSocket();
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _connectWebSocket();
      }
    });
  }

  void _startListening() async {
    if (_isListening || _isProcessing) return;

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        print('Speech error: $error');
        setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognizedText = result.recognizedWords;
            if (recognizedText.isNotEmpty) {
              // Remove direct message insertion and only use ConversationManager
              final userMessage = {
                'text': recognizedText,
                'isUser': true,
                'timestamp': DateTime.now().toIso8601String(),
              };
              ConversationManager.addMessage(userMessage);

              channel.sink.add(json.encode({
                'type': 'text',
                'user_id': '12345',
                'text': recognizedText,
              }));

              _stopListening(); // Stop listening after sending
            }
          }
        },
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        listenFor: Duration(seconds: 10), // Adjust this duration as needed
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _initializeGemini() {
    model = genai.GenerativeModel(
        model: 'models/gemini-2.0-flash',
        apiKey: 'AIzaSyDjsiA8U72-Zqt3xD4cEUHW8V5NooY6Y2A');
  }

  Future<void> _handleSubmitted(String text) async {
    _messageController.clear();
    if (text.trim().isEmpty) return;

    final userMessage = {
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Only use ConversationManager to handle messages
    ConversationManager.addMessage(userMessage);
    setState(() => _isGeneratingResponse = true);

    try {
      final contextPrompt = ConversationManager.getContextPrompt();
      final prompt = contextPrompt + "\nUser: " + text;

      final content = [genai.Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText =
          response.text ?? "Sorry, I couldn't generate a response";

      final botMessage = {
        'text': responseText,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (mounted) {
        ConversationManager.addMessage(botMessage);
        setState(() => _isGeneratingResponse = false);
      }
    } catch (e) {
      print('Error generating response: $e');
      if (mounted) {
        setState(() => _isGeneratingResponse = false);
        final errorMessage = {
          'text': 'Sorry, I encountered an error. Please try again.',
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        };
        ConversationManager.addMessage(errorMessage);
      }
    }
  }

  void _openVoiceChatScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceChatScreen(
          channel: channel,
          messageStream: broadcastStream,
          onConversationComplete: (conversation) {},
          initialConversation: _conversationHistory,
        ),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>> && mounted) {
      // Let ConversationManager handle the messages
      for (final message in result) {
        if (!_conversationHistory.any((m) =>
            m['timestamp'] == message['timestamp'] &&
            m['text'] == message['text'])) {
          ConversationManager.addMessage(message);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Chat Assistant',
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Clear History'),
                  content: Text('Are you sure you want to clear all messages?'),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: Text('Clear'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ConversationManager.clearHistory();
                setState(() {
                  _messages.clear();
                  _conversationHistory.clear();
                });
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
              Color.fromARGB(255, 26, 126, 51).withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Add decorative shapes
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 26, 126, 51).withOpacity(0.2),
                      Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 26, 126, 51).withOpacity(0.15),
                      Color.fromARGB(255, 26, 126, 51).withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: isUser
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 26, 126, 51),
                    Color.fromARGB(120, 26, 126, 51),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/profile.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            )
          : SizedBox(
              width: 45,
              height: 45,
              child: Lottie.asset(
                'assets/animation/voice_wave.json',
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(isUser: false),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 26, 126, 51),
                        Color.fromARGB(120, 26, 126, 51),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color.fromARGB(120, 26, 126, 51),
                        Color.fromARGB(65, 26, 126, 51),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          if (message.isUser) _buildAvatar(isUser: true),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _openVoiceChatScreen,
            color: Colors.grey,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isGeneratingResponse,
              decoration: InputDecoration(
                hintText: _isGeneratingResponse
                    ? 'Generating response...'
                    : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey[100],
                filled: true,
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isGeneratingResponse
                ? null
                : () => _handleSubmitted(_messageController.text),
            color: _isGeneratingResponse ? Colors.grey : Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _autoSaveTimer?.cancel();
    // Save one final time before disposing
    ConversationManager.saveHistory();
    _messageController.dispose();
    channel.sink.close();
    audioPlayer.dispose();
    super.dispose();
  }

  void _logMessage(String message) {
    print('${DateTime.now()}: $message');
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
