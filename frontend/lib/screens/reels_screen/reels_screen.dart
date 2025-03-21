import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'comments_sheet.dart';
import '../view_profile_screen/view_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:frontend/services/notification.dart';


class ReelsScreen extends StatefulWidget {
  final int initialIndex;
  final List<DocumentSnapshot>? videos;
  final String? searchQuery;

  const ReelsScreen({
    Key? key,
    this.initialIndex = 0,
    this.videos,
    this.searchQuery,
  }) : super(key: key);

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
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    if (widget.videos != null) {
      setState(() {
        _videoDocuments = widget.videos!;
        _isLoadingVideos = false;
      });
      // Initialize the first video immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAndInitializeVideo(widget.initialIndex);
      });
    } else {
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    try {
      setState(() => _isLoadingVideos = true);

      Query query = FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true);

      // Apply search filter if search query exists
      if (widget.searchQuery?.isNotEmpty ?? false) {
        query = query.where('searchKeywords',
            arrayContains: widget.searchQuery!.toLowerCase());
      }

      final videoSnapshots = await query.get();

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

    final videoRef =
        FirebaseFirestore.instance.collection('videos').doc(videoId);
    final likesCollection = videoRef.collection('likes');
    final userLikeDoc = likesCollection.doc(user.uid);

    try {
      final docSnapshot = await userLikeDoc.get();
      final batch = FirebaseFirestore.instance.batch();
      final videoData = _videoDocuments[_currentIndex].data() as Map<String, dynamic>;

      if (!docSnapshot.exists) {
        // Like: Create notification when liking
        await PushNotificationService.createNotification(
          receiverId: videoData['creatorId'],
          senderId: user.uid,
          type: 'LIKE',
          content: '${user.displayName ?? 'Someone'} liked your video',
          targetId: videoId,
          additionalData: {'videoTitle': videoData['title']},
        );
      }

      if (docSnapshot.exists) {
        // Unlike: Remove user from likes collection and decrease counter
        batch.delete(userLikeDoc);
        batch.update(videoRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        // Like: Add user to likes collection and increase counter
        batch.set(userLikeDoc, {
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'userName': user.displayName,
        });
        batch.update(videoRef, {'likeCount': FieldValue.increment(1)});
      }

      await batch.commit();
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like. Please try again.')));
    }
  }

  Future<void> _togglePray(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef =
        FirebaseFirestore.instance.collection('videos').doc(videoId);
    final praysCollection = videoRef.collection('prays');
    final userPrayDoc = praysCollection.doc(user.uid);

    try {
      final docSnapshot = await userPrayDoc.get();
      final batch = FirebaseFirestore.instance.batch();

      if (docSnapshot.exists) {
        // Remove pray: Remove user from prays collection and decrease counter
        batch.delete(userPrayDoc);
        batch.update(videoRef, {'prayCount': FieldValue.increment(-1)});
      } else {
        // Add pray: Add user to prays collection and increase counter
        batch.set(userPrayDoc, {
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'userName': user.displayName,
        });
        batch.update(videoRef, {'prayCount': FieldValue.increment(1)});
      }

      await batch.commit();
    } catch (e) {
      print('Error toggling pray: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating pray. Please try again.')));
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

      final videoData = _videoDocuments[index].data() as Map<String, dynamic>;
      final cachedFile = await _cacheVideo(videoData['videoUrl'], index);

      if (_controllerCache.containsKey(index)) {
        _currentController = _controllerCache[index];
      } else {
        _currentController = VideoPlayerController.file(cachedFile)
          ..setLooping(true);
        await _currentController!.initialize();
        _controllerCache[index] = _currentController!;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Ensure video starts playing
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
    setState(() {
      _currentIndex = index;
    });
    _loadAndInitializeVideo(index);
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

  void _showComments(String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(videoId: videoId),
    );
  }

  Future<void> _toggleFollow(String creatorId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final otherUserRef =
        FirebaseFirestore.instance.collection('users').doc(creatorId);

    try {
      final isFollowing = await _isFollowingUser(creatorId);   
      if (!isFollowing) {
        // Create notification when following
        await PushNotificationService.createNotification(
          receiverId: creatorId,
          senderId: currentUser.uid,
          type: 'FOLLOW',
          content: '${currentUser.displayName ?? 'Someone'} started following you',
        );
      }


      if (isFollowing) {
        await userRef.update({
          'following': FieldValue.arrayRemove([creatorId])
        });
        await otherUserRef.update({
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        await userRef.update({
          'following': FieldValue.arrayUnion([creatorId])
        });
        await otherUserRef.update({
          'followers': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating follow status. Please try again.')));
    }
  }

  Future<bool> _isFollowingUser(String creatorId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final following = userDoc.data()?['following'] ?? [];
    return following.contains(creatorId);
  }

  Future<void> _shareVideo(Map<String, dynamic> videoData) async {
    final String videoTitle = videoData['title'] ?? 'Check out this video';
    final String videoUrl = videoData['videoUrl'] ?? '';
    final String creatorName = videoData['creatorName'] ?? 'Anonymous';

    final String shareText = '''
$videoTitle

By: $creatorName

Watch here: $videoUrl
''';

    try {
      await Share.share(shareText, subject: videoTitle);
    } catch (e) {
      print('Error sharing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing video. Please try again.')));
    }
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
                      Text(_loadingError!,
                          style: TextStyle(color: Colors.white)),
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
                        final videoData = _videoDocuments[index].data()
                            as Map<String, dynamic>;
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
                                Icon(Icons.error_outline,
                                    color: Colors.white, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: () =>
                                      _loadAndInitializeVideo(_currentIndex),
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
                                    height:
                                        _currentController!.value.size.height,
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
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('videos')
                                        .doc(videoId)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData)
                                        return _buildCircleButton(
                                          icon: Icons.favorite_border,
                                          label: '0',
                                          color: whiteColor,
                                          onTap: () => _toggleLike(videoId),
                                        );

                                      final videoData = snapshot.data!.data()
                                          as Map<String, dynamic>;
                                      final likeCount =
                                          videoData['likeCount'] ?? 0;

                                      return StreamBuilder<bool>(
                                        stream: _isLikedStream(videoId),
                                        builder: (context, likeSnapshot) {
                                          final isLiked =
                                              likeSnapshot.data ?? false;
                                          return _buildCircleButton(
                                            icon: isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            label: '$likeCount',
                                            color: isLiked
                                                ? Colors.red
                                                : whiteColor,
                                            onTap: () => _toggleLike(videoId),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('videos')
                                        .doc(videoId)
                                        .collection('comments')
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final commentCount =
                                          snapshot.data?.docs.length ?? 0;
                                      return _buildCircleButton(
                                        icon: Icons.comment_outlined,
                                        label: '$commentCount',
                                        color: whiteColor,
                                        onTap: () => _showComments(videoId),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  _buildCircleButton(
                                    icon: Icons.share,
                                    label: 'Share',
                                    onTap: () => _shareVideo(videoData),
                                  ),
                                ],
                              ),
                            ),
                            // Bottom user info and description
                            Positioned(
                              left: 16,
                              right: 72,
                              bottom: 20,
                              child: _buildUserInfo(videoData),
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
                                onPressed: () =>
                                    _loadAndInitializeVideo(_currentIndex),
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

  Widget _buildUserInfo(Map<String, dynamic> videoData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ViewProfileScreen(userId: videoData['creatorId']),
                ),
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(videoData['creatorId'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage('default_avatar_url'),
                    );
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  final userPhotoURL =
                      userData?['photoURL'] as String? ?? 'default_avatar_url';

                  return CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(userPhotoURL),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ViewProfileScreen(userId: videoData['creatorId']),
                ),
              ),
              child: Text(
                videoData['creatorName'] ?? 'Anonymous',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(width: 20), // Added space
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(); // Return empty container while loading
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final following =
                    List<String>.from(userData?['following'] ?? []);
                final isFollowing = following.contains(videoData['creatorId']);

                return Container(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _toggleFollow(videoData['creatorId']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFollowing ? Colors.transparent : primaryColor,
                      side: BorderSide(
                        color: isFollowing ? Colors.white : Colors.transparent,
                        width: 1,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight:
                            isFollowing ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
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
    );
  }
}
