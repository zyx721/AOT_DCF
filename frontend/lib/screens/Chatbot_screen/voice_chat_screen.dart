import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:frontend/services/conversation_manager.dart';
import 'package:frontend/services/role_matcher.dart';

class VoiceChatScreen extends StatefulWidget {
  final WebSocketChannel channel;
  final Stream messageStream;
  final Function(List<Map<String, dynamic>>) onConversationComplete;
  final List<Map<String, dynamic>> initialConversation; // Add this line
  final RoleMatcher roleMatcher; // Add this line

  const VoiceChatScreen({
    Key? key,
    required this.channel,
    required this.messageStream,
    required this.onConversationComplete,
    required this.roleMatcher, // Add this parameter
    this.initialConversation = const [], // Add this parameter
  }) : super(key: key);

  @override
  _VoiceChatScreenState createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  late final genai.GenerativeModel model;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  bool _isGeneratingResponse = false;
  bool _canInterrupt = true; // Add this property
  List<Map<String, dynamic>> _conversation = [];
  late AnimationController _animationController;
  double _soundLevel = 0.0;

  // Add these properties
  List<String> _detectedRoles = [];
  bool _showRoleOptions = false;
  bool _showRoleDetails = false;
  String? _selectedRole;
  String? _selectedRoleDetails;

  @override
  void initState() {
    super.initState();
    // Load the complete conversation history from ConversationManager
    _conversation = List.from(ConversationManager.history);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeSpeech();
      await _initializeTts();
      _initializeGemini();
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      Future.delayed(Duration(milliseconds: 500), _startListening);
      _setupMessageListener();
      // Set up history listener
      ConversationManager.historyStream.listen((history) {
        if (mounted) {
          setState(() {
            _conversation = List.from(history);
          });
        }
      });
    });
  }

  void _loadConversationHistory() {
    _conversation = List.from(ConversationManager.history);
  }

  void _initializeGemini() {
    final apiKey = "AIzaSyDjsiA8U72-Zqt3xD4cEUHW8V5NooY6Y2A";
    // Removed the call to the non-existent init method
    model = genai.GenerativeModel(
        model: 'models/gemini-2.0-flash',
        apiKey: 'AIzaSyDjsiA8U72-Zqt3xD4cEUHW8V5NooY6Y2A');
  }

  Future<void> _initializeTts() async {
    try {
      await flutterTts.awaitSpeakCompletion(true);

      if (Platform.isAndroid) {
        // Get and set the best available voice
        var engines = await flutterTts.getEngines;
        if (engines.isNotEmpty) {
          await flutterTts.setEngine(engines.first);
        }

        await flutterTts.setLanguage("en-US");
        await flutterTts.setPitch(1.0);
        await flutterTts.setSpeechRate(0.5);
        await flutterTts.setVolume(1.0);

        // Try different voice options
        try {
          await flutterTts
              .setVoice({"name": "en-us-x-tpf-local", "locale": "en-US"});
        } catch (e) {
          _logMessage('Failed to set specific voice, using default',
              isError: true);
        }
      } else if (Platform.isIOS) {
        await flutterTts.setSharedInstance(true);
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }

      // Set up completion handler to automatically start listening
      flutterTts.setCompletionHandler(() {
        _logMessage('TTS Completed Speaking');
        setState(() {
          _isPlaying = false;
          _isProcessing = false;
        });
        // Start listening after a short pause
        Future.delayed(Duration(milliseconds: 800), () {
          if (!_isGeneratingResponse && !_isProcessing && !_isPlaying) {
            _startListening();
          }
        });
      });

      // Setup TTS handlers for turn management
      flutterTts.setStartHandler(() {
        _logMessage('TTS Started Speaking');
        setState(() {
          _isPlaying = true;
          _isProcessing = false;
          _isListening = false; // Ensure we're not listening while speaking
        });
      });

      flutterTts.setErrorHandler((message) {
        _logMessage('TTS Error: $message', isError: true);
        setState(() {
          _isPlaying = false;
          _isProcessing = false;
        });
        // Try to recover by starting listening
        Future.delayed(Duration(milliseconds: 500), _startListening);
      });

      _logMessage('TTS initialized successfully');
    } catch (e) {
      _logMessage('TTS Initialization error: $e', isError: true);
    }
  }

  void _initializeSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => print('Speech error: $error'),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _logMessage(String message, {bool isError = false}) {
    final timestamp = DateTime.now().toString();
    print('[$timestamp] ${isError ? "ERROR: " : ""}$message');
  }

  void _saveConversationToHistory(Map<String, dynamic> message) {
    ConversationManager.addMessage(message);
    widget.onConversationComplete(ConversationManager.history);
  }

  List<String> _detectRoles(String text) {
    final rolePattern =
        RegExp(r'(?:^|\n)#(\d+)[:\s-]+([^\n.]+)', multiLine: true);
    final matches = rolePattern.allMatches(text);
    final roles = <String>[];

    for (var match in matches) {
      final roleNumber = match.group(1);
      final roleTitle = match.group(2)?.trim();
      if (roleTitle != null) {
        final role = '#$roleNumber: $roleTitle';
        roles.add(role);
      }
    }
    return roles.take(3).toList();
  }

  Future<void> _handleSpeechResult(String text) async {
    if (text.isEmpty) return;

    _logMessage('Received speech input: $text');

    setState(() {
      _isGeneratingResponse = true;
      _isProcessing = true;
    });

    final userMessage = {
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _saveConversationToHistory(userMessage);

    try {
      _logMessage('Generating response for: $text');

      // Use RoleMatcher to generate contextual prompt
      final contextualPrompt = widget.roleMatcher.generateRoleMatchPrompt(text);
      _logMessage('Using contextual prompt: $contextualPrompt');

      final content = [
        genai.Content.text(contextualPrompt +
            "\nPlease format any role suggestions with #1, #2, etc.")
      ];
      final response = await model.generateContent(content);
      final responseText =
          response.text ?? "Sorry, I couldn't generate a response";
      _logMessage('Received response: $responseText');

      final detectedRoles = _detectRoles(responseText);
      if (detectedRoles.isNotEmpty) {
        setState(() {
          _detectedRoles = detectedRoles;
          _showRoleOptions = true;
        });
      }

      final botMessage = {
        'text': responseText,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _saveConversationToHistory(botMessage);

      setState(() => _isGeneratingResponse = false);

      // Use the new speak method
      await _speakText(responseText);
    } catch (e, stackTrace) {
      _logMessage('Error in response generation: $e\nStack trace: $stackTrace',
          isError: true);
      setState(() {
        _isGeneratingResponse = false;
        _isProcessing = false;
      });

      // Add error message to conversation
      final errorMessage = {
        'text': 'Sorry, I encountered an error. Please try again.',
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _saveConversationToHistory(errorMessage);

      Future.delayed(Duration(seconds: 1), _startListening);
    }
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;

    try {
      _logMessage('Preparing to speak: $text');

      setState(() {
        _isPlaying = true;
        _isProcessing = false;
        _isListening = false;
      });

      // Wait for any previous speech to finish
      await flutterTts.stop();
      await Future.delayed(Duration(milliseconds: 300));

      // Configure TTS for complete utterance
      flutterTts.setCompletionHandler(() {
        _logMessage('TTS Completed Speaking');
        setState(() {
          _isPlaying = false;
          _isProcessing = false;
        });
        Future.delayed(Duration(milliseconds: 500), () {
          if (!_isGeneratingResponse && !_isProcessing) {
            _startListening();
          }
        });
      });

      // Prepare the text
      String cleanedText = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          // Mark sentence boundaries

          .split('|') // Split into sentences
          .where((s) => s.trim().isNotEmpty) // Remove empty sentences
          .join('. '); // Rejoin with proper spacing

      _logMessage('Speaking text: $cleanedText');

      // Speak the entire text at once
      var result = await flutterTts.speak(cleanedText);

      if (result != 1) {
        _logMessage('TTS speak failed', isError: true);
        setState(() {
          _isPlaying = false;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _logMessage('TTS speak error: $e', isError: true);
      setState(() {
        _isPlaying = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleManualInterruption() async {
    if (_isPlaying) {
      _logMessage('Manual interruption by user');
      await flutterTts.stop();
      setState(() {
        _isPlaying = false;
        _isProcessing = false;
      });
      _startListening();
    }
  }

  void _startListening() {
    // Stop any ongoing speech first
    if (_isPlaying) {
      flutterTts.stop();
      setState(() => _isPlaying = false);
    }

    if (_isListening || _isProcessing || _isGeneratingResponse) {
      _logMessage('Cannot start listening - another operation is in progress');
      return;
    }

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final recognizedText = result.recognizedWords;
          _logMessage('Final speech result: $recognizedText');
          setState(() {
            _isListening = false;
            _isProcessing = true;
          });
          _handleSpeechResult(recognizedText);
        }
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 3),
      cancelOnError: true,
      partialResults: true, // Enable partial results to detect speech earlier
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level.clamp(0.0, 10.0);
        });
      },
    );

    setState(() => _isListening = true);
    _logMessage('Started listening');
  }

  void _setupMessageListener() {
    widget.messageStream.listen((message) {
      _logMessage('Received WebSocket message: $message');
      final data = json.decode(message);
      if (data['type'] == 'response' || data['type'] == 'text') {
        final newMessage = {
          'text': data['text'],
          'isUser': data['type'] == 'text',
          'timestamp': DateTime.now().toIso8601String(),
        };
        setState(() {
          _saveConversationToHistory(newMessage);
        });
      }
    });
  }

  Widget _buildVoiceAnimation() {
    double baseSize = 200.0;
    double circleSize = baseSize + (_soundLevel * 10);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background pulse animation
        if (_isListening)
          AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: _soundLevel * 10,
                  spreadRadius: _soundLevel * 5,
                ),
              ],
            ),
          ),
        // Main animation
        AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _isListening
              ? Lottie.asset(
                  'assets/animation/voice_wave.json',
                  width: baseSize,
                  height: baseSize,
                  key: ValueKey('listening'),
                )
              : _isPlaying
                  ? Lottie.asset(
                      'assets/animation/voice_wave2.json',
                      width: baseSize,
                      height: baseSize,
                      key: ValueKey('playing'),
                    )
                  : Lottie.asset(
                      'assets/animation/processing.json',
                      width: baseSize,
                      height: baseSize,
                      key: ValueKey('processing'),
                    ),
        ),
      ],
    );
  }

  void _handleRoleSelection(int index) {
    if (index < _detectedRoles.length) {
      final selectedRole = _detectedRoles[index];
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
        _showRoleOptions = false;
      });
    }
  }

  void _handleRoleConfirmation(bool accepted) {
    setState(() {
      _showRoleDetails = false;
      if (accepted && _selectedRole != null) {
        _saveConversationToHistory({
          'text':
              'You have accepted the role: $_selectedRole\n\nRole Details:\n$_selectedRoleDetails\n\nOur team will contact you soon with further details.',
          'isUser': false,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      _selectedRole = null;
      _selectedRoleDetails = null;
    });
  }

  Widget _buildRoleOptions() {
    if (!_showRoleOptions || _detectedRoles.isEmpty) {
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.volunteer_activism,
                          color: Color.fromARGB(255, 26, 126, 51),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Recommended Roles',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color.fromARGB(255, 26, 126, 51),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey[600]),
                        onPressed: () {
                          setState(() {
                            _showRoleOptions = false;
                            _detectedRoles = [];
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: _detectedRoles.length,
                    itemBuilder: (context, index) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleRoleSelection(index),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 26, 126, 51).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${index + 1}',
                                      style: GoogleFonts.poppins(
                                        color: Color.fromARGB(255, 26, 126, 51),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _detectedRoles[index].replaceAll(RegExp(r'^#\d+:\s*'), ''),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Tap to select this role',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            widget.onConversationComplete(_conversation);
            Navigator.pop(context);
          },
        ),
      ),
      body: GestureDetector(
        onTapDown: (_) => _handleManualInterruption(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Background Animation with zoom effect
            Transform.scale(
              scale: 1.2, // Slightly zoom in the animation
              child: Positioned.fill(
                top: -50, // Extend beyond the top
                bottom: -50, // Extend beyond the bottom
                left: -50, // Extend beyond the left
                right: -50, // Extend beyond the right
                child: Lottie.asset(
                  'assets/animation/Animation - 1739443672393.json',
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width * 1.2,
                  height: MediaQuery.of(context).size.height * 1.2,
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 100),
                  _buildVoiceAnimation(),
                  SizedBox(height: 40),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Add these widgets to the stack
            if (_showRoleOptions) _buildRoleOptions(),
            if (_showRoleDetails) _buildRoleDetails(),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_isListening) return "Listening...";
    if (_isGeneratingResponse) return "Thinking...";
    if (_isProcessing) return "Processing...";
    if (_isPlaying) return "Speaking...";
    return "Tap to speak";
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

  @override
  void dispose() {
    // Remove extra history update since ConversationManager handles it
    flutterTts.stop();
    _logMessage('Stopping TTS and cleaning up');
    _logMessage('Conversation history:');
    for (var msg in _conversation) {
      _logMessage('${msg['isUser'] ? "User" : "Bot"}: ${msg['text']}');
    }
    try {
      flutterTts.stop();
    } catch (e) {
      print('TTS dispose error: $e');
    }
    _animationController.dispose();
    _speech.stop();
    widget.onConversationComplete(_conversation);
    super.dispose();
  }
}
