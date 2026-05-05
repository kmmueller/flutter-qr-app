import 'package:flutter_test/flutter_test.dart';
import 'package:qr_sheets_scanner/google_service.dart';

void main() {
  group('GoogleService.thumbnailUrl', () {
    test('generates correct URL with file ID', () {
      final url = GoogleService.thumbnailUrl('abc123');
      expect(url, 'https://drive.google.com/thumbnail?id=abc123&sz=w400');
    });

    test('handles special characters in file ID', () {
      final url = GoogleService.thumbnailUrl('a-b_c');
      expect(url, contains('a-b_c'));
    });
  });

  group('SpreadsheetInfo', () {
    test('stores id and name', () {
      final info = SpreadsheetInfo('id123', 'My Sheet');
      expect(info.id, 'id123');
      expect(info.name, 'My Sheet');
    });
  });

  group('SheetTab', () {
    test('stores gid and title', () {
      final tab = SheetTab(42, 'Sheet1');
      expect(tab.gid, 42);
      expect(tab.title, 'Sheet1');
    });
  });
}
