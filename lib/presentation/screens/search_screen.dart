import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/di.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/gif_model.dart';
import '../../data/network_status.dart';
import '../bloc/network_cubit.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';

/// Number of masonry columns for the available width (phones → desktop web).
int _columnsFor(double width) => (width / 190).floor().clamp(2, 6).toInt();

/// Quick-start searches shown before the user types anything.
const List<(String, String)> _suggestions = [
  ('😹', 'cats'),
  ('😂', 'funny'),
  ('🕺', 'dance'),
  ('🤯', 'mind blown'),
  ('👏', 'applause'),
  ('🎮', 'gaming'),
  ('🍕', 'food'),
  ('🤦', 'facepalm'),
];

/// Entry screen: search bar and an infinitely scrolling masonry grid of GIFs.
///
/// The screen does not know how navigation works: it reports a tap through
/// [onGifSelected] and the router (see `core/router.dart`) decides what happens.
/// [BlocProvider] creates and closes the blocs, so the screen never manages
/// their lifecycle by hand.
class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.onGifSelected,
    this.networkStatus,
  });

  /// Called when the user taps a GIF.
  final void Function(BuildContext context, GifModel gif) onGifSelected;

  /// Source of connectivity updates. Defaults to the real device state;
  /// tests pass a fake.
  final NetworkStatus? networkStatus;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SearchBloc>(create: (_) => getIt<SearchBloc>()),
        BlocProvider<NetworkCubit>(
          create: (_) =>
              NetworkCubit(networkStatus ?? ConnectivityNetworkStatus()),
        ),
      ],
      child: _SearchView(onGifSelected: onGifSelected),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({required this.onGifSelected});

  final void Function(BuildContext context, GifModel gif) onGifSelected;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  /// Distance from the bottom (logical pixels) at which the next page loads.
  static const double _paginationThreshold = 300;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _paginationThreshold) {
      context.read<SearchBloc>().add(LoadNextPage());
    }
  }

  void _search(String query) =>
      context.read<SearchBloc>().add(SearchQueryChanged(query));

  void _clear() {
    _textController.clear();
    _search('');
  }

  void _searchSuggestion(String query) {
    _textController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    FocusScope.of(context).unfocus();
    _search(query);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NetworkCubit, bool>(
      // Only react to "connection came back".
      listenWhen: (previous, current) => !previous && current,
      listener: (context, _) {
        // Back online: if the last search failed, try again automatically.
        if (context.read<SearchBloc>().state is SearchError) {
          _search(_textController.text);
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _AmbientBackground()),
            SafeArea(
              child: Column(
                children: [
                  _Header(
                    controller: _textController,
                    onChanged: _search,
                    onClear: _clear,
                  ),
                  const _OfflineBanner(),
                  Expanded(
                    child: BlocBuilder<SearchBloc, SearchState>(
                      builder: (context, state) => switch (state) {
                        SearchInitial() =>
                          _Discover(onSelected: _searchSuggestion),
                        SearchLoading() => const _SkeletonGrid(),
                        SearchError() => _StateMessage(
                            icon: Icons.wifi_off_rounded,
                            title: AppStrings.errorTitle,
                            message: AppStrings.errorMessage,
                            // Re-runs the current query.
                            onRetry: () => _search(_textController.text),
                          ),
                        SearchSuccess(:final gifs, :final hasReachedMax) =>
                          gifs.isEmpty
                              ? const _StateMessage(
                                  icon: Icons.sentiment_dissatisfied_rounded,
                                  title: AppStrings.emptyTitle,
                                  message: AppStrings.emptyMessage,
                                )
                              : _GifGrid(
                                  controller: _scrollController,
                                  gifs: gifs,
                                  showLoader: !hasReachedMax,
                                  onGifTap: (gif) =>
                                      widget.onGifSelected(context, gif),
                                ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
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

// ─────────────────────────────── Background ───────────────────────────────

/// Two soft colour glows behind the content give the dark UI some depth.
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -140,
            left: -100,
            child: _Glow(color: AppColors.accent, size: 380),
          ),
          Positioned(
            top: 120,
            right: -160,
            child: _Glow(color: AppColors.accentAlt, size: 340),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ───────────────────────────────── Header ─────────────────────────────────

/// Centered logo, tagline and the search field. Becomes more compact on short
/// screens (phones in landscape) so the results keep enough room.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact ? 8 : 16, 20, compact ? 8 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 32 : 40,
                    height: compact ? 32 : 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.gif_rounded,
                      color: Colors.black,
                      size: compact ? 24 : 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.brandGradient.createShader(bounds),
                    // Colour is replaced by the gradient; white is a placeholder.
                    child: Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: compact ? 24 : 30,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  AppStrings.tagline,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
              SizedBox(height: compact ? 10 : 20),
              _SearchField(
                controller: controller,
                onChanged: onChanged,
                onClear: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search field that glows in the accent colour while focused.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          width: 1.5,
          color: focused
              ? AppColors.accent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        cursorColor: AppColors.accent,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: AppStrings.searchHint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: focused ? AppColors.accent : Colors.white54,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: AppStrings.clear,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white54,
                    onPressed: widget.onClear,
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

/// Slides in below the header while the device has no connection.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkCubit, bool>(
      builder: (context, online) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: online
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          AppStrings.offlineBanner,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ──────────────────────────────── States ──────────────────────────────────

/// Initial state: invites the user to start with a popular search.
class _Discover extends StatelessWidget {
  const _Discover({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                AppStrings.discoverTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.discoverSubtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (emoji, label) in _suggestions)
                    ActionChip(
                      avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
                      label: Text(label),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      onPressed: () => onSelected(label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon, title and message for empty and error states.
class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;

  /// When set, a *Retry* button is shown below the message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(icon, size: 40, color: AppColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(AppStrings.retry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder tiles shown during the first search.
class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  static const List<double> _ratios = [1.0, 0.75, 1.4, 1.0, 1.2, 0.8];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 0.9).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          ),
          child: MasonryGridView.count(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            crossAxisCount: _columnsFor(constraints.maxWidth),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: 12,
            itemBuilder: (context, index) => AspectRatio(
              aspectRatio: _ratios[index % _ratios.length],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors
                      .placeholders[index % AppColors.placeholders.length],
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────── Grid ───────────────────────────────────

/// Pinterest-style masonry grid. Each tile uses the GIF's real aspect ratio,
/// so nothing is cropped and the layout does not jump while images load.
class _GifGrid extends StatelessWidget {
  const _GifGrid({
    required this.controller,
    required this.gifs,
    required this.showLoader,
    required this.onGifTap,
  });

  final ScrollController controller;
  final List<GifModel> gifs;
  final bool showLoader;
  final ValueChanged<GifModel> onGifTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: _columnsFor(constraints.maxWidth),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childCount: gifs.length,
                itemBuilder: (context, index) => _GifCard(
                  gif: gifs[index],
                  index: index,
                  onTap: () => onGifTap(gifs[index]),
                ),
              ),
            ),
            if (showLoader)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GifCard extends StatelessWidget {
  const _GifCard({
    required this.gif,
    required this.index,
    required this.onTap,
  });

  final GifModel gif;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder =
        AppColors.placeholders[index % AppColors.placeholders.length];

    return AspectRatio(
      aspectRatio: gif.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: gif.heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: gif.previewUrl,
                fit: BoxFit.cover,
                // Decode at tile size, not at the full GIF size, to keep memory low.
                memCacheWidth: 400,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (_, _) => ColoredBox(color: placeholder),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.surface,
                  child: Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
          // Ripple feedback on top of the image.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
