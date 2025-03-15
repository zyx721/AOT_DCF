import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReelsScreen extends StatefulWidget {
  @override
  _ReelsScreenState createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  List<DocumentSnapshot> _videoDocuments = [];
  bool _isLoadingVideos = true;
  String? _loadingError;

  int _currentIndex = 0;
  VideoPlayerController? _currentController;
  bool _isLoading = true;
  String? _error;

  final Color primaryColor = const Color.fromARGB(255, 26, 126, 51);
  final Color primaryLightColor = const Color.fromARGB(120, 26, 126, 51);
  final Color primaryVeryLightColor = const Color.fromARGB(65, 26, 126, 51);
  final Color whiteColor = const Color.fromRGBO(255, 255, 255, 1);

  Map<int, VideoPlayerController> _controllerCache = {};
  Map<int, Future<void>> _initializingFutures = {};
  final _maxCacheSize = 3; // Keep 3 videos in memory

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() => _isLoadingVideos = true);
      
      final videoSnapshots = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _videoDocuments = videoSnapshots.docs;
        _isLoadingVideos = false;
      });

      if (_videoDocuments.isNotEmpty) {
        _preloadVideos(_currentIndex);
      }
    } catch (e) {
      setState(() {
        _loadingError = 'Error loading videos: $e';
        _isLoadingVideos = false;
      });
    }
  }

  Future<void> _toggleLike(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef = FirebaseFirestore.instance.collection('videos').doc(videoId);
    final userLikesRef = videoRef.collection('likes').doc(user.uid);

    final userLikeDoc = await userLikesRef.get();
    
    if (userLikeDoc.exists) {
      await userLikesRef.delete();
      await videoRef.update({
        'likes': FieldValue.increment(-1),
      });
    } else {
      await userLikesRef.set({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await videoRef.update({
        'likes': FieldValue.increment(1),
      });
    }
  }

  Future<void> _togglePray(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef = FirebaseFirestore.instance.collection('videos').doc(videoId);
    final userPraysRef = videoRef.collection('prays').doc(user.uid);

    final userPrayDoc = await userPraysRef.get();
    
    if (userPrayDoc.exists) {
      await userPraysRef.delete();
      await videoRef.update({
        'prays': FieldValue.increment(-1),
      });
    } else {
      await userPraysRef.set({
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await videoRef.update({
        'prays': FieldValue.increment(1),
      });
    }
  }

  Stream<bool> _isLikedStream(String videoId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<bool> _isPrayedStream(String videoId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('prays')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<File> _cacheVideo(String url, int index) async {
    final fileStream = DefaultCacheManager().getFileStream(
      url,
      withProgress: true,
    );
    
    File? cachedFile;
    await for (final event in fileStream) {
      if (event is FileInfo) {
        cachedFile = event.file;
        break;
      }
    }
    return cachedFile!;
  }

  Future<void> _preloadVideos(int currentIndex) async {
    // Load current video
    await _loadAndInitializeVideo(currentIndex);
    
    // Preload next video if available
    if (currentIndex < _videoDocuments.length - 1) {
      _precacheVideo(currentIndex + 1);
    }
    
    // Preload previous video if available
    if (currentIndex > 0) {
      _precacheVideo(currentIndex - 1);
    }
    
    // Clean up old cached videos
    _cleanupCache(currentIndex);
  }

  Future<void> _precacheVideo(int index) async {
    if (_controllerCache.containsKey(index)) return;
    
    try {
      final videoData = _videoDocuments[index].data() as Map<String, dynamic>;
      final cachedFile = await _cacheVideo(videoData['videoUrl'], index);
      final controller = VideoPlayerController.file(cachedFile)
        ..setLooping(true);
      
      _initializingFutures[index] = controller.initialize();
      _controllerCache[index] = controller;
      
      // Start buffering but don't play
      await controller.initialize();
    } catch (e) {
      print('Error precaching video $index: $e');
    }
  }

  void _cleanupCache(int currentIndex) {
    final validIndices = {
      currentIndex - 1,
      currentIndex,
      currentIndex + 1,
    }.where((index) => index >= 0 && index < _videoDocuments.length);

    _controllerCache.keys.toList().forEach((index) {
      if (!validIndices.contains(index)) {
        _controllerCache[index]?.dispose();
        _controllerCache.remove(index);
        _initializingFutures.remove(index);
      }
    });
  }

  Future<void> _loadAndInitializeVideo(int index) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_currentController != null) {
        await _currentController!.pause();
      }

      if (_controllerCache.containsKey(index)) {
        _currentController = _controllerCache[index];
        await _initializingFutures[index];
      } else {
        final videoData = _videoDocuments[index].data() as Map<String, dynamic>;
        final cachedFile = await _cacheVideo(videoData['videoUrl'], index);
        _currentController = VideoPlayerController.file(cachedFile)
          ..setLooping(true);
        await _currentController!.initialize();
        _controllerCache[index] = _currentController!;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _currentController?.play();
      }
    } catch (e) {
      print("Error loading video: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error loading video. Please try again.";
        });
      }
    }
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    _preloadVideos(index);
  }

  @override
  void dispose() {
    _controllerCache.values.forEach((controller) => controller.dispose());
    _controllerCache.clear();
    _initializingFutures.clear();
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoadingVideos
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _loadingError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_loadingError!, style: TextStyle(color: Colors.white)),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: _videoDocuments.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final videoData = _videoDocuments[index].data() as Map<String, dynamic>;
                        final videoId = _videoDocuments[index].id;

                        if (index != _currentIndex) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        if (_error != null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.white, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => _loadAndInitializeVideo(_currentIndex),
                                  child: Text('Retry'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_isLoading ||
                            _currentController == null ||
                            !_currentController!.value.isInitialized) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_currentController!.value.isPlaying) {
                                  _currentController!.pause();
                                } else {
                                  _currentController!.play();
                                }
                                setState(() {});
                              },
                              child: Container(
                                color: Colors.black,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _currentController!.value.size.width,
                                    height: _currentController!.value.size.height,
                                    child: VideoPlayer(_currentController!),
                                  ),
                                ),
                              ),
                            ),
                            // Right side buttons
                            Positioned(
                              right: 16,
                              bottom: 100,
                              child: Column(
                                children: [
                                  StreamBuilder<bool>(
                                    stream: _isLikedStream(videoId),
                                    builder: (context, snapshot) {
                                      final isLiked = snapshot.data ?? false;
                                      return _buildCircleButton(
                                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                                        label: '${videoData['likes'] ?? 0}',
                                        color: isLiked ? Colors.red : whiteColor,
                                        onTap: () => _toggleLike(videoId),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  StreamBuilder<bool>(
                                    stream: _isPrayedStream(videoId),
                                    builder: (context, snapshot) {
                                      final isPrayed = snapshot.data ?? false;
                                      return _buildCircleButton(
                                        icon: isPrayed ? Icons.emoji_events : Icons.emoji_events_outlined,
                                        label: '${videoData['prays'] ?? 0}',
                                        color: isPrayed ? Colors.amber : whiteColor,
                                        onTap: () => _togglePray(videoId),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  _buildCircleButton(
                                    icon: Icons.share,
                                    label: 'Share',
                                    onTap: () {/* Share functionality */},
                                  ),
                                ],
                              ),
                            ),
                            // Bottom user info and description
                            Positioned(
                              left: 16,
                              right: 72,
                              bottom: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(videoData['creatorAvatar'] ?? 'default_avatar_url'),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        videoData['creatorName'] ?? 'Anonymous',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    videoData['title'] ?? '',
                                    style: TextStyle(color: whiteColor),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: whiteColor),
                              onPressed: () => Navigator.pop(context),
                            ),
                            if (_error != null)
                              IconButton(
                                icon: Icon(Icons.refresh, color: whiteColor),
                                onPressed: () => _loadAndInitializeVideo(_currentIndex),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Icon(icon, color: color, size: 30),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: whiteColor),
        ),
      ],
    );
  }
}
