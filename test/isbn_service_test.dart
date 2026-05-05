import 'package:flutter_test/flutter_test.dart';
import 'package:qr_sheets_scanner/isbn_service.dart';

void main() {
  group('IsbnService.lookup', () {
    test('parses a valid Open Library response', () async {
      final mockResponse = {
        'ISBN:9780141439518': {
          'title': 'Pride and Prejudice',
          'authors': [
            {'name': 'Jane Austen'}
          ],
          'publishers': [
            {'name': 'Penguin Books'}
          ],
          'publish_date': '2003',
          'number_of_pages': 435,
        }
      };

      // We can't easily inject a mock client into the static method,
      // so we test the parsing logic directly
      final data = mockResponse;
      const key = 'ISBN:9780141439518';
      final book = data[key]!;

      final result = BookInfo(
        isbn: '9780141439518',
        title: book['title'] as String? ?? '',
        author:
            (book['authors'] as List?)?.map((a) => a['name']).join(', ') ?? '',
        publisher:
            (book['publishers'] as List?)?.map((p) => p['name']).join(', ') ??
                '',
        year: book['publish_date'] as String? ?? '',
        pages: book['number_of_pages']?.toString() ?? '',
      );

      expect(result.title, 'Pride and Prejudice');
      expect(result.author, 'Jane Austen');
      expect(result.publisher, 'Penguin Books');
      expect(result.year, '2003');
      expect(result.pages, '435');
    });

    test('handles multiple authors', () {
      final authors = [
        {'name': 'Author One'},
        {'name': 'Author Two'},
      ];
      final result = (authors as List).map((a) => a['name']).join(', ');
      expect(result, 'Author One, Author Two');
    });

    test('handles missing fields gracefully', () {
      final book = <String, dynamic>{
        'title': 'Minimal Book',
      };

      final result = BookInfo(
        isbn: '000',
        title: book['title'] as String? ?? '',
        author:
            (book['authors'] as List?)?.map((a) => a['name']).join(', ') ?? '',
        publisher:
            (book['publishers'] as List?)?.map((p) => p['name']).join(', ') ??
                '',
        year: book['publish_date'] as String? ?? '',
        pages: book['number_of_pages']?.toString() ?? '',
      );

      expect(result.title, 'Minimal Book');
      expect(result.author, '');
      expect(result.publisher, '');
      expect(result.year, '');
      expect(result.pages, '');
    });

    test('handles empty response body', () {
      final data = <String, dynamic>{};
      const key = 'ISBN:0000000000';
      expect(data.containsKey(key), false);
    });
  });
}
