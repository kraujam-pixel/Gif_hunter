import 'package:dio/dio.dart';
import '../models/gif_model.dart';
import '../../core/config.dart';


class GiphyRepository {
  final Dio _dio;
  final String _apiKey = AppConfig.giphyApiKey;
  final int limit = 20;

  GiphyRepository(this._dio);

  Future<List<GifModel>> searchGifs(String query, int offset) async {
    if (query.isEmpty) return [];
    
    if (_apiKey.isEmpty) {
     throw StateError('GIPHY_API_KEY is missing');
   }

    try {
      final response = await _dio.get(
        'https://api.giphy.com/v1/gifs/search',
        queryParameters: {
          'api_key': _apiKey,
          'q': query,
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.statusCode == 200) {
        final List data = response.data['data'];
        return data.map((json) => GifModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load GIFs');
      }
    } catch (e) {
      throw Exception('Network error or API failure: $e');
    }
  }
}