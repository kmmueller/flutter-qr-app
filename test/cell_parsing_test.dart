import 'package:flutter_test/flutter_test.dart';

/// Tests for cell parsing logic used in ScanPage and QrPhotoPage.
/// Extracted here since _parseCell is private — we replicate the logic.
void main() {
  (String, int) parseCell(String cell) {
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cell);
    if (match != null) {
      return (match.group(1)!.toUpperCase(), int.parse(match.group(2)!));
    }
    return ('A', 1);
  }

  group('parseCell', () {
    test('parses A1', () {
      final (col, row) = parseCell('A1');
      expect(col, 'A');
      expect(row, 1);
    });

    test('parses B10', () {
      final (col, row) = parseCell('B10');
      expect(col, 'B');
      expect(row, 10);
    });

    test('parses lowercase c5', () {
      final (col, row) = parseCell('c5');
      expect(col, 'C');
      expect(row, 5);
    });

    test('parses multi-letter column AA100', () {
      final (col, row) = parseCell('AA100');
      expect(col, 'AA');
      expect(row, 100);
    });

    test('returns default A1 for empty string', () {
      final (col, row) = parseCell('');
      expect(col, 'A');
      expect(row, 1);
    });

    test('returns default A1 for invalid input', () {
      final (col, row) = parseCell('123');
      expect(col, 'A');
      expect(row, 1);
    });

    test('returns default A1 for symbols', () {
      final (col, row) = parseCell('!@#');
      expect(col, 'A');
      expect(row, 1);
    });
  });

  group('nextColumn', () {
    String nextColumn(String col) {
      final chars = col.codeUnits.toList();
      int i = chars.length - 1;
      while (i >= 0) {
        if (chars[i] < 90) {
          chars[i]++;
          return String.fromCharCodes(chars);
        }
        chars[i] = 65;
        i--;
      }
      return 'A${String.fromCharCodes(chars)}';
    }

    test('A -> B', () => expect(nextColumn('A'), 'B'));
    test('Z -> AA', () => expect(nextColumn('Z'), 'AA'));
    test('AA -> AB', () => expect(nextColumn('AA'), 'AB'));
    test('AZ -> BA', () => expect(nextColumn('AZ'), 'BA'));
    test('M -> N', () => expect(nextColumn('M'), 'N'));
  });
}
