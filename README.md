# GIF Hunter

A responsive Flutter app for searching GIFs with the [Giphy API](https://developers.giphy.com/docs/api/).
Built as a technical assignment for Chili Labs.

## Flutter version

> **Flutter 3.XX.X (stable) · Dart 3.XX.X** ← replace with the output of `flutter --version`

The project requires Dart `^3.13.7` (see `pubspec.yaml`).

## Requirements checklist

| Requirement | Status | Where |
| --- | --- | --- |
| iOS & Android | Plain Flutter/Material code, no web-only APIs | – |
| Auto search after a short delay | ✅ 500 ms debounce, stale requests cancelled | `search_bloc.dart` |
| Pagination | ✅ infinite scroll, one request at a time, no duplicates | `search_bloc.dart`, `search_screen.dart` |
| Portrait & landscape | ✅ adaptive column count, compact header, side-by-side detail layout | `search_screen.dart`, `detail_screen.dart` |
| Error handling | ✅ friendly message, *Retry*, pagination failures keep results | `search_bloc.dart`, `search_screen.dart` |
| Unit & widget tests | ✅ model, BLoC, cubit and screen tests | `test/` |
| Responsive, platform guidelines | ✅ platform-native transitions & back gesture, adaptive icons/indicators | `core/router.dart` |
| ≥ 2 views from Giphy data | ✅ search grid and detail view | `screens/` |
| Grid, detail on tap | ✅ masonry grid → detail screen | `screens/` |
| Loading indicators | ✅ skeleton grid, pagination spinner, preview-while-loading | `search_screen.dart` |
| Error display | ✅ error state with retry; offline banner | `search_screen.dart` |
| State management (bonus) | ✅ `flutter_bloc` (BLoC + Cubit) | `presentation/bloc/` |
| Architecture (bonus) | ✅ data / presentation / core layers, DI with `get_it` | see below |
| Navigation separate from pages (bonus) | ✅ screens get callbacks; all routing lives in the router | `core/router.dart` |
| Network availability (bonus) | ✅ offline banner, auto-retry when back online | `network_status.dart`, `network_cubit.dart` |

## Features

- **Search as you type**, with debounce and request cancellation.
- **Masonry grid** that uses each GIF's real aspect ratio; column count follows the screen width.
- **Detail screen** that plays the lightweight MP4 (muted, looping, tap to pause) with automatic
  fallback to the GIF, blurred backdrop, and a *Copy link* action.
- **Popular-search chips** on the start screen.
- **Offline handling:** banner while offline; a failed search retries by itself when the connection returns.
- **Dark UI** with a gradient logo, glow effects, skeleton loader, frosted-glass panel and Hero transitions.

## Architecture

```
lib/
├── core/            # DI, router, theme, config, strings
├── data/            # GifModel, GiphyRepository (Dio), NetworkStatus (connectivity_plus)
└── presentation/
    ├── bloc/        # SearchBloc, NetworkCubit
    └── screens/     # SearchScreen, DetailScreen
test/
├── data/            # GifModel parsing
├── bloc/            # SearchBloc, NetworkCubit
└── widget_test.dart # SearchScreen states
```

- UI dispatches events and renders states; it never touches the network.
- `SearchBloc` depends on the repository, so it is tested with a mock.
- Connectivity is behind the `NetworkStatus` interface, so tests use a fake instead of the plugin.
- Screens do not import the router. They receive `onGifSelected` / `onBack` callbacks wired in
  `core/router.dart`, which is the only place that knows the routes.

## Tech stack

| Concern | Package |
| --- | --- |
| State management | `flutter_bloc`, `equatable` |
| Debounce | `rxdart` |
| Networking | `dio` |
| Connectivity | `connectivity_plus` |
| Navigation | `go_router` |
| Dependency injection | `get_it` |
| Images / layout | `cached_network_image`, `flutter_staggered_grid_view` |
| Video | `video_player` |
| Tests | `flutter_test`, `bloc_test`, `mocktail` |

## Getting started

1. Install the Flutter SDK.
2. Get a free API key from the [Giphy Developer Portal](https://developers.giphy.com/) (choose **API**).
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Provide the key at build time (never commit it):
   ```bash
   flutter run --dart-define=GIPHY_API_KEY=your_key
   ```
   In VS Code, put the key into `.vscode/launch.json` and press F5.
   The repository reads it from `AppConfig.giphyApiKey` (`lib/core/config.dart`).
5. Run the tests:
   ```bash
   flutter test
   ```

## Platform status

> Replace this section with what you actually verified, for example:
> *"Manually verified on Chrome (Flutter Web) and Android emulator (Pixel 6, API 34). Not tested on iOS."*

## Notes for the reviewer

### Design decisions
- **Pagination safety.** The scroll listener fires very often, so `SearchBloc` allows only one
  next-page request at a time, discards a page if the query changed while it loaded, filters
  duplicate ids, and keeps the existing results if a page request fails.
- **Platform behaviour.** Default page transitions are kept on purpose, so iOS keeps its swipe-back
  gesture and Android its native back handling.
- **Video.** The detail screen uses Giphy's MP4 rendition (much smaller than a GIF) and falls back to the
  GIF if no MP4 exists or playback fails.

### Trade-offs and known limitations
- **Grid previews are animated images.** Playing many videos at once is costly; for heavy use I would play
  MP4 only for the visible tiles.
- **API key.** Injected with `--dart-define`, so it is not in source control. It is still embedded in the
  compiled app; a production app should call Giphy through a small backend proxy.
- **Connectivity.** `connectivity_plus` reports whether a network interface exists, not whether the
  internet is reachable. Failed requests are still handled by the error state.
- **Localisation.** All UI text is in `core/strings.dart`, ready for ARB files; only English is shipped.
