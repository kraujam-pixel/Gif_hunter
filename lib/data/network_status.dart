import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraction over the device's network state, so the UI and tests do not
/// depend on the connectivity plugin directly.
abstract class NetworkStatus {
  /// Whether the device currently has any network connection.
  Future<bool> get isOnline;

  /// Emits whenever the connection is gained or lost.
  Stream<bool> get onStatusChanged;
}

/// [NetworkStatus] backed by `connectivity_plus`.
class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
}
