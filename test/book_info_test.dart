import 'package:flutter_test/flutter_test.dart';
import 'package:qr_sheets_scanner/isbn_service.dart';

void main() {
  group('BookInfo', () {
    test('toRow includes all fields and box value', () {
      final book = BookInfo(
        isbn: '9780141439518',
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
        publisher: 'Penguin Books',
        year: '2003',
        pages: '435',
      );
      expect(book.toRow('Box 1'), [
        '9780141439518',
        'Pride and Prejudice',
        'Jane Austen',
        'Penguin Books',
        '2003',
        '435',
        'Box 1',
      ]);
    });

    test('toRow uses empty strings for missing fields', () {
      final book = BookInfo(isbn: '1234567890', title: 'Test Book');
      expect(book.toRow(''), [
        '1234567890',
        'Test Book',
        '',
        '',
        '',
        '',
        '',
      ]);
    });

    test('headers returns correct column names', () {
      expect(BookInfo.headers(), [
        'ISBN',
        'Title',
        'Author',
        'Publisher',
        'Year',
        'Pages',
        'Box',
      ]);
    });

    test('headers has 7 columns matching toRow length', () {
      final book = BookInfo(isbn: '123', title: 'Test');
      expect(BookInfo.headers().length, book.toRow('box').length);
    });
  });
}
