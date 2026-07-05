/// CDN helper for leonardo.osnova.io media — one place for every URL
/// transform instead of duplicated string templates per widget.
///
/// Every template below is copied verbatim from a proven-working call site
/// (not guessed from the decompiled-APK spec); this only consolidates them.
class OsnovaImage {
  final String? uuid;
  const OsnovaImage(this.uuid);

  static const _base = 'https://leonardo.osnova.io';

  /// Square crop, used for avatars. [size] in logical pixels.
  String avatar(int size) => '$_base/$uuid/-/scale_crop/${size}x$size/center/';

  /// Arbitrary-aspect crop, used for profile covers/banners.
  String scaleCrop(int width, int height) => '$_base/$uuid/-/scale_crop/${width}x$height/center/';

  /// Resized preview for feed/post images and attachment thumbnails.
  String preview(int width) => '$_base/$uuid/-/preview/$width/-/format/webp/';

  /// Full-resolution static image (original, converted to webp).
  String original() => '$_base/$uuid/-/format/webp/';

  /// Animated GIF rendered as a real gif. Deliberately no `-/preview/` —
  /// that resize operator returns a static frame even for animated sources.
  String gif() => '$_base/$uuid/-/format/gif/';

  /// Animated avatars/covers on DTF are actually short videos (the `gif` type
  /// carries duration/has_audio). Every image transform — including
  /// `-/format/gif/` — collapses them to a single static frame; only the mp4
  /// output preserves the animation, played muted+looping via video_player.
  String mp4() => '$_base/$uuid/-/format/mp4/';

  /// Direct URL for a hosted video file — no CDN transforms.
  /// CDN format transforms work for images but not for video; the raw UUID
  /// path returns the file as-is, which is already mp4 on DTF's storage.
  String videoUrl() => '$_base/$uuid/';
}
