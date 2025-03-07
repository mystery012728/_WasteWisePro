import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutternew/Features/App/User_auth/util/smack_bar.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;

class AwarenessVideosPage extends StatefulWidget {
  const AwarenessVideosPage({Key? key}) : super(key: key);

  @override
  _AwarenessVideosPageState createState() => _AwarenessVideosPageState();
}

class _AwarenessVideosPageState extends State<AwarenessVideosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _checkVideoLimit() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final userVideos = await _firestore
        .collection('awareness_videos')
        .where('userId', isEqualTo: userId)
        .get();

    return userVideos.docs.length < 5;
  }

  Future<bool> _isWasteManagementRelated(String title, String description) {
    // Define keywords related to waste management
    final keywords = [
      'waste',
      'recycle',
      'garbage',
      'trash',
      'environment',
      'clean',
      'sustainable',
      'green',
      'pollution',
      'management',
      'disposal',
      'eco',
      'reuse',
      'reduce',
      'compost'
    ];

    // Convert text to lowercase for case-insensitive matching
    final lowercaseTitle = title.toLowerCase();
    final lowercaseDescription = description.toLowerCase();

    // Check if any keyword is present in title or description
    return Future.value(keywords.any((keyword) =>
    lowercaseTitle.contains(keyword) ||
        lowercaseDescription.contains(keyword)));
  }

  Future<void> _uploadVideo() async {
    if (!await _checkVideoLimit()) {
      CustomSnackbar.showError(
        context: context,
        message: 'You can only upload up to 5 videos',
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    // Show dialog for title and description
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _VideoDetailsDialog(),
    );

    if (result == null) return;

    final title = result['title'] ?? '';
    final description = result['description'] ?? '';

    // Check if video content is related to waste management
    if (!await _isWasteManagementRelated(title, description)) {
      CustomSnackbar.showError(
        context: context,
        message: 'Video content must be related to waste management awareness',
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final userId = _auth.currentUser?.uid;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(video.path)}';
      final storageRef =
      _storage.ref().child('awareness_videos/$userId/$fileName');

      final uploadTask = storageRef.putFile(
        File(video.path),
        SettableMetadata(contentType: 'video/mp4'),
      );

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final videoUrl = await storageRef.getDownloadURL();

      await _firestore.collection('awareness_videos').add({
        'userId': userId,
        'userName': _auth.currentUser?.displayName ?? 'Anonymous',
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'dislikes': 0,
        'likedBy': [],
        'dislikedBy': []
      });

      if (mounted) {
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Video uploaded successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context: context,
          message: 'Error uploading video: $e',
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _handleLikeDislike(String videoId, bool isLike) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final videoRef = _firestore.collection('awareness_videos').doc(videoId);
    final video = await videoRef.get();

    if (!video.exists) return;

    final likedBy = List<String>.from(video.data()?['likedBy'] ?? []);
    final dislikedBy = List<String>.from(video.data()?['dislikedBy'] ?? []);

    if (isLike) {
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
        dislikedBy.remove(userId);
      }
    } else {
      if (dislikedBy.contains(userId)) {
        dislikedBy.remove(userId);
      } else {
        dislikedBy.add(userId);
        likedBy.remove(userId);
      }
    }

    await videoRef.update({
      'likes': likedBy.length,
      'dislikes': dislikedBy.length,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Awareness Videos',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade800,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All Videos'),
            Tab(text: 'My Videos'),
          ],
          labelStyle: GoogleFonts.poppins(),
          indicatorColor: Colors.white,
          labelColor: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildVideoList(false),
              _buildVideoList(true),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadVideo,
        backgroundColor: Colors.green.shade800,
        child: Icon(Icons.upload),
      ),
    );
  }

  Widget _buildVideoList(bool onlyUserVideos) {
    Query query = _firestore
        .collection('awareness_videos')
        .orderBy('timestamp', descending: true);

    if (onlyUserVideos) {
      query = query.where('userId', isEqualTo: _auth.currentUser?.uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final videos = snapshot.data!.docs;

        if (videos.isEmpty) {
          return Center(
            child: Text(
              onlyUserVideos
                  ? 'You haven\'t uploaded any videos yet'
                  : 'No videos available',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        return ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final data = video.data() as Map<String, dynamic>;

            return _VideoCard(
              videoUrl: data['videoUrl'],
              title: data['title'],
              description: data['description'],
              userName: data['userName'],
              likes: data['likes'],
              dislikes: data['dislikes'],
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              onLike: () => _handleLikeDislike(video.id, true),
              onDislike: () => _handleLikeDislike(video.id, false),
              isLiked: (data['likedBy'] as List<dynamic>)
                  .contains(_auth.currentUser?.uid),
              isDisliked: (data['dislikedBy'] as List<dynamic>)
                  .contains(_auth.currentUser?.uid),
            );
          },
        );
      },
    );
  }
}

class _VideoCard extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String description;
  final String userName;
  final int likes;
  final int dislikes;
  final DateTime timestamp;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final bool isLiked;
  final bool isDisliked;

  const _VideoCard({
    required this.videoUrl,
    required this.title,
    required this.description,
    required this.userName,
    required this.likes,
    required this.dislikes,
    required this.timestamp,
    required this.onLike,
    required this.onDislike,
    required this.isLiked,
    required this.isDisliked,
  });

  @override
  _VideoCardState createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 50,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                ],
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: CircularProgressIndicator()),
            ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.description,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'By ${widget.userName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.thumb_up,
                        color: widget.isLiked ? Colors.green : Colors.grey,
                      ),
                      onPressed: widget.onLike,
                    ),
                    Text('${widget.likes}'),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.thumb_down,
                        color: widget.isDisliked ? Colors.red : Colors.grey,
                      ),
                      onPressed: widget.onDislike,
                    ),
                    Text('${widget.dislikes}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoDetailsDialog extends StatefulWidget {
  @override
  _VideoDetailsDialogState createState() => _VideoDetailsDialogState();
}

class _VideoDetailsDialogState extends State<_VideoDetailsDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Video Details', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              labelStyle: GoogleFonts.poppins(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: GoogleFonts.poppins(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty &&
                _descriptionController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'description': _descriptionController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade800,
          ),
          child:
          Text('Upload', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }
}
