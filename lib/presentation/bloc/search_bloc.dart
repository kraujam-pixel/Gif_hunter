import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/repositories/giphy_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Debounces rapid events and cancels the previous handler when a new one
/// arrives.
EventTransformer<T> debounce<T>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final GiphyRepository repository;

  String _currentQuery = '';
  int _currentOffset = 0;

  /// The scroll listener can fire dozens of times per second. This flag makes
  /// sure only one next-page request is in flight at a time.
  bool _isFetchingNextPage = false;

  SearchBloc(this.repository) : super(SearchInitial()) {
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounce(const Duration(milliseconds: 500)),
    );
    on<LoadNextPage>(_onLoadNextPage);
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      _currentQuery = '';
      emit(SearchInitial());
      return;
    }

    _currentQuery = query;
    _currentOffset = 0;
    emit(SearchLoading());

    try {
      final gifs = await repository.searchGifs(query, _currentOffset);
      emit(SearchSuccess(
        gifs: gifs,
        hasReachedMax: gifs.length < repository.limit,
      ));
    } catch (e) {
      debugPrint('Search failed: $e');
      emit(SearchError(e.toString()));
    }
  }

  Future<void> _onLoadNextPage(
    LoadNextPage event,
    Emitter<SearchState> emit,
  ) async {
    final currentState = state;
    if (_isFetchingNextPage ||
        currentState is! SearchSuccess ||
        currentState.hasReachedMax) {
      return;
    }

    _isFetchingNextPage = true;
    final query = _currentQuery;
    final nextOffset = _currentOffset + repository.limit;

    try {
      final nextGifs = await repository.searchGifs(query, nextOffset);

      // The user searched for something else while this page was loading.
      if (query != _currentQuery) return;

      _currentOffset = nextOffset;

      // Duplicate ids would also clash as Hero tags.
      final knownIds = currentState.gifs.map((g) => g.id).toSet();
      final fresh = nextGifs.where((g) => !knownIds.contains(g.id)).toList();

      emit(SearchSuccess(
        gifs: [...currentState.gifs, ...fresh],
        hasReachedMax: nextGifs.length < repository.limit,
      ));
    } catch (e) {
      debugPrint('Loading next page failed: $e');
      // Keep the results already on screen instead of replacing the whole grid
      // with an error. The next scroll near the bottom retries automatically.
    } finally {
      _isFetchingNextPage = false;
    }
  }
}
