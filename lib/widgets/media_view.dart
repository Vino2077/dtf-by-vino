import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';
import '../util/external_link.dart';
import '../util/json_safe.dart';
import '../util/osnova_image.dart';

/// Renders a single Osnova media object: `{type, data: {uuid, width, height,
/// type, isVideo, has_audio}}`. Posts and comments use slightly different
/// shapes for the same kind of content (confirmed via live API, 2026-06-29):
/// - Post media: outer `type` is always "image"; the real signal is
///   `data.type` ('png'/'gif'/...) + `data.isVideo` + `data.has_audio`.
/// - Comment media: outer `type` is 'image'/'movie'/'video'/'link'. Movie
///   clips ('movie'/'mp4') have NO `isVideo` field at all. External embeds
///   (outer 'video', e.g. YouTube) have no direct `uuid` — only a thumbnail.
/// `has_audio: true` always wins regardless of type/isVideo — that's the
/// one combination DTF's own metadata is inconsistent about (a "gif" can
/// have audio and needs a real player, not a muted looping image).
class MediaView extends StatelessWidget {
  final dynamic media;
  final double maxHeight;

  const MediaView({super.key, required this.media, this.maxHeight = 640});

  @override
  Widget build(BuildContext context) {
    final outerType = media is Map ? media['type']?.toString() : null;
    final data = media is Map ? media['data'] : null;

    // External embed (e.g. YouTube) — no DTF-hosted uuid, just a thumbnail.
    if (outerType == 'video' && data is Map && data['uuid'] == null) {
      return _ExternalVideoCard(data: data, maxHeight: maxHeight);
    }

    final uuid = data?['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) return const SizedBox();

    final fileType = (data['type'] ?? '').toString().toLowerCase();
    final hasAudio = data['has_audio'] == true;
    final isMovieFile = outerType == 'movie' || fileType == 'mp4';
    final isGifFile = fileType == 'gif';
    final width = (data['width'] as num?)?.toDouble() ?? 1;
    final height = (data['height'] as num?)?.toDouble() ?? 1;
    final aspect = (width > 0 && height > 0) ? width / height : 16 / 9;
    final cdn = OsnovaImage(uuid);

    // Has sound, or a real movie file → a proper video, not a muted loop.
    // Tap opens the fullscreen player (sound starts there, not inline).
    if (hasAudio || isMovieFile) {
      return _ConstrainedMedia(
        aspect: aspect,
        maxHeight: maxHeight,
        child: GestureDetector(
          onTap: () => _openFullscreenVideo(context, cdn.videoUrl()),
          child: hasAudio
              ? _VideoPoster(previewUrl: cdn.preview(640))
              : _InlineLoop(url: cdn.videoUrl()),
        ),
      );
    }

    // Silent GIF → animated image (cheaper than a video controller).
    if (isGifFile) {
      return _ConstrainedMedia(
        aspect: aspect,
        maxHeight: maxHeight,
        child: GestureDetector(
          onTap: () => _openFullscreenGif(context, cdn.gif()),
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              // Image.network (not CachedNetworkImage) is required here:
              // cached_network_image saves GIFs to disk via flutter_cache_manager,
              // which can strip animation during file storage/retrieval. Image.network
              // decodes bytes directly from the network codec, preserving all frames.
              Image.network(
                cdn.gif(),
                fit: BoxFit.cover,
                width: double.infinity,
                gaplessPlayback: true,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : Container(color: AppColors.bgElevated),
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.bgElevated,
                  child: const Center(child: Icon(Icons.gif_box_outlined, color: Colors.grey)),
                ),
              ),
              _badge('GIF'),
            ],
          ),
        ),
      );
    }

    // Static image (cached on disk).
    return _ConstrainedMedia(
      aspect: aspect,
      maxHeight: maxHeight,
      child: GestureDetector(
        onTap: () => _openFullscreenImage(context, cdn.original()),
        child: CachedNetworkImage(
          imageUrl: cdn.preview(640),
          fit: BoxFit.cover,
          width: double.infinity,
          memCacheWidth: 700,
          placeholder: (_, __) => Container(color: AppColors.bgElevated),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.bgElevated,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  void _openFullscreenImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullscreenImage(url: url)));
  }

  void _openFullscreenGif(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullscreenGif(url: url)));
  }

  void _openFullscreenVideo(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullscreenVideo(url: url)));
  }
}

Widget _badge(String text) => Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );

class _ConstrainedMedia extends StatelessWidget {
  final double aspect;
  final double maxHeight; // generous cap so 8:21 media doesn't span several screens
  final Widget child;
  const _ConstrainedMedia({required this.aspect, required this.maxHeight, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Natural height for full-width media in its real aspect ratio.
          double height = width / aspect;
          if (height > maxHeight) height = maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: width,
                  height: width / aspect,
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Silent auto-looping video (real mp4 clip, or a "gif" with no audio that
/// DTF only serves as mp4). No tap handling of its own — the parent
/// GestureDetector owns the tap, this just plays muted in a loop.
class _InlineLoop extends StatefulWidget {
  final String url;
  const _InlineLoop({required this.url});

  @override
  State<_InlineLoop> createState() => _InlineLoopState();
}

class _InlineLoopState extends State<_InlineLoop> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();
      if (!mounted) { c.dispose(); return; }
      c.setLooping(true);
      c.setVolume(0);
      c.play();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: AppColors.bgElevated,
        child: const Center(child: Icon(Icons.videocam_off, color: Colors.grey)),
      );
    }
    if (!_ready || _controller == null) {
      return Container(
        color: AppColors.bgElevated,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return VideoPlayer(_controller!);
  }
}

/// Static poster frame for a video that has sound — no controller spun up
/// inline (would mean playing N videos at once in a feed); tapping opens the
/// fullscreen player where it actually plays, with sound.
class _VideoPoster extends StatelessWidget {
  final String previewUrl;
  const _VideoPoster({required this.previewUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CachedNetworkImage(
          imageUrl: previewUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 700,
          placeholder: (_, __) => Container(color: AppColors.bgElevated),
          errorWidget: (_, __, ___) => Container(color: AppColors.bgElevated),
        ),
        Container(
          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
          padding: const EdgeInsets.all(4),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
        ),
      ],
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 48),
          ),
        ),
      ),
    );
  }
}

class _FullscreenGif extends StatelessWidget {
  final String url;
  const _FullscreenGif({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const CircularProgressIndicator(),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      ),
    );
  }
}

/// Fullscreen video player. Stays portrait regardless of the video's own
/// aspect ratio (the app is locked to portrait — see main.dart) — a 16:9
/// video is letterboxed via BoxFit.contain, never rotated to landscape.
class _FullscreenVideo extends StatefulWidget {
  final String url;
  const _FullscreenVideo({required this.url});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();
      if (!mounted) { c.dispose(); return; }
      c.setLooping(true);
      c.setVolume(1);
      c.play();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _failed
          ? const Center(child: Icon(Icons.videocam_off, color: Colors.grey, size: 48))
          : !_ready || _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() =>
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play()),
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            if (!_controller!.value.isPlaying)
                              const Icon(Icons.play_circle_fill,
                                  color: Colors.white70, size: 64),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: const Color(0xFF333333),
                          bufferedColor: const Color(0xFF555555),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller!,
                      builder: (_, v, __) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(v.position),
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _controller!.value.isPlaying
                                      ? _controller!.pause()
                                      : _controller!.play()),
                              child: Icon(
                                v.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            Text(_fmt(v.duration),
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// External video embed (e.g. YouTube) attached to a comment — DTF gives us
/// only a thumbnail + service id, no hosted file. Shows the thumbnail with a
/// play affordance; tapping opens the real video externally.
class _ExternalVideoCard extends StatelessWidget {
  final Map data;
  final double maxHeight;
  const _ExternalVideoCard({required this.data, required this.maxHeight});

  String? get _thumbUuid => digString(data, ['thumbnail', 'data', 'uuid']);

  String? get _url {
    final service = digString(data, ['external_service', 'name']);
    final id = digString(data, ['external_service', 'id']);
    if (service == 'youtube' && id != null && id.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$id';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbUuid;
    if (thumb == null) return const SizedBox();
    final width = (data['width'] as num?)?.toDouble() ?? 1;
    final height = (data['height'] as num?)?.toDouble() ?? 1;
    final aspect = (width > 0 && height > 0) ? width / height : 16 / 9;
    final url = _url;

    return _ConstrainedMedia(
      aspect: aspect,
      maxHeight: maxHeight,
      child: GestureDetector(
        onTap: url != null ? () => openExternalUrl(url) : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: OsnovaImage(thumb).preview(640),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 700,
              placeholder: (_, __) => Container(color: AppColors.bgElevated),
              errorWidget: (_, __, ___) => Container(color: AppColors.bgElevated),
            ),
            Container(
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}
