# GIF Hunter

A responsive Flutter app for searching GIFs with the [Giphy API](https://developers.giphy.com/docs/api/).
Built as a technical assignment for Chili Labs.

## Flutter version

> **Flutter 3.47.9 (stable) · Dart 3.13.7** ← replace with the output of `flutter --version`

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
- **Detail screen** that plays the lightweight MP4 on Android/iOS (muted, looping, tap to pause) and the
  GIF on web or when no MP4 exists, blurred backdrop, and a *Copy link* action.
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

| Target | Status |
| --- | --- |
| Android (Android Studio emulator) | Verified: search, pagination, detail view, rotation, offline banner |
| Flutter Web (Chrome) | Runs, with one known rendering issue (see below) |
| iOS | Not tested (developed on Windows, no Mac available). The code uses no platform-specific APIs. |

### Known issue: Flutter Web (Chrome)

After opening a GIF and returning, grid tiles that were already on screen can turn black until they are
scrolled out of view and back. The browser console shows `WebGL: INVALID_VALUE: texImage2D: no image`
(the CanvasKit renderer). It does **not** happen on the Android emulator.

What I tried, as the brief asks:
- Playing the MP4 only on Android/iOS and the GIF on web (no `<video>` platform view): no change.
- Turning off the snapshot in the page transition: no change.
- Static first frames instead of animated GIFs in the grid: no change (so I reverted it).
- Removing the blur backdrop and glass panel on web: no change (so I reverted it).
- Smaller grid GIFs (`fixed_width_downsampled`) decoded at tile size: kept, it lowers memory use.

Since the target platforms are Android and iOS, I left the web behaviour as is.

## Notes for the reviewer

### Design decisions
- **Pagination safety.** The scroll listener fires very often, so `SearchBloc` allows only one
  next-page request at a time, discards a page if the query changed while it loaded, filters
  duplicate ids, and keeps the existing results if a page request fails.
- **Platform behaviour.** Page transitions are the platform ones (Cupertino on iOS, so swipe-back works;
  Zoom elsewhere), and the back icon and progress indicator adapt to the platform.
- **Video.** On Android/iOS the detail screen uses Giphy's MP4 rendition (much smaller than a GIF) and
  falls back to the GIF if no MP4 exists or playback fails. On Flutter Web it shows the GIF.

### Trade-offs and known limitations
- **Grid previews are animated images.** Playing many videos at once is costly; for heavy use I would play
  MP4 only for the visible tiles.
- **API key.** Injected with `--dart-define` (the committed default in `lib/core/config.dart` is empty),
  so no key is in source control. It is still embedded in the
  compiled app; a production app should call Giphy through a small backend proxy.
- **Connectivity.** `connectivity_plus` reports whether a network interface exists, not whether the
  internet is reachable. Failed requests are still handled by the error state.
- **Localisation.** All UI text is in `core/strings.dart`, ready for ARB files; only English is shipped.