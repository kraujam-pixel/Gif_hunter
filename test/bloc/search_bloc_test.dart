import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_hunter/data/models/gif_model.dart';
import 'package:gif_hunter/data/repositories/giphy_repository.dart';
import 'package:gif_hunter/presentation/bloc/search_bloc.dart';
import 'package:gif_hunter/presentation/bloc/search_event.dart';
import 'package:gif_hunter/presentation/bloc/search_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGiphyRepository extends Mock implements GiphyRepository {}

GifModel _gif(String id) => GifModel(
      id: id,
      title: 'GIF $id',
      previewUrl: 'https://example.com/$id-preview.gif',
      originalUrl: 'https://example.com/$id.gif',
    );

/// Longer than the bloc's 500 ms debounce.
const _afterDebounce = Duration(milliseconds: 600);

void main() {
  late MockGiphyRepository repository;

  setUp(() {
    repository = MockGiphyRepository();
    // A page holds 2 items, so a page with fewer than 2 means "last page".
    when(() => repository.limit).thenReturn(2);
  });

  test('starts in SearchInitial', () {
    final bloc = SearchBloc(repository);
    addTearDown(bloc.close);
    expect(bloc.state, isA<SearchInitial>());
  });

  group('searching', () {
    blocTest<SearchBloc, SearchState>(
      'emits loading then success with the results',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) => bloc.add(SearchQueryChanged('cats')),
      wait: _afterDebounce,
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>()
            .having((s) => s.gifs.length, 'gifs', 2)
            .having((s) => s.hasReachedMax, 'hasReachedMax', false),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'marks the end of the results when a page is not full',
      setUp: () {
        when(() => repository.searchGifs('rare', 0))
            .thenAnswer((_) async => [_gif('1')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) => bloc.add(SearchQueryChanged('rare')),
      wait: _afterDebounce,
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.hasReachedMax, 'max', true),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'debounces fast typing: only the last query hits the API',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('c'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(SearchQueryChanged('ca'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(SearchQueryChanged('cats'));
      },
      wait: _afterDebounce,
      verify: (_) {
        verify(() => repository.searchGifs('cats', 0)).called(1);
        verifyNever(() => repository.searchGifs('c', 0));
        verifyNever(() => repository.searchGifs('ca', 0));
      },
    );

    test('a blank query does not call the API', () async {
      final bloc = SearchBloc(repository);
      addTearDown(bloc.close);

      bloc.add(SearchQueryChanged('   '));
      await Future<void>.delayed(_afterDebounce);

      expect(bloc.state, isA<SearchInitial>());
      verifyNever(() => repository.searchGifs(any(), any()));
    });

    blocTest<SearchBloc, SearchState>(
      'emits loading then error when the request fails',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => throw Exception('boom'));
      },
      build: () => SearchBloc(repository),
      act: (bloc) => bloc.add(SearchQueryChanged('cats')),
      wait: _afterDebounce,
      expect: () => [isA<SearchLoading>(), isA<SearchError>()],
    );
  });

  group('pagination', () {
    blocTest<SearchBloc, SearchState>(
      'appends the next page to the existing results',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
        when(() => repository.searchGifs('cats', 2))
            .thenAnswer((_) async => [_gif('3'), _gif('4')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('cats'));
        await Future<void>.delayed(_afterDebounce);
        bloc.add(LoadNextPage());
      },
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>().having((s) => s.gifs.length, 'first page', 2),
        isA<SearchSuccess>()
            .having((s) => s.gifs.map((g) => g.id).toList(), 'ids',
                ['1', '2', '3', '4']),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'drops duplicate gifs returned on the next page',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
        when(() => repository.searchGifs('cats', 2))
            .thenAnswer((_) async => [_gif('2'), _gif('3')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('cats'));
        await Future<void>.delayed(_afterDebounce);
        bloc.add(LoadNextPage());
      },
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>(),
        isA<SearchSuccess>()
            .having((s) => s.gifs.map((g) => g.id).toList(), 'ids',
                ['1', '2', '3']),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'does not request more once the end was reached',
      setUp: () {
        when(() => repository.searchGifs('rare', 0))
            .thenAnswer((_) async => [_gif('1')]);
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('rare'));
        await Future<void>.delayed(_afterDebounce);
        bloc.add(LoadNextPage());
      },
      wait: const Duration(milliseconds: 200),
      verify: (_) {
        verifyNever(() => repository.searchGifs('rare', 2));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'ignores repeated scroll events while a page is loading',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
        when(() => repository.searchGifs('cats', 2)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return [_gif('3'), _gif('4')];
        });
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('cats'));
        await Future<void>.delayed(_afterDebounce);
        bloc
          ..add(LoadNextPage())
          ..add(LoadNextPage())
          ..add(LoadNextPage());
      },
      wait: const Duration(milliseconds: 300),
      verify: (_) {
        verify(() => repository.searchGifs('cats', 2)).called(1);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'keeps the current results when the next page fails',
      setUp: () {
        when(() => repository.searchGifs('cats', 0))
            .thenAnswer((_) async => [_gif('1'), _gif('2')]);
        when(() => repository.searchGifs('cats', 2))
            .thenAnswer((_) async => throw Exception('offline'));
      },
      build: () => SearchBloc(repository),
      act: (bloc) async {
        bloc.add(SearchQueryChanged('cats'));
        await Future<void>.delayed(_afterDebounce);
        bloc.add(LoadNextPage());
      },
      wait: const Duration(milliseconds: 200),
      // No SearchError after the first page: the grid stays on screen.
      expect: () => [isA<SearchLoading>(), isA<SearchSuccess>()],
    );
  });
}
