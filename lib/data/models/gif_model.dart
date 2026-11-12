/// A single GIF returned by the Giphy search endpoint.
class GifModel {
  final String id;
  final String title;

  /// Small rendition used in the grid (`fixed_width`).
  final String previewUrl;

  /// Full-size rendition used on the detail screen.
  final String originalUrl;

  /// Looping MP4 version of the full-size GIF (much lighter than the GIF).
  /// May be missing, in which case the animated image is used.
  final String? videoUrl;

  /// Width / height of the preview. Lets the grid reserve the right amount of
  /// space before the image loads and enables the masonry layout.
  final double aspectRatio;

  GifModel({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.originalUrl,
    this.videoUrl,
    this.aspectRatio = 1,
  });

  /// Shared Hero tag so the grid card flies into the detail screen.
  String get heroTag => 'gif_$id';

  factory GifModel.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>;
    final preview = images['fixed_width'] as Map<String, dynamic>;
    // Smaller GIF (fewer frames/colours): lighter to download and decode, which
    // matters most for a grid of many animated images. Falls back if missing.
    final grid = (images['fixed_width_downsampled'] as Map<String, dynamic>?) ??
        preview;
    final original = images['original'] as Map<String, dynamic>;

    // Giphy sends dimensions as strings.
    final width = double.tryParse('${preview['width']}');
    final height = double.tryParse('${preview['height']}');
    final ratio = (width != null && height != null && height > 0)
        ? width / height
        : 1.0;

    return GifModel(
      id: json['id'] as String,
      title: (json['title'] as String?)?.trim() ?? '',
      previewUrl: (grid['url'] as String?) ?? preview['url'] as String,
      originalUrl: original['url'] as String,
      videoUrl: original['mp4'] as String?,
      // Clamp extreme shapes so one very tall/wide GIF cannot dominate the grid.
      aspectRatio: ratio.clamp(0.6, 1.8).toDouble(),
    );
  }
}
