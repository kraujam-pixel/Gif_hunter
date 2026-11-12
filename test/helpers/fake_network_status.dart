import 'dart:async';

import 'package:gif_hunter/data/network_status.dart';

/// Test double for [NetworkStatus]: set the initial state and push changes.
class FakeNetworkStatus implements NetworkStatus {
  FakeNetworkStatus({this.initiallyOnline = true});

  final bool initiallyOnline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  void emit(bool online) => _controller.add(online);

  @override
  Future<bool> get isOnline async => initiallyOnline;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;
}
