import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/network_status.dart';


/// Starts as online so the offline banner never flashes before the first
/// real check completes.
class NetworkCubit extends Cubit<bool> {
  NetworkCubit(this._networkStatus) : super(true) {
    _start();
  }

  final NetworkStatus _networkStatus;
  StreamSubscription<bool>? _subscription;

  Future<void> _start() async {
    try {
      final online = await _networkStatus.isOnline;
      if (isClosed) return;
      emit(online);
    } catch (_) {
      // Unknown state: keep assuming online; failed requests show the error UI.
    }
    if (isClosed) return;
    _subscription = _networkStatus.onStatusChanged.listen(
      (online) {
        if (!isClosed) emit(online);
      },
      onError: (Object _) {},
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
