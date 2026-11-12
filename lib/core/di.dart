import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../data/repositories/giphy_repository.dart';
import '../presentation/bloc/search_bloc.dart';

final getIt = GetIt.instance;

void setupDI() {
  // Client
  getIt.registerLazySingleton<Dio>(() => Dio());
  
  // Repository 
  getIt.registerLazySingleton<GiphyRepository>(
    () => GiphyRepository(getIt<Dio>()),
  );
  
  // BLoC (Factory, to create a new instance each time it's needed)
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(getIt<GiphyRepository>()),
  );
}