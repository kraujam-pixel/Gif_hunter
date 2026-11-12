import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:gif_hunter/presentation/bloc/network_cubit.dart';

import '../helpers/fake_network_status.dart';

void main() {
  blocTest<NetworkCubit, bool>(
    'stays online when the device starts online',
    build: () => NetworkCubit(FakeNetworkStatus()),
    wait: const Duration(milliseconds: 20),
    expect: () => <bool>[],
  );

  blocTest<NetworkCubit, bool>(
    'goes offline when the device starts offline',
    build: () => NetworkCubit(FakeNetworkStatus(initiallyOnline: false)),
    wait: const Duration(milliseconds: 20),
    expect: () => [false],
  );

  late FakeNetworkStatus status;
  blocTest<NetworkCubit, bool>(
    'follows connection changes',
    setUp: () => status = FakeNetworkStatus(),
    build: () => NetworkCubit(status),
    act: (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      status.emit(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      status.emit(true);
    },
    wait: const Duration(milliseconds: 20),
    expect: () => [false, true],
  );
}
