/// Scanner page for ISBN and Basic scan modes.
/// Uses mobile_scanner to detect barcodes/QR codes via the camera.
/// ISBN mode: looks up book metadata via Open Library, writes multi-column rows.
/// Basic mode: writes scanned values to a single column.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_service.dart';
import 'isbn_service.dart';

class ScanPage extends StatefulWidget {
  final String sheetId;
  final String sheetName;
  final String startCell;
  final bool isbnMode;
  final String? tabName;

  const ScanPage({
    super.key,
    required this.sheetId,
    required this.sheetName,
    required this.startCell,
    this.isbnMode = false,
    this.tabName,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final MobileScannerController _cameraController;
  late String _column; // Current column letter (e.g. "A")
  late int _currentRow; // Next row to write to
  int _scanCount = 0;
  String _status = 'Tap Scan to begin';
  bool _scanning = false; // True when actively looking for a barcode
  bool _processing = false; // True when saving a scan result
  final Set<String> _scannedValues = {}; // Duplicate detection within session
  final TextEditingController _boxController = TextEditingController();
  static const _boxKey = 'isbn_box_value';

  @override
  void initState() {
    super.initState();
    _cameraController =
        MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    _parseCell(widget.startCell);
    if (widget.isbnMode) {
      _loadBoxValue();
      _writeHeaders();
    }
  }

  /// Loads the persisted box value from SharedPreferences.
  Future<void> _loadBoxValue() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_boxKey) ?? '';
    _boxController.text = saved;
  }

  /// Saves the current box value to SharedPreferences.
  Future<void> _saveBoxValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boxKey, _boxController.text.trim());
  }

  /// Parses a cell reference like "B5" into column ("B") and row (5).
  void _parseCell(String cell) {
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(cell);
    if (match != null) {
      _column = match.group(1)!.toUpperCase();
      _currentRow = int.parse(match.group(2)!);
    } else {
      _column = 'A';
      _currentRow = 1;
    }
  }

  /// Writes the ISBN header row only if one doesn't already exist in the tab.
  Future<void> _writeHeaders() async {
    try {
      // Always check the first row of this column for existing headers
      final existing = await GoogleService.readRow(
        widget.sheetId,
        '${_column}1',
        tabName: widget.tabName,
      );
      if (existing.isNotEmpty && existing.first == 'ISBN') {
        return;
      }
      await GoogleService.writeRow(
        widget.sheetId,
        '$_column$_currentRow',
        BookInfo.headers(),
        tabName: widget.tabName,
      );
      _currentRow++;
    } catch (e) {
      if (mounted) setState(() => _status = 'Error writing headers: $e');
    }
  }

  /// Called by mobile_scanner when a barcode is detected. Enforces one-scan-per-press.
  void _onDetect(BarcodeCapture capture) {
    if (!_scanning || _processing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;

    if (_scannedValues.contains(value)) {
      setState(() => _status = 'Duplicate skipped: $value');
      return;
    }

    _scanning = false;
    _processing = true;
    _beepAndVibrate();

    if (widget.isbnMode) {
      _handleIsbn(value);
    } else {
      setState(() => _status = 'Saving: $value');
      _saveToSheet(value);
    }
  }

  /// Looks up the ISBN online, prompts for manual title if not found, writes the row.
  Future<void> _handleIsbn(String isbn) async {
    setState(() => _status = 'Looking up ISBN: $isbn');

    BookInfo? book = await IsbnService.lookup(isbn);

    // If not found or no title, ask the user to enter title and pages manually
    if (book == null || book.title.isEmpty) {
      if (!mounted) return;
      final result = await _promptForManualEntry(isbn);
      if (result == null) {
        setState(() => _status = 'Skipped: $isbn');
        _processing = false;
        return;
      }
      book = BookInfo(isbn: isbn, title: result.$1, pages: result.$2);
    }

    try {
      await GoogleService.writeRow(
        widget.sheetId,
        '$_column$_currentRow',
        book.toRow(_boxController.text.trim()),
        tabName: widget.tabName,
      );
      _scannedValues.add(isbn);
      _currentRow++;
      _scanCount++;
      if (mounted) setState(() => _status = 'Last: ${book!.title}');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
    _processing = false;
  }

  /// Dialog for manual title and pages entry when ISBN lookup fails.
  /// Returns a (title, pages) record, or null if skipped.
  Future<(String, String)?> _promptForManualEntry(String isbn) async {
    final titleController = TextEditingController();
    final pagesController = TextEditingController();
    return showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Book not found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No data found for ISBN: $isbn'),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Enter book title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pagesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Enter number of pages'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx, (title, pagesController.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Prompts the user to type an ISBN manually, then processes it.
  Future<void> _manualIsbn() async {
    final controller = TextEditingController();
    final isbn = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter ISBN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ISBN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Look Up'),
          ),
        ],
      ),
    );
    if (isbn == null || isbn.isEmpty) return;
    if (_scannedValues.contains(isbn)) {
      setState(() => _status = 'Duplicate skipped: $isbn');
      return;
    }
    _processing = true;
    _beepAndVibrate();
    _handleIsbn(isbn);
  }

  /// Plays a click sound and triggers haptic feedback on successful scan.
  void _beepAndVibrate() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }

  /// Writes a single scanned value to the sheet (Basic mode).
  Future<void> _saveToSheet(String value) async {
    try {
      await GoogleService.writeCell(
          widget.sheetId, '$_column$_currentRow', value,
          tabName: widget.tabName);
      _scannedValues.add(value);
      _currentRow++;
      _scanCount++;
      if (mounted) setState(() => _status = 'Last: $value');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
    _processing = false;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _boxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isbnMode ? '${widget.sheetName} (ISBN)' : widget.sheetName),
        actions: [
          IconButton(
            onPressed: () => SystemNavigator.pop(),
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview — always visible
          Expanded(
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),
          // Bottom panel with controls and status
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  '${widget.sheetName} — Row $_currentRow',
                  style: const TextStyle(fontSize: 13),
                ),
                // Box field — only shown in ISBN mode, persists across scans
                if (widget.isbnMode) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _boxController,
                    onChanged: (_) => _saveBoxValue(),
                    decoration: const InputDecoration(
                      labelText: 'Box',
                      hintText: 'Enter box value',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Scan and Manual ISBN buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _processing
                          ? null
                          : () => setState(() {
                                _scanning = true;
                                _status = 'Point camera at a code...';
                              }),
                      child: const Text('Scan', style: TextStyle(fontSize: 18)),
                    ),
                    if (widget.isbnMode) ...[
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _processing ? null : _manualIsbn,
                        child: const Text('Manual ISBN',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(_status,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Scans: $_scanCount',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
