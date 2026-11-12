import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/gif_model.dart';

/// Full-screen view of one GIF with a blurred copy of itself as the backdrop.
///
/// Portrait: the GIF on top, an info panel below. Landscape: the GIF on the
/// left, the info panel on the right, so nothing gets squeezed on short screens.
/// Navigation is delegated through [onBack]; the screen does not know the router.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.gif, required this.onBack});

  final GifModel gif;
  final VoidCallback onBack;

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: gif.originalUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.accentAlt),
              SizedBox(width: 12),
              Text(AppStrings.linkCopied),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final title = gif.title.isEmpty ? AppStrings.untitled : gif.title;

    final media = Hero(
      tag: gif.heroTag,
      // During the flight only a plain image is shown, so no second video
      // player is created for the shuttle.
      flightShuttleBuilder: (_, _, _, _, _) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CachedNetworkImage(imageUrl: gif.previewUrl, fit: BoxFit.cover),
      ),
      child: DecoratedBox(
        // Soft accent glow behind the GIF.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 50,
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: _GifPlayer(gif: gif),
        ),
      ),
    );

    final info = _GlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _copyLink(context),
            icon: const Icon(Icons.link_rounded),
            label: const Text(AppStrings.copyLink),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: blurred backdrop. The small preview is enough for a heavy
          // blur and avoids decoding the large original twice. ClipRect keeps
          // the blur inside this layer.
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: CachedNetworkImage(
                imageUrl: gif.previewUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.6)),

          // Layer 2: content.
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final landscape =
                            constraints.maxWidth > constraints.maxHeight;

                        if (landscape) {
                          return Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      64, 16, 8, 16),
                                  child: Center(child: media),
                                ),
                              ),
                              SizedBox(
                                width: 340,
                                child: Center(
                                  child: SingleChildScrollView(child: info),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            const SizedBox(height: 64),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Center(child: media),
                              ),
                            ),
                            info,
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: AppStrings.back,
                    // Platform-native icon: chevron on iOS, arrow on Android.
                    icon: const BackButtonIcon(),
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays Giphy's MP4 rendition (muted, looping) instead of the heavy GIF.
///
/// While the video initialises the cached preview is shown. If the GIF has no
/// MP4 or playback fails, it falls back to the animated image. Tap to
/// pause / resume.
class _GifPlayer extends StatefulWidget {
  const _GifPlayer({required this.gif});

  final GifModel gif;

  @override
  State<_GifPlayer> createState() => _GifPlayerState();
}

class _GifPlayerState extends State<_GifPlayer> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  late bool _useImageFallback;

  @override
  void initState() {
    super.initState();
    final url = widget.gif.videoUrl;
    _useImageFallback = url == null;
    if (url != null) _initVideo(url);
  }

  Future<void> _initVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0); // also required for web autoplay
      await controller.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _useImageFallback = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback(VideoPlayerController controller) {
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_videoReady && controller != null) {
      return GestureDetector(
        onTap: () => _togglePlayback(controller),
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(controller),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) => AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_useImageFallback) {
      return CachedNetworkImage(
        imageUrl: widget.gif.originalUrl,
        fit: BoxFit.contain,
        placeholder: (_, _) => CachedNetworkImage(
          imageUrl: widget.gif.previewUrl,
          fit: BoxFit.contain,
        ),
        errorWidget: (_, _, _) => const Padding(
          padding: EdgeInsets.all(32),
          child: Icon(Icons.broken_image_rounded, size: 48),
        ),
      );
    }

    // Video is still loading: show the preview that is already cached.
    return CachedNetworkImage(
      imageUrl: widget.gif.previewUrl,
      fit: BoxFit.contain,
    );
  }
}

/// Frosted-glass card. [BackdropFilter] blurs whatever is behind it, so it is
/// wrapped in a clip to limit the effect to the card's own bounds.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
