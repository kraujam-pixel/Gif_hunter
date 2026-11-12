import 'package:flutter_test/flutter_test.dart';
import 'package:gif_hunter/data/models/gif_model.dart';

Map<String, dynamic> _json({
  Object? title = '  Funny cat  ',
  Object? width = '200',
  Object? height = '150',
  bool withMp4 = true,
}) {
  return {
    'id': 'abc123',
    'title': title,
    'images': {
      'fixed_width': {
        'url': 'https://media.giphy.com/preview.gif',
        'width': width,
        'height': height,
      },
      'original': {
        'url': 'https://media.giphy.com/original.gif',
        if (withMp4) 'mp4': 'https://media.giphy.com/original.mp4',
      },
    },
  };
}

void main() {
  group('GifModel.fromJson', () {
    test('parses ids, urls and trims the title', () {
      final gif = GifModel.fromJson(_json());

      expect(gif.id, 'abc123');
      expect(gif.title, 'Funny cat');
      expect(gif.previewUrl, 'https://media.giphy.com/preview.gif');
      expect(gif.originalUrl, 'https://media.giphy.com/original.gif');
      expect(gif.videoUrl, 'https://media.giphy.com/original.mp4');
      expect(gif.heroTag, 'gif_abc123');
    });

    test('computes the aspect ratio from string dimensions', () {
      final gif = GifModel.fromJson(_json(width: '200', height: '100'));
      expect(gif.aspectRatio, closeTo(1.8, 0.001)); // 2.0 clamped to 1.8
      final normal = GifModel.fromJson(_json(width: '200', height: '150'));
      expect(normal.aspectRatio, closeTo(1.333, 0.01));
    });

    test('clamps very tall and very wide shapes', () {
      expect(
        GifModel.fromJson(_json(width: '100', height: '1000')).aspectRatio,
        0.6,
      );
      expect(
        GifModel.fromJson(_json(width: '1000', height: '100')).aspectRatio,
        1.8,
      );
    });

    test('falls back to a square when dimensions are missing or invalid', () {
      expect(
        GifModel.fromJson(_json(width: null, height: null)).aspectRatio,
        1.0,
      );
      expect(
        GifModel.fromJson(_json(width: 'abc', height: '0')).aspectRatio,
        1.0,
      );
    });

    test('uses an empty title when the API sends null', () {
      expect(GifModel.fromJson(_json(title: null)).title, '');
    });

    test('videoUrl is null when there is no mp4', () {
      expect(GifModel.fromJson(_json(withMp4: false)).videoUrl, isNull);
    });
  });
}
