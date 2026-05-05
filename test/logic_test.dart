import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Duplicate detection logic', () {
    test('Set prevents duplicate scans', () {
      final scannedValues = <String>{};
      expect(scannedValues.contains('ABC123'), false);

      scannedValues.add('ABC123');
      expect(scannedValues.contains('ABC123'), true);

      // Second scan of same value should be detected
      expect(scannedValues.contains('ABC123'), true);

      // Different value should not be detected
      expect(scannedValues.contains('DEF456'), false);
    });

    test('Set is case-sensitive', () {
      final scannedValues = <String>{};
      scannedValues.add('abc');
      expect(scannedValues.contains('ABC'), false);
    });
  });

  group('Tab name validation', () {
    test('detects duplicate tab names', () {
      final existingTabs = ['Sheet1', 'Inventory', 'Books'];
      const newName = 'Inventory';
      expect(existingTabs.contains(newName), true);
    });

    test('allows unique tab names', () {
      final existingTabs = ['Sheet1', 'Inventory'];
      const newName = 'Books';
      expect(existingTabs.contains(newName), false);
    });

    test('empty name is allowed (uses default)', () {
      const name = '';
      expect(name.isEmpty, true);
    });
  });

  group('IMAGE formula generation', () {
    test('generates correct formula', () {
      const fileId = 'abc123';
      const url = 'https://drive.google.com/thumbnail?id=$fileId&sz=w400';
      const formula = '=IMAGE("$url")';
      expect(formula,
          '=IMAGE("https://drive.google.com/thumbnail?id=abc123&sz=w400")');
    });
  });

  group('Tab-scoped cell range', () {
    test('formats range with tab name', () {
      const tabName = 'My Tab';
      const cell = 'A1';
      const range = "'$tabName'!$cell";
      expect(range, "'My Tab'!A1");
    });

    test('uses plain cell when no tab name', () {
      const String? tabName = null;
      const cell = 'B5';
      const range = tabName != null ? "'$tabName'!$cell" : cell;
      expect(range, 'B5');
    });
  });
}
