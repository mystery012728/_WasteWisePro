import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AwarenessVideosPage extends StatefulWidget {
  const AwarenessVideosPage({Key? key}) : super(key: key);

  @override
  _AwarenessVideosPageState createState() => _AwarenessVideosPageState();
}

class _AwarenessVideosPageState extends State<AwarenessVideosPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryGreen = const Color(0xFF2E7D32); // Dark Green
  final Color lightGreen = const Color(0xFF4CAF50); // Light Green

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Awareness Videos',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: MediaQuery.of(context).size.width * 0.05,
          ),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: _buildVideoList(),
    );
  }

  Widget _buildVideoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('awareness_videos')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: primaryGreen,
            ),
          );
        }

        final videos = snapshot.data!.docs;

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off_rounded,
                  size: 64,
                  color: primaryGreen.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No awareness videos available',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              final data = video.data() as Map<String, dynamic>;
              final videoId = YoutubePlayer.convertUrlToId(data['videoUrl'] ?? '');
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final thumbnailUrl = videoId != null
                  ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildVideoCard(
                  video: video,
                  data: data,
                  thumbnailUrl: thumbnailUrl,
                  timestamp: timestamp,
                  index: index,
                ),
              ).animate(delay: (50 * index).ms).fadeIn().slideY(begin: 0.1, end: 0);
            },
          ),
        );
      },
    );
  }

  Widget _buildVideoCard({
    required DocumentSnapshot video,
    required Map<String, dynamic> data,
    required String? thumbnailUrl,
    required DateTime timestamp,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailPage(
              videoId: video.id,
              videoUrl: data['videoUrl'] ?? '',
              title: data['title'] ?? 'Unknown Title',
              description: data['description'] ?? 'No description',
              timestamp: timestamp,
              primaryGreen: primaryGreen,
              lightGreen: lightGreen,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryGreen,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.error)),
                    ),
                  )
                      : Container(
                    height: 200,
                    color: Colors.grey[300],
                    width: double.infinity,
                    child: const Center(child: Icon(Icons.video_library, size: 50)),
                  ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                // Time indicator
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatDate(timestamp),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Video info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? 'Unknown Title',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data['viewCount'] ?? 0} views',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data['likeCount'] ?? 0}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Make formatDate a global function so it can be used across classes
String formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return '${difference.inHours} hours ago';
    }
  } else if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()} weeks ago';
  } else {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class VideoDetailPage extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final String title;
  final String description;
  final DateTime timestamp;
  final Color primaryGreen;
  final Color lightGreen;

  const VideoDetailPage({
    Key? key,
    required this.videoId,
    required this.videoUrl,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.primaryGreen,
    required this.lightGreen,
  }) : super(key: key);

  @override
  _VideoDetailPageState createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  String? _youtubeVideoId;
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserInteractions();
    _initializePlayer();
  }

  void _loadUserInteractions() async {
    if (_auth.currentUser != null) {
      try {
        // Get video statistics
        final videoDoc = await _firestore
            .collection('awareness_videos')
            .doc(widget.videoId)
            .get();

        if (videoDoc.exists) {
          final data = videoDoc.data();
          setState(() {
            _likeCount = (data?['likeCount'] ?? 0);
            _dislikeCount = (data?['dislikeCount'] ?? 0);
          });
        }

        // Check if user has liked or disliked this video
        final userInteractionDoc = await _firestore
            .collection('user_video_interactions')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('videoId', isEqualTo: widget.videoId)
            .limit(1)
            .get();

        if (userInteractionDoc.docs.isNotEmpty) {
          final data = userInteractionDoc.docs.first.data();
          setState(() {
            _isLiked = data['liked'] ?? false;
            _isDisliked = data['disliked'] ?? false;
          });
        }
      } catch (e) {
        print('Error loading interactions: $e');
      }
    }
  }

  void _initializePlayer() {
    _youtubeVideoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (_youtubeVideoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _youtubeVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: true,
        ),
      )..addListener(_listener);
    }
  }

  void _listener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      setState(() {});
    }
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleLike() async {
    if (_auth.currentUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    final userId = _auth.currentUser!.uid;
    final interactionRef = _firestore.collection('user_video_interactions');
    final videoRef = _firestore.collection('awareness_videos').doc(widget.videoId);

    try {
      // Get existing interaction if any
      final existingQuery = await interactionRef
          .where('userId', isEqualTo: userId)
          .where('videoId', isEqualTo: widget.videoId)
          .limit(1)
          .get();

      final bool hasExisting = existingQuery.docs.isNotEmpty;
      final bool wasLiked = hasExisting ? (existingQuery.docs.first.data()['liked'] ?? false) : false;
      final bool wasDisliked = hasExisting ? (existingQuery.docs.first.data()['disliked'] ?? false) : false;

      // Determine state changes
      final bool willBeLiked = !_isLiked;
      final bool willBeDisliked = false; // Always remove dislike when liking

      // Calculate count changes
      int likeCountChange = 0;
      int dislikeCountChange = 0;

      if (wasLiked && !willBeLiked) likeCountChange = -1;
      if (!wasLiked && willBeLiked) likeCountChange = 1;
      if (wasDisliked && !willBeDisliked) dislikeCountChange = -1;

      // Update firestore in a batch
      final batch = _firestore.batch();

      // Update interaction document
      if (hasExisting) {
        batch.update(existingQuery.docs.first.reference, {
          'liked': willBeLiked,
          'disliked': willBeDisliked,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final newInteractionRef = interactionRef.doc();
        batch.set(newInteractionRef, {
          'userId': userId,
          'videoId': widget.videoId,
          'liked': willBeLiked,
          'disliked': willBeDisliked,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update video counts
      if (likeCountChange != 0 || dislikeCountChange != 0) {
        batch.update(videoRef, {
          'likeCount': FieldValue.increment(likeCountChange),
          'dislikeCount': FieldValue.increment(dislikeCountChange),
        });
      }

      await batch.commit();

      // Update local state
      setState(() {
        _isLiked = willBeLiked;
        _isDisliked = willBeDisliked;
        _likeCount += likeCountChange;
        _dislikeCount += dislikeCountChange;
      });

    } catch (e) {
      print('Error updating like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  void _handleDislike() async {
    if (_auth.currentUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    final userId = _auth.currentUser!.uid;
    final interactionRef = _firestore.collection('user_video_interactions');
    final videoRef = _firestore.collection('awareness_videos').doc(widget.videoId);

    try {
      // Get existing interaction if any
      final existingQuery = await interactionRef
          .where('userId', isEqualTo: userId)
          .where('videoId', isEqualTo: widget.videoId)
          .limit(1)
          .get();

      final bool hasExisting = existingQuery.docs.isNotEmpty;
      final bool wasLiked = hasExisting ? (existingQuery.docs.first.data()['liked'] ?? false) : false;
      final bool wasDisliked = hasExisting ? (existingQuery.docs.first.data()['disliked'] ?? false) : false;

      // Determine state changes
      final bool willBeLiked = false; // Always remove like when disliking
      final bool willBeDisliked = !_isDisliked;

      // Calculate count changes
      int likeCountChange = 0;
      int dislikeCountChange = 0;

      if (wasLiked && !willBeLiked) likeCountChange = -1;
      if (wasDisliked && !willBeDisliked) dislikeCountChange = -1;
      if (!wasDisliked && willBeDisliked) dislikeCountChange = 1;

      // Update firestore in a batch
      final batch = _firestore.batch();

      // Update interaction document
      if (hasExisting) {
        batch.update(existingQuery.docs.first.reference, {
          'liked': willBeLiked,
          'disliked': willBeDisliked,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final newInteractionRef = interactionRef.doc();
        batch.set(newInteractionRef, {
          'userId': userId,
          'videoId': widget.videoId,
          'liked': willBeLiked,
          'disliked': willBeDisliked,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update video counts
      if (likeCountChange != 0 || dislikeCountChange != 0) {
        batch.update(videoRef, {
          'likeCount': FieldValue.increment(likeCountChange),
          'dislikeCount': FieldValue.increment(dislikeCountChange),
        });
      }

      await batch.commit();

      // Update local state
      setState(() {
        _isLiked = willBeLiked;
        _isDisliked = willBeDisliked;
        _likeCount += likeCountChange;
        _dislikeCount += dislikeCountChange;
      });

    } catch (e) {
      print('Error updating dislike: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  void _handleShare() {
    Share.share('Check out this video: ${widget.title}\n${widget.videoUrl}');
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(
                Icons.lock_rounded,
                color: widget.primaryGreen,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryGreen,
                ),
              ),
            ],
          ),
          content: Text(
            'You need to sign in to perform this action.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to login page
                      // Navigator.of(context).push(MaterialPageRoute(builder: (context) => LoginPage()));
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: widget.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        );
      },
    );
  }

  void _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    if (_auth.currentUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    try {
      await _firestore.collection('video_comments').add({
        'videoId': widget.videoId,
        'userId': _auth.currentUser!.uid,
        'userName': _auth.currentUser!.displayName ?? 'Anonymous',
        'userPhotoUrl': _auth.currentUser!.photoURL,
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      FocusScope.of(context).unfocus();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Comment posted successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: widget.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not post comment. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showFullScreenVideo() {
    if (_youtubeVideoId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenVideoPage(
            videoId: _youtubeVideoId!,
            title: widget.title,
            primaryGreen: widget.primaryGreen,
          ),
        ),
      );
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _youtubeVideoId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: widget.primaryGreen.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Invalid video URL',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Go Back',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: widget.primaryGreen,
            foregroundColor: Colors.white,
            expandedHeight: 0,
            floating: true,
            pinned: true,
            title: Text(
              'Video Details',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: _handleShare,
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // YouTube Player
                YoutubePlayerBuilder(
                  player: YoutubePlayer(
                    controller: _controller,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: widget.primaryGreen,
                    progressColors: ProgressBarColors(
                      playedColor: widget.primaryGreen,
                      handleColor: widget.lightGreen,
                    ),
                    onReady: () {
                      setState(() {
                        _isPlayerReady = true;
                      });
                    },
                    bottomActions: [
                      const SizedBox(width: 14.0),
                      CurrentPosition(),
                      const SizedBox(width: 8.0),
                      ProgressBar(
                        isExpanded: true,
                        colors: ProgressBarColors(
                          playedColor: widget.primaryGreen,
                          handleColor: widget.lightGreen,
                        ),
                      ),
                      RemainingDuration(),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                        onPressed: _showFullScreenVideo,
                      ),
                    ],
                  ),
                  builder: (context, player) {
                    return player;
                  },
                ),

                // Video Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and timestamp
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatDate(widget.timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),

                      // Action Buttons
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Like Button
                            _buildActionButton(
                              icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              label: _formatNumber(_likeCount),
                              color: _isLiked ? widget.primaryGreen : Colors.grey[700]!,
                              onTap: _handleLike,
                            ),

                            // Dislike Button
                            _buildActionButton(
                              icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                              label: _formatNumber(_dislikeCount),
                              color: _isDisliked ? Colors.red : Colors.grey[700]!,
                              onTap: _handleDislike,
                            ),

                            // Share Button
                            _buildActionButton(
                              icon: Icons.share_outlined,
                              label: 'Share',
                              color: Colors.grey[700]!,
                              onTap: _handleShare,
                            ),
                          ],
                        ),
                      ),

                      // Description
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          title: Text(
                            'Description',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: widget.primaryGreen,
                            ),
                          ),
                          trailing: Icon(
                            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: widget.primaryGreen,
                          ),
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isExpanded = expanded;
                            });
                          },
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                widget.description,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Comments Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comments',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: widget.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Add Comment
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    radius: 20,
                                    child: _auth.currentUser?.photoURL != null
                                        ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: _auth.currentUser!.photoURL!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: widget.primaryGreen,
                                        ),
                                        errorWidget: (context, url, error) => const Icon(Icons.person),
                                      ),
                                    )
                                        : const Icon(Icons.person),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      decoration: InputDecoration(
                                        hintText: 'Add a comment...',
                                        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                                        border: InputBorder.none,
                                      ),
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.send_rounded, color: widget.primaryGreen),
                                    onPressed: _postComment,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Comments List
                            _buildCommentsList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('video_comments')
          .where('videoId', isEqualTo: widget.videoId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Error loading comments',
                style: GoogleFonts.poppins(
                  color: Colors.red[400],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(
                color: widget.primaryGreen,
              ),
            ),
          );
        }

        final comments = snapshot.data!.docs;

        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No comments yet. Be the first to comment!',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            final timestamp = comment['timestamp'] != null
                ? (comment['timestamp'] as Timestamp).toDate()
                : DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    radius: 16,
                    child: comment['userPhotoUrl'] != null
                        ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: comment['userPhotoUrl'],
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.primaryGreen,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 16),
                      ),
                    )
                        : const Icon(Icons.person, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment['userName'] ?? 'Anonymous',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatDate(timestamp),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['text'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: (50 * index).ms).fadeIn().slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final String videoId;
  final String title;
  final Color primaryGreen;

  const FullScreenVideoPage({
    Key? key,
    required this.videoId,
    required this.title,
    required this.primaryGreen,
  }) : super(key: key);

  @override
  _FullScreenVideoPageState createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
        enableCaption: true,
      ),
    )..addListener(_listener);

    // Force landscape orientation for fullscreen viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  void _listener() {
    if (_isPlayerReady && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Reset to portrait orientation when leaving fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: widget.primaryGreen,
                  progressColors: ProgressBarColors(
                    playedColor: widget.primaryGreen,
                    handleColor: Colors.greenAccent,
                  ),
                  onReady: () {
                    setState(() {
                      _isPlayerReady = true;
                    });
                  },
                  bottomActions: [
                    const SizedBox(width: 14.0),
                    CurrentPosition(),
                    const SizedBox(width: 8.0),
                    ProgressBar(
                      isExpanded: true,
                      colors: ProgressBarColors(
                        playedColor: widget.primaryGreen,
                        handleColor: Colors.greenAccent,
                      ),
                    ),
                    RemainingDuration(),
                  ],
                ),
                builder: (context, player) {
                  return player;
                },
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}