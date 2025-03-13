import 'package:flutter/material.dart';
import 'package:frontend/screens/Chatbot_screen/voice_chat_screen.dart';
import 'package:frontend/screens/colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _connectWebSocket();
    _setupAudioPlayerListeners();
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
    channel = WebSocketChannel.connect(
      Uri.parse('ws://10.222.202.216:8000/ws'),
    );
    
    // Create a broadcast stream
    broadcastStream = channel.stream.asBroadcastStream();

    broadcastStream.listen((message) async {
      if (_isProcessing) return; // Prevent multiple processing
      _isProcessing = true;

      final data = json.decode(message);
      if (data['type'] == 'response') {
        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              text: data['text'],
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else if (data['type'] == 'audio') {
        _stopListening(); // Stop listening while playing audio
        try {
          await audioPlayer.setUrl(data['audio_url']);
          await audioPlayer.play();
        } catch (e) {
          print('Error playing audio: $e');
          _startListening(); // Start listening if audio fails
        }
      }
      _isProcessing = false;
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
              setState(() {
                _messages.insert(
                  0,
                  ChatMessage(
                    text: recognizedText,
                    isUser: true,
                    timestamp: DateTime.now(),
                  ),
                );
              });

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

  void _handleSubmitted(String text) async {
    _messageController.clear();
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.insert(
          0,
          ChatMessage(
            text: text,
            isUser: true,
            timestamp: DateTime.now(),
          ));
    });

    try {
      final Uri url = Uri.parse(
          'http://10.156.140.216:8000/chat'); // Correct server address
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': '12345', // Add user_id
          'query': text
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _messages.insert(
              0,
              ChatMessage(
                text: data['response'],
                isUser: false,
                timestamp: DateTime.now(),
              ));
        });
      } else {
        setState(() {
          _messages.insert(
              0,
              ChatMessage(
                text: 'Error: ${response.statusCode}',
                isUser: false,
                timestamp: DateTime.now(),
              ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.insert(
            0,
            ChatMessage(
              text: 'Connection error: $e',
              isUser: false,
              timestamp: DateTime.now(),
            ));
      });
    }
  }

  void _openVoiceChatScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceChatScreen(
          channel: channel,
          messageStream: broadcastStream, // Pass the broadcast stream
          onConversationComplete: (conversation) {
            for (final message in conversation) {
              setState(() {
                _messages.insert(
                  0,
                  ChatMessage(
                    text: message['text'],
                    isUser: message['isUser'],
                    timestamp: DateTime.parse(message['timestamp']),
                  ),
                );
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? AppColors.mainGradient
                  : const LinearGradient(
                      colors: [Colors.grey, Colors.blueGrey],
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
          if (message.isUser) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.person, color: Colors.white),
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
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey[100],
                filled: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_messageController.text),
            color: Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    channel.sink.close();
    audioPlayer.dispose();
    super.dispose();
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