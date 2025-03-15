import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

class ReelsScreen extends StatefulWidget {
  @override
  _ReelsScreenState createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  List<String> videos = [
    'https://drive.google.com/uc?export=download&id=1Vdg54Nscas6XXvn7KAspRE_7S8N7iQim',
    'https://drive.google.com/uc?export=download&id=13v0mmQq7F57cKDPP-XvpHWBiwXTvDrGS',
    'https://drive.google.com/uc?export=download&id=1SM080AtS077e2_jjFL6O98yls1GPfdYG',
    'https://drive.google.com/uc?export=download&id=1poxg9BsDzyVXCRHl4ITN47bPmtm8Nq0i',
    'https://drive.google.com/uc?export=download&id=19pCv8mRrinuzx3_nASZIHRQEUqgDFNyA',
    'https://drive.google.com/uc?export=download&id=1wUPZVisMOy-gzcEnoQlhFFteMUifIQ9V',
  ];

  int _currentIndex = 0;
  VideoPlayerController? _currentController;
  bool _isLoading = true;
  String? _error;

  Map<int, bool> _isLiked = {};
  List<Map<String, dynamic>> _reelsData = [
    {
      'username': '@RamadanSpirit',
      'description': 'Ramadan Month Special Coverage',
      'likes': '15.2K',
      'comments': '2.1K',
      'userAvatar': 'https://picsum.photos/200/300',
      'title': 'Ramadan Month'
    },
    {
      'username': '@OmanCulture',
      'description': 'Iftar Traditions in Oman',
      'likes': '8.7K',
      'comments': '1.3K',
      'userAvatar': 'https://picsum.photos/200/301',
      'title': 'Iftar Oman'
    },
    {
      'username': '@MakkahNews',
      'description': 'Blood Donation Campaign in Makkah',
      'likes': '12.4K',
      'comments': '1.8K',
      'userAvatar': 'https://picsum.photos/200/302',
      'title': 'Blood Donation in Makkah'
    },
    {
      'username': '@EconomyNews',
      'description': 'Ramadan Economic Impact',
      'likes': '7.9K',
      'comments': '956',
      'userAvatar': 'https://picsum.photos/200/303',
      'title': 'Ramadan and Dollar'
    },
    {
      'username': '@MakkahLive',
      'description': 'إفطار الصائمين في الحرم المكي ٩ رمضان ١٤٤٤ هجري',
      'likes': '25.6K',
      'comments': '3.2K',
      'userAvatar': 'https://picsum.photos/200/304',
      'title': 'إفطار الصائمين في الحرم المكي'
    },
    {
      'username': '@HealthAwareness',
      'description': 'هل للتبرع بالدم فوائد صحية؟',
      'likes': '11.3K',
      'comments': '1.5K',
      'userAvatar': 'https://picsum.photos/200/305',
      'title': 'فوائد التبرع بالدم'
    },
  ];

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
    _preloadVideos(_currentIndex);
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
    if (currentIndex < videos.length - 1) {
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
      final cachedFile = await _cacheVideo(videos[index], index);
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
    }.where((index) => index >= 0 && index < videos.length);

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
        final cachedFile = await _cacheVideo(videos[index], index);
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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
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
                        _buildCircleButton(
                          icon: _isLiked[index] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: _reelsData[index]['likes'],
                          color:
                              _isLiked[index] == true ? Colors.red : whiteColor,
                          onTap: () => setState(() =>
                              _isLiked[index] = !(_isLiked[index] ?? false)),
                        ),
                        SizedBox(height: 20),
                        _buildCircleButton(
                          icon: Icons.comment,
                          label: _reelsData[index]['comments'],
                          onTap: () {/* Show comments */},
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
                              backgroundImage:
                                  NetworkImage(_reelsData[index]['userAvatar']),
                            ),
                            SizedBox(width: 12),
                            Text(
                              _reelsData[index]['username'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 12),
                            TextButton(
                              onPressed: () {/* Follow functionality */},
                              child: Text('Follow'),
                              style: TextButton.styleFrom(
                                foregroundColor: whiteColor,
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _reelsData[index]['description'],
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
