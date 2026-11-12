/// All user-facing text in one place. Moving to ARB files / `flutter_localizations`
abstract final class AppStrings {
  static const String appName = 'GIF HUNTER';
  static const String tagline = 'FIND THE PERFECT REACTION';
  static const String searchHint = 'Search GIFs...';
  static const String clear = 'Clear';
  static const String back = 'Back';

  static const String discoverTitle = 'Start hunting';
  static const String discoverSubtitle = 'Type above or pick a popular search';

  static const String emptyTitle = 'No GIFs found';
  static const String emptyMessage = 'Try a different keyword.';

  static const String errorTitle = 'Something went wrong';
  static const String errorMessage =
      'Check your internet connection and try again.';
  static const String retry = 'Retry';

  static const String offlineBanner =
      "You’re offline — we’ll retry when you’re back online.";

  static const String copyLink = 'Copy link';
  static const String linkCopied = 'Link copied to clipboard';
  static const String untitled = 'Untitled GIF';
}
