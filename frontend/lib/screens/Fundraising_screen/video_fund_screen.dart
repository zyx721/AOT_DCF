import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/drive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

class VideoFundraisingScreen extends StatefulWidget {
  @override
  _VideoFundraisingScreenState createState() => _VideoFundraisingScreenState();
}

class _VideoFundraisingScreenState extends State<VideoFundraisingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  File? _coverImage;
  File? _video;
  bool _isLoading = false;
  VideoPlayerController? _videoPlayerController;
  final GoogleDriveService _driveService = GoogleDriveService();

  // Add custom green colors
  final Color primaryGreen = Color(0xFF2E7D32);
  final Color lightGreen = Color(0xFFE8F5E9);

  Future<void> _pickCoverImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _coverImage = File(image.path);
      });
    }
  }

  Future<void> _takeCoverImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _coverImage = File(image.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _video = File(video.path);
        _initializeVideoPlayer(video.path);
      });
    }
  }

  Future<void> _recordVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() {
        _video = File(video.path);
        _initializeVideoPlayer(video.path);
      });
    }
  }

  void _initializeVideoPlayer(String path) {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  void _showMediaOptions(BuildContext context, bool isVideo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(isVideo ? Icons.video_library : Icons.photo_library, color: Theme.of(context).primaryColor),
                title: Text(isVideo ? 'Choose from gallery' : 'Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  if (isVideo) {
                    _pickVideo();
                  } else {
                    _pickCoverImage();
                  }
                },
              ),
              ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.camera_alt, color: Theme.of(context).primaryColor),
                title: Text(isVideo ? 'Record video' : 'Take photo'),
                onTap: () {
                  Navigator.pop(context);
                  if (isVideo) {
                    _recordVideo();
                  } else {
                    _takeCoverImage();
                  }
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createVideoFundraiser() async {
    if (!_formKey.currentState!.validate() || _coverImage == null || _video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields and select media'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final coverImageUrl = await _driveService.uploadFile(_coverImage!);
      final videoUrl = await _driveService.uploadFile(_video!);

      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('videos').add({
        'title': _titleController.text,
        'creatorId': user?.uid,
        'creatorName': user?.displayName,
        'mainImageUrl': coverImageUrl,
        'videoUrl': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'expirationDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: 30)),
        ),
        'likeCount': 0,  // Add initial like counter
        'prayCount': 0,  // Add initial pray counter
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Fundraiser created successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating fundraiser: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Fundraiser', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white
          )
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryGreen),
                  SizedBox(height: 20),
                  Text('Creating your fundraiser...',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w500
                      )),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lightGreen,
                    Colors.white,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tell Your Story',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Create a compelling video fundraiser to share with your community',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Cover Image Section
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cover Image',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Add an eye-catching image that represents your fundraiser',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 16),
                              _coverImage == null
                                  ? GestureDetector(
                                      onTap: () => _showMediaOptions(context, false),
                                      child: Container(
                                        height: 180,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate,
                                              size: 48,
                                              color: primaryGreen,
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Add Cover Image',
                                              style: TextStyle(
                                                color: primaryGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            _coverImage!,
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _coverImage = null),
                                            child: Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _showMediaOptions(context, false),
                                            child: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: primaryGreen,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Video Section
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Video',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Add a short video explaining your fundraiser',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 16),
                              if (_video == null)
                                GestureDetector(
                                  onTap: () => _showMediaOptions(context, true),
                                  child: Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam,
                                          size: 48,
                                          color: primaryGreen,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Add Video',
                                          style: TextStyle(
                                            color: primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (_videoPlayerController != null &&
                                  _videoPlayerController!.value.isInitialized)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                                        child: VideoPlayer(_videoPlayerController!),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Center(
                                        child: IconButton(
                                          icon: Icon(
                                            _videoPlayerController!.value.isPlaying
                                                ? Icons.pause_circle_outlined
                                                : Icons.play_circle_outlined,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (_videoPlayerController!.value.isPlaying) {
                                                _videoPlayerController!.pause();
                                              } else {
                                                _videoPlayerController!.play();
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          _videoPlayerController?.dispose();
                                          setState(() {
                                            _video = null;
                                            _videoPlayerController = null;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Form Fields
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: lightGreen,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fundraiser Title',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen,
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter a compelling title',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: lightGreen.withOpacity(0.1),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.red.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.title_rounded,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 32),
                      
                      ElevatedButton(
                        onPressed: _createVideoFundraiser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Create Fundraiser',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
    _videoPlayerController?.dispose();
    _titleController.dispose();
    super.dispose();
  }
}