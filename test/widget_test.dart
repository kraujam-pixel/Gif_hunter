import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_hunter/core/di.dart';
import 'package:gif_hunter/core/theme.dart';
import 'package:gif_hunter/data/repositories/giphy_repository.dart';
import 'package:gif_hunter/presentation/bloc/search_bloc.dart';
import 'package:gif_hunter/presentation/screens/search_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/fake_network_status.dart';

class MockGiphyRepository extends Mock implements GiphyRepository {}

void main() {
  late MockGiphyRepository repository;

  setUp(() async {
    await getIt.reset();
    repository = MockGiphyRepository();
    when(() => repository.limit).thenReturn(2);
    getIt.registerFactory<SearchBloc>(() => SearchBloc(repository));
  });

  tearDown(() async => getIt.reset());

  Widget app({bool online = true}) => MaterialApp(
        theme: buildAppTheme(),
        home: SearchScreen(
          onGifSelected: (_, _) {},
          networkStatus: FakeNetworkStatus(initiallyOnline: online),
        ),
      );

  testWidgets('shows the logo and popular searches at start', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('GIF HUNTER'), findsOneWidget);
    expect(find.text('Start hunting'), findsOneWidget);
    expect(find.text('cats'), findsOneWidget);
  });

  testWidgets('shows an error with a Retry button when the request fails',
      (tester) async {
    when(() => repository.searchGifs('cats', 0))
        .thenAnswer((_) async => throw Exception('boom'));

    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField), 'cats');
    await tester.pump(const Duration(milliseconds: 600)); // debounce
    await tester.pump(); // result

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a message when nothing is found', (tester) async {
    when(() => repository.searchGifs('zzzz', 0)).thenAnswer((_) async => []);

    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('No GIFs found'), findsOneWidget);
  });

  testWidgets('shows the offline banner when there is no connection',
      (tester) async {
    await tester.pumpWidget(app(online: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('offline'), findsOneWidget);
  });
}
