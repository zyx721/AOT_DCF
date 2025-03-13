import 'dart:io';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class VoiceChatScreen extends StatefulWidget {
  final WebSocketChannel channel;
  final Stream messageStream;
  final Function(List<Map<String, dynamic>>) onConversationComplete;

  const VoiceChatScreen({
    Key? key,
    required this.channel,
    required this.messageStream,
    required this.onConversationComplete,
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
  bool _canInterrupt = true;  // Add this property
  List<Map<String, dynamic>> _conversation = [];
  late AnimationController _animationController;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
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
    });
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
        
        // Get available voices and set a natural sounding voice
        var voices = await flutterTts.getVoices;
        _logMessage('Available voices: $voices');
        
        // Try to set a high-quality voice
        await flutterTts.setVoice({
          "name": "en-us-x-iom-local",  // High-quality US English voice
          "locale": "en-US"
        });

        // Fine-tune the voice parameters
        await flutterTts.setPitch(1.0);     // Natural pitch
        await flutterTts.setSpeechRate(0.5); // Slower, more natural pace
        await flutterTts.setVolume(1.0);    // Full volume
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
    _conversation.add(message);
    // Print conversation for debugging
    _logMessage(
        '${message['isUser'] ? "User" : "Bot"}: ${message['text']}\nTimestamp: ${message['timestamp']}');
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
      // Create proper content for Gemini
      final content = [genai.Content.text(text)];
      final response = await model.generateContent(content);
      final responseText =
          response.text ?? "Sorry, I couldn't generate a response";
      _logMessage('Received response: $responseText');

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
        _canInterrupt = true;  // Allow interruption when speaking
      });

      // Clean up the text for better speech
      String cleanedText = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Split into natural phrases
      List<String> phrases = cleanedText.split(RegExp(r'[,;.!?]+\s*'));
      
      for (String phrase in phrases) {
        if (phrase.trim().isEmpty) continue;

        // Check if we've been interrupted
        if (!_isPlaying) {
          _logMessage('Speech interrupted');
          break;
        }

        _logMessage('Speaking phrase: $phrase');
        var result = await flutterTts.speak(phrase.trim());

        if (result != 1) {
          _logMessage('TTS speak failed for phrase: $phrase', isError: true);
          continue;
        }

        // Wait for completion or interruption
        await Future.delayed(Duration(milliseconds: 500));
      }
    } catch (e) {
      _logMessage('TTS speak error: $e', isError: true);
      setState(() {
        _isPlaying = false;
        _isProcessing = false;
      });
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
      partialResults: true,  // Enable partial results to detect speech earlier
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level.clamp(0.0, 10.0);
        });
        // Optionally interrupt on sound detection
        if (_isPlaying && level > 2.0) {  // Adjust threshold as needed
          _handleInterruption();
        }
      },
    );
    
    setState(() => _isListening = true);
    _logMessage('Started listening');
  }

  Future<void> _handleInterruption() async {
    if (_isPlaying) {
      _logMessage('User interrupted the bot');
      await flutterTts.stop();
      setState(() {
        _isPlaying = false;
        _isProcessing = false;
      });
      _startListening();
    }
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
        onTapDown: (_) => _handleInterruption(),
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

  @override
  void dispose() {
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
