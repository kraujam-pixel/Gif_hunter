/// Build-time configuration.
///
/// Secrets are injected with `--dart-define` instead of being committed:
///
///     flutter run --dart-define=GIPHY_API_KEY=your_key
/// Build-time configuration.
abstract final class AppConfig {
  static const String giphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY');
}