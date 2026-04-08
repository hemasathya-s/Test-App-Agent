import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../../core/model/order_details.dart';
import '../../../../../core/theme/app_theme.dart';

class MediaTabsWidget extends StatefulWidget {
  final List<ItemMedia> mediaList;

  const MediaTabsWidget({super.key, required this.mediaList});

  @override
  State<MediaTabsWidget> createState() => _MediaTabsWidgetState();
}

class _MediaTabsWidgetState extends State<MediaTabsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late List<ItemMedia> photos;
  late List<ItemMedia> videos;
  late List<ItemMedia> audios;

  @override
  void initState() {
    super.initState();
    _categorizeMedia();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _categorizeMedia() {
    photos = widget.mediaList
        .where((m) =>
            m.mediaType?.toLowerCase() == 'image' ||
            m.mediaType?.toLowerCase() == 'photo')
        .toList();

    videos = widget.mediaList
        .where((m) => m.mediaType?.toLowerCase() == 'video')
        .toList();

    audios = widget.mediaList
        .where((m) => m.mediaType?.toLowerCase() == 'audio')
        .toList();
  }

  @override
  void didUpdateWidget(covariant MediaTabsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaList != oldWidget.mediaList) {
      setState(() => _categorizeMedia());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Title ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 13, 16, 10),
          child: Text(
            'Media',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),

        // ── Card ──────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal:2),
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
            children: [
              // ── TabBar ────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle:
                      GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle:
                      GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(text: 'Photos (${photos.length})'),
                    Tab(text: 'Videos (${videos.length})'),
                    Tab(text: 'Audio (${audios.length})'),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

              // ── TabBarView ────────────────────────────
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMediaGrid(photos, 'image'),
                    _buildMediaGrid(videos, 'video'),
                    _buildMediaGrid(audios, 'audio'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Grid Builder ─────────────────────────────────────────────────────────────

  Widget _buildMediaGrid(List<ItemMedia> media, String type) {
    if (media.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type == 'image'
                  ? Icons.image_not_supported_outlined
                  : type == 'video'
                      ? Icons.videocam_off_outlined
                      : Icons.audiotrack_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'No ${type}s found',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Extract image URLs for gallery navigation
    final imageUrls = type == 'image'
        ? media.map((m) => m.url ?? '').where((u) => u.isNotEmpty).toList()
        : <String>[];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        final url = item.url;

        return GestureDetector(
          onTap: () {
            if (url == null) return;
            if (type == 'image') {
              _openImageGallery(context, imageUrls, index);
            } else if (type == 'video') {
              _showVideoDialog(context, url);
            } else if (type == 'audio') {
              _showAudioDialog(context, url);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildGridThumbnail(type, url),
          ),
        );
      },
    );
  }

  // ── Thumbnails ────────────────────────────────────────────────────────────

  Widget _buildGridThumbnail(String type, String? url) {
    if (type == 'image' && url != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey.shade100,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
          // Subtle overlay to indicate tappable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (type == 'video') {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
        ),
      );
    } else if (type == 'audio') {
      return Container(
        color: Color(AppTheme.primaryColor.value).withOpacity(0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, color: AppTheme.primaryColor, size: 28),
            const SizedBox(height: 4),
            Text(
              'Audio',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  // ── Full-Screen Image Gallery ────────────────────────────────────────────

  void _openImageGallery(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenGallery(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _showVideoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VideoPlayerDialog(url: url),
    );
  }

  void _showAudioDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => _AudioPlayerDialog(url: url),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-Screen Image Gallery with swipe navigation
// ─────────────────────────────────────────────────────────────────────────────

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Swipeable Page View ──────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 64),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Top Bar ──────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Close button
                  _GalleryIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Counter
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Left Arrow ───────────────────────────────
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryIconButton(
                  icon: Icons.chevron_left,
                  size: 32,
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),

          // ── Right Arrow ──────────────────────────────
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryIconButton(
                  icon: Icons.chevron_right,
                  size: 32,
                  onTap: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),

          // ── Dot Indicators ───────────────────────────
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Reusable semi-transparent icon button for gallery overlays
class _GalleryIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _GalleryIconButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video Player Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  const _VideoPlayerDialog({required this.url});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoPlayerController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Center(
            child: _isError
                ? const Text('Failed to load video',
                    style: TextStyle(color: Colors.white))
                : _chewieController != null &&
                        _chewieController!
                            .videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : const CircularProgressIndicator(
                        color: AppTheme.primaryColor),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _GalleryIconButton(
              icon: Icons.close,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Player Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AudioPlayerDialog extends StatefulWidget {
  final String url;
  const _AudioPlayerDialog({required this.url});

  @override
  State<_AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<_AudioPlayerDialog> {
  late VideoPlayerController _audioController;
  bool _isPlaying = false;
  bool _isFinished = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioController =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isInitialized = true);
              _audioController.play();
              _isPlaying = true;
            }
          });

    _audioController.addListener(() {
      final value = _audioController.value;
      if (value.position >= value.duration &&
          value.duration > Duration.zero &&
          !_isFinished) {
        if (mounted) {
          setState(() {
            _isFinished = true;
            _isPlaying = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      if (_isFinished) {
        _audioController.seekTo(Duration.zero);
        _audioController.play();
        _isFinished = false;
        _isPlaying = true;
      } else if (_isPlaying) {
        _audioController.pause();
        _isPlaying = false;
      } else {
        _audioController.play();
        _isPlaying = true;
      }
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Color(AppTheme.primaryColor.value).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.audiotrack,
                  size: 36, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Audio Player',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Play/Pause
            if (!_isInitialized)
              const CircularProgressIndicator()
            else
              IconButton(
                iconSize: 56,
                color: AppTheme.primaryColor,
                icon: Icon(_isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill),
                onPressed: _togglePlayback,
              ),

            const SizedBox(height: 12),

            // Progress
            if (_isInitialized)
              ValueListenableBuilder(
                valueListenable: _audioController,
                builder: (_, VideoPlayerValue value, __) {
                  final progress = value.duration.inMilliseconds > 0
                      ? value.position.inMilliseconds /
                          value.duration.inMilliseconds
                      : 0.0;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: AppTheme.primaryColor,
                          thumbColor: AppTheme.primaryColor,
                          inactiveTrackColor: Colors.grey.shade200,
                          overlayColor:
                              Color(AppTheme.primaryColor.value).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            final pos = Duration(
                              milliseconds:
                                  (v * value.duration.inMilliseconds).toInt(),
                            );
                            _audioController.seekTo(pos);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(value.position),
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                            Text(_fmt(value.duration),
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}