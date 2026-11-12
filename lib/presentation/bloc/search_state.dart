import 'package:equatable/equatable.dart';
import '../../data/models/gif_model.dart';

abstract class SearchState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<GifModel> gifs;
  final bool hasReachedMax;

  SearchSuccess({required this.gifs, this.hasReachedMax = false});

  @override
  List<Object?> get props => [gifs, hasReachedMax];
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);

  @override
  List<Object?> get props => [message];
}