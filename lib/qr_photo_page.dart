/// QR+Photo scan mode page.
/// Flow: scan QR code → take photo → enter description → upload to Drive → write to Sheets.
/// Uploads photos to a "QR_Scan_Thumbs" Drive folder and writes =IMAGE() formulas.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'google_service.dart';

class QrPhotoPage extends StatefulWidget {
  final String sheetId;
  final String sheetName;
  final String startCell;
  final String? tabName;
  final int? sheetGid;

  const QrPhotoPage({
    super.key,
    required this.sheetId,
    required this.sheetName,
    required this.startCell,
    this.tabName,
    this.sheetGid,
  });

  @override
  State<QrPhotoPage> createState() => _QrPhotoPageState();
}

/// Tracks the current step in the QR+Photo workflow.
enum _Step { ready, scanning, photo, describe, saving }

class _QrPhotoPageState extends State<QrPhotoPage> {
  late final MobileScannerController _cameraController;
  late String _column;
  late int _currentRow;
  int _scanCount = 0;
  String _status = 'Tap Scan to begin';
  _Step _step = _Step.ready;
  final Set<String> _scannedValues = {}; // Duplicate detection
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _currentQr; // QR value for the current scan cycle
  Uint8List? _photoBytes; // Captured photo bytes for upload

  int? _sheetGid;

  @override
  void initState() {
    super.initState();
    _cameraController =
        MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    _parseCell(widget.startCell);
    _sheetGid = widget.sheetGid;
    _init();
  }

  /// Resolves the sheet GID if not provided, then writes the header row.
  Future<void> _init() async {
    _sheetGid ??= await GoogleService.getSheetGid(widget.sheetId);
    await _writeHeaders();
  }

  /// Parses a cell reference like "B5" into column and row.
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

  /// Writes the QR+Photo header row (QR Code, Description, Thumbnail).
  Future<void> _writeHeaders() async {
    try {
      await GoogleService.writeRow(
        widget.sheetId,
        '$_column$_currentRow',
        ['QR Code', 'Description', 'Thumbnail'],
        tabName: widget.tabName,
      );
      _currentRow++;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _status = 'Error writing headers: $e');
    }
  }

  /// Called when a QR code is detected. Advances to the photo step.
  void _onDetect(BarcodeCapture capture) {
    if (_step != _Step.scanning) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;

    if (_scannedValues.contains(value)) {
      setState(() => _status = 'Duplicate skipped: $value');
      return;
    }

    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();

    setState(() {
      _currentQr = value;
      _step = _Step.photo;
      _status = 'QR: $value\nTap "Take Photo"';
    });
  }

  /// Opens the camera to take a photo, then advances to the description step.
  Future<void> _takePhoto() async {
    final xfile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _step = _Step.describe;
      _status = 'Enter description, then tap Save';
    });
  }

  /// Uploads the photo to Drive, writes the row to Sheets, resizes the row for the thumbnail.
  Future<void> _saveEntry() async {
    final description = _descController.text.trim();
    _descController.clear();

    setState(() {
      _step = _Step.saving;
      _status = 'Uploading...';
    });

    try {
      String thumbnailFormula = '';
      if (_photoBytes != null) {
        // Upload to QR_Scan_Thumbs folder and build =IMAGE() formula
        final fileId = await GoogleService.uploadImage(
          _photoBytes!,
          'qr_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final url = GoogleService.thumbnailUrl(fileId);
        thumbnailFormula = '=IMAGE("$url")';
      }

      // Write QR value, description, and thumbnail formula as a row
      await GoogleService.writeRow(
        widget.sheetId,
        '$_column$_currentRow',
        [_currentQr!, description, thumbnailFormula],
        tabName: widget.tabName,
      );

      // Resize row to 150px so the thumbnail is visible
      if (_sheetGid != null && thumbnailFormula.isNotEmpty) {
        await GoogleService.setRowHeight(
            widget.sheetId, _sheetGid!, _currentRow, 150);
      }

      _scannedValues.add(_currentQr!);
      _currentRow++;
      _scanCount++;

      setState(() {
        _step = _Step.ready;
        _status = 'Saved! Tap Scan for next';
        _currentQr = null;
        _photoBytes = null;
      });
    } catch (e) {
      setState(() {
        _step = _Step.ready;
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sheetName} (QR+Photo)'),
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
          // Show photo preview after capture, otherwise show camera feed
          Expanded(
            child: _photoBytes != null
                ? Image.memory(_photoBytes!, fit: BoxFit.contain)
                : MobileScanner(
                    controller: _cameraController,
                    onDetect: _onDetect,
                  ),
          ),
          // Bottom panel — buttons change based on current workflow step
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status message at top so it's visible above navigation bar
                Text(_status,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Row $_currentRow — Scans: $_scanCount',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                if (_step == _Step.ready)
                  ElevatedButton(
                    onPressed: () {
                      SystemSound.play(SystemSoundType.click);
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _step = _Step.scanning;
                        _status = 'Point camera at a QR code...';
                      });
                    },
                    child: const Text('Scan', style: TextStyle(fontSize: 18)),
                  ),
                if (_step == _Step.photo)
                  ElevatedButton(
                    onPressed: _takePhoto,
                    child: const Text('Take Photo',
                        style: TextStyle(fontSize: 18)),
                  ),
                if (_step == _Step.describe) ...[
                  TextField(
                    controller: _descController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _saveEntry,
                    child: const Text('Save', style: TextStyle(fontSize: 18)),
                  ),
                ],
                if (_step == _Step.saving) const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
