import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:frontend/services/vector_store.dart';
import 'package:frontend/services/role_matcher.dart';

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
  String? _currentFileContent;
  String? _currentFileName;
  final VectorStore _vectorStore = VectorStore();
  final RoleMatcher _roleMatcher = RoleMatcher();
  bool _showRoleConfirmation = false;
  String? _suggestedRole;
  List<String> _detectedRoles = [];
  bool _showRoleOptions = false;
  bool _showRoleDetails = false;
  String? _selectedRole;
  String? _selectedRoleDetails;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Remove the system prompt from initState since it's now handled in _setupRoleMatcher

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
    _setupRoleMatcher();
  }

  Future<void> _setupRoleMatcher() async {
    try {
      final documentContent =
          await rootBundle.loadString('assets/documents/document.txt');
      final userContent =
          await rootBundle.loadString('assets/documents/user.txt');
      final userProfile = _parseUserProfile(userContent);

      _roleMatcher.initializeWithDocuments(
        documentContent: documentContent,
        userProfile: userProfile,
        rawUserProfile: userContent,
      );

      // Generate initial context and add to conversation
      final initialContext = _roleMatcher.generateRoleMatchPrompt();
      print('\n🚀 INITIAL CONTEXT SET');

      if (mounted && initialContext.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.add(ChatMessage(
            text:
                "Hello! I'm here to help you find the perfect role in our Ramadan charity campaign.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });

        // Store initial context in conversation history
        ConversationManager.addMessage({
          'text': initialContext,
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
          'isContext': true, // Mark as context message
        });
      }
    } catch (e) {
      print('❌ Error setting up role matcher: $e');
    }
  }

  Map<String, dynamic> _parseUserProfile(String content) {
    try {
      // Clean up the content and ensure proper JSON formatting
      content = content
          .replaceAll("'", '"')
          .replaceAll(RegExp(r',\s*}$'), '}')
          .trim();

      print('📝 Raw profile content:');
      print(content);

      final Map<String, dynamic> rawProfile = json.decode(content);

      // Enhanced regex patterns with better handling of different formats
      final RegExp namePattern =
          RegExp(r'Name:\s*([^,\n]+)', caseSensitive: false);
      final RegExp occupationPattern =
          RegExp(r'Occupation:\s*([^,\n]+)', caseSensitive: false);
      final RegExp capacityPattern =
          RegExp(r'Donation Capacity:\s*([^,\n]+)', caseSensitive: false);

      // Extract background information
      final background = rawProfile['background'] as String? ?? '';

      // Extract specific fields with null safety
      final name =
          namePattern.firstMatch(background)?.group(1)?.trim() ?? 'Unknown';
      final occupation =
          occupationPattern.firstMatch(background)?.group(1)?.trim() ??
              'Not specified';
      final capacity = capacityPattern.firstMatch(background)?.group(1)?.trim();

      // Build profile with default values for null cases
      final profile = {
        'background': background,
        'capacity': rawProfile['capacity'] ?? 'Not specified',
        'motivations': rawProfile['motivations'] ?? 'Not specified',
        'skills': rawProfile['skills'] ?? 'Not specified',
        'interests': rawProfile['interests'] ?? 'Not specified',
        'experience': rawProfile['experience'] ?? 'Not specified',
        'values': rawProfile['values'] ?? 'Not specified',
        'goals': rawProfile['goals'] ?? 'Not specified',
        'context': rawProfile['context'] ?? '',
        'name': name,
        'occupation': occupation,
        'donation_capacity': capacity ?? 'Not specified',
      };

      print('✅ Parsed profile:');
      print(json.encode(profile));

      return profile;
    } catch (e) {
      print('❌ Error parsing user profile: $e');
      // Return a default profile instead of empty map
      return {
        'background': 'Not provided',
        'capacity': 'Not specified',
        'motivations': 'Not specified',
        'skills': 'Not specified',
        'interests': 'Not specified',
        'experience': 'Not specified',
        'values': 'Not specified',
        'goals': 'Not specified',
        'context': '',
        'name': 'Unknown User',
        'occupation': 'Not specified',
        'donation_capacity': 'Not specified',
      };
    }
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

  List<String> _detectRoles(String text) {
    // Updated pattern to be more flexible in matching role formats
    final rolePattern =
        RegExp(r'(?:^|\n)#(\d+)[:\s-]+([^\n.]+)', multiLine: true);
    final matches = rolePattern.allMatches(text);
    final roles = <String>[];

    print('\n🔍 DETECTING ROLES IN RESPONSE:');
    print('Text being analyzed:\n$text\n');

    for (var match in matches) {
      final roleNumber = match.group(1);
      final roleTitle = match.group(2)?.trim();
      if (roleTitle != null) {
        final role = '#$roleNumber: $roleTitle';
        roles.add(role);
        print('✅ Found role: $role');
      }
    }

    if (roles.isEmpty) {
      print('❌ No roles found in the response');
    } else {
      print('📋 Total roles found: ${roles.length}');
      print('🎯 First 3 roles to display: ${roles.take(3).join("\n")}');
    }

    return roles.take(3).toList();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();

    final userMessage = {
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
    ConversationManager.addMessage(userMessage);

    setState(() => _isGeneratingResponse = true);

    try {
      final contextualPrompt = _roleMatcher.generateRoleMatchPrompt(text);
      final content = [
        genai.Content.text(contextualPrompt +
            "\nPlease format any role suggestions with #1, #2, etc.")
      ];
      final response = await model.generateContent(content);
      final responseText =
          response.text ?? "Sorry, I couldn't generate a response";

      print('\n✨ RESPONSE GENERATED');
      print('Analyzing response for roles...');

      final detectedRoles = _detectRoles(responseText);

      if (detectedRoles.isNotEmpty) {
        print('\n🎉 SHOWING ROLE OPTIONS');
        setState(() {
          _detectedRoles = detectedRoles;
          _showRoleOptions = true;
          print('🔵 Role options state updated: $_showRoleOptions');
          print('🔵 Detected roles: $_detectedRoles');
        });
      } else {
        print('\n⚠️ No roles to display');
      }

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
      print('❌ Error generating response: $e');
      setState(() => _isGeneratingResponse = false);
    }
  }

  void _handleRoleSelection(int index) {
    if (index < _detectedRoles.length) {
      final selectedRole = _detectedRoles[index];
      // Generate role details (you can customize this based on your needs)
      final roleDetails = """
Role: ${selectedRole.replaceAll(RegExp(r'^#\d+:\s*'), '')}

Description:
• Help organize and coordinate volunteer activities
• Work closely with team members
• Contribute to the success of our Ramadan charity campaign

Requirements:
• Good communication skills
• Ability to work in a team
• Commitment to the cause

Time Commitment: 
• 5-10 hours per week
• Flexible scheduling

Location: 
• Mix of remote and on-site work
""";

      setState(() {
        _selectedRole = selectedRole;
        _selectedRoleDetails = roleDetails;
        _showRoleDetails = true;
      });
    }
  }

  void _handleRoleConfirmation(bool accepted) {
    if (accepted && _selectedRole != null) {
      // Show acceptance snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role Accepted!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'You will be contacted soon with further details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Color.fromARGB(255, 26, 126, 51),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Add acceptance message to conversation
      ConversationManager.addMessage({
        'text':
            'You have accepted the role: $_selectedRole\n\nRole Details:\n$_selectedRoleDetails\n\nOur team will contact you soon with further details.',
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Navigate back to home screen after a short delay
      Future.delayed(Duration(milliseconds: 500), () {
        // Pop until we reach the home screen
        Navigator.of(context).popUntil((route) => route.isFirst);

        // Optional: You can also use a named route if you have one set up
        // Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      });
    }

    setState(() {
      _showRoleDetails = false;
      _showRoleOptions = false;
      _selectedRole = null;
      _selectedRoleDetails = null;
    });
  }

  String _getLastNMessages(int n) {
    final lastMessages = _messages.take(n).toList().reversed;
    return lastMessages
        .map((msg) => "${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}")
        .join('\n');
  }

  Future<void> _pickAndReadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'md',
          'json',
          'yaml',
          'dart',
          'js',
          'py',
          'html',
          'css'
        ],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Split content into chunks (simple approach - split by paragraphs)
        final chunks = content.split(RegExp(r'\n\s*\n'));

        // Add chunks to vector store
        for (var i = 0; i < chunks.length; i++) {
          if (chunks[i].trim().isNotEmpty) {
            _vectorStore.addDocument(
              chunks[i].trim(),
              '${result.files.single.name}:chunk_$i',
            );
          }
        }

        setState(() {
          _currentFileContent = content;
          _currentFileName = result.files.single.name;
        });

        // Add a system message indicating file was loaded
        final systemMessage = {
          'text': 'File loaded: $_currentFileName',
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        };
        ConversationManager.addMessage(systemMessage);
      }
    } catch (e) {
      print('Error picking/reading file: $e');
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
          roleMatcher: _roleMatcher, // Add this line
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
            _buildRoleOptions(), // Moved here to overlay on top
            _buildRoleDetails(), // Add this line before the closing bracket of children
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
    return GestureDetector(
      onTap: message.isSuggestion
          ? () => _handleSubmitted(_roleMatcher.generateRoleMatchPrompt())
          : null,
      child: Container(
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
                gradient: message.isSuggestion
                    ? const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 100, 149, 237),
                          Color.fromARGB(120, 100, 149, 237),
                        ],
                      )
                    : message.isUser
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
      ),
    );
  }

  Widget _buildRoleConfirmation() {
    if (!_showRoleConfirmation || _suggestedRole == null)
      return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Would you like to accept this role?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _handleRoleConfirmation(true),
                child: Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
              ElevatedButton(
                onPressed: () => _handleRoleConfirmation(false),
                child: Text('Decline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOptions() {
    if (!_showRoleOptions || _detectedRoles.isEmpty) {
      return SizedBox.shrink();
    }

    return Positioned(
      // Move it to the top of the screen below app bar
      top: kToolbarHeight - 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          // Reduce overall container height
          constraints: BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism,
                      color: Color.fromARGB(255, 26, 126, 51),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Available Roles',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color.fromARGB(255, 26, 126, 51),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _showRoleOptions = false;
                          _detectedRoles = [];
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Compact role list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  itemCount: _detectedRoles.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () => _handleRoleSelection(index),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 26, 126, 51)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: GoogleFonts.poppins(
                                    color: Color.fromARGB(255, 26, 126, 51),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _detectedRoles[index]
                                    .replaceAll(RegExp(r'^#\d+:\s*'), ''),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDetails() {
    if (!_showRoleDetails ||
        _selectedRole == null ||
        _selectedRoleDetails == null) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          color: Color.fromARGB(255, 26, 126, 51),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Role Details',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color.fromARGB(255, 26, 126, 51),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 20, color: Colors.grey[600]),
                        onPressed: () => setState(() {
                          _showRoleDetails = false;
                          _selectedRole = null;
                          _selectedRoleDetails = null;
                        }),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRoleDetails!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _handleRoleConfirmation(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Decline',
                                style: TextStyle(color: Colors.black87)),
                          ),
                          ElevatedButton(
                            onPressed: () => _handleRoleConfirmation(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 26, 126, 51),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Accept Role',
                                style: TextStyle(
                                    color: const Color.fromARGB(
                                        221, 255, 255, 255))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _pickAndReadFile,
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
  final bool isSuggestion;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSuggestion = false,
  });
}
