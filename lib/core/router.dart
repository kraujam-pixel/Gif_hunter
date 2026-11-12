import 'package:go_router/go_router.dart';

import '../data/models/gif_model.dart';
import '../presentation/screens/detail_screen.dart';
import '../presentation/screens/search_screen.dart';

/// Route paths in one place.
abstract final class AppRoutes {
  static const String search = '/';
  static const String detail = '/detail';
}

/// The single place that knows how screens connect.
///

/// Default page transitions are kept on purpose so each platform gets its own
/// native behaviour (iOS swipe-back, Android predictive back).
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => SearchScreen(
        onGifSelected: (context, gif) =>
            context.push(AppRoutes.detail, extra: gif),
      ),
    ),
    GoRoute(
      path: AppRoutes.detail,
      redirect: (context, state) =>
          state.extra is GifModel ? null : AppRoutes.search,
      builder: (context, state) => DetailScreen(
        gif: state.extra! as GifModel,
        onBack: () => context.pop(),
      ),
    ),
  ],
);
