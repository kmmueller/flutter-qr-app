/// Sheet picker page — handles the multi-step setup flow:
/// 1. Choose or create a Sheets document
/// 2. Choose or create a tab within the document
/// 3. Select scan mode (ISBN, QR+Photo, or Basic)
/// 4. Set the starting cell (auto-detected for existing tabs)
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'google_service.dart';
import 'scan_page.dart';
import 'qr_photo_page.dart';

/// The three scanning modes available in the app.
enum ScanMode { basic, isbn, qrPhoto }

class SheetPickerPage extends StatefulWidget {
  const SheetPickerPage({super.key});

  @override
  State<SheetPickerPage> createState() => _SheetPickerPageState();
}

class _SheetPickerPageState extends State<SheetPickerPage> {
  List<SpreadsheetInfo>? _sheets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches the user's spreadsheets from Google Drive.
  Future<void> _load() async {
    try {
      final sheets = await GoogleService.listSpreadsheets();
      if (mounted) setState(() => _sheets = sheets);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Fetches tabs for the selected spreadsheet, then shows the tab chooser.
  void _onSelect(SpreadsheetInfo sheet) async {
    List<SheetTab> tabs;
    try {
      tabs = await GoogleService.getSheetTabs(sheet.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }
    if (!mounted) return;
    _showTabChooser(sheet, tabs);
  }

  /// Dialog listing existing tabs and an option to create a new one.
  void _showTabChooser(SpreadsheetInfo sheet, List<SheetTab> tabs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose a Tab'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ...tabs.map((tab) => ListTile(
                    title: Text(tab.title),
                    subtitle: const Text('Use existing tab'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _useExistingTab(sheet, tab);
                    },
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create new tab'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNewTabDialog(sheet, tabs.map((t) => t.title).toList());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  /// Proceeds with an existing tab — will auto-find the first empty row.
  void _useExistingTab(SpreadsheetInfo sheet, SheetTab tab) {
    _showModePicker(sheet, tab.title, tab.gid, true);
  }

  /// Dialog to name a new tab. Validates against existing tab names to prevent duplicates.
  void _showNewTabDialog(SpreadsheetInfo sheet, List<String> existingNames,
      {String? errorMsg}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    Text(errorMsg, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Tab name (optional)',
                hintText: 'Leave blank for default',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(ctx);
              if (name.isNotEmpty && existingNames.contains(name)) {
                _showNewTabDialog(sheet, existingNames,
                    errorMsg: 'Tab "$name" already exists.');
              } else {
                _createNewTab(sheet, name.isEmpty ? null : name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Creates a new tab via the Sheets API, then proceeds to mode selection.
  Future<void> _createNewTab(SpreadsheetInfo sheet, String? tabName) async {
    try {
      final gid = await GoogleService.addSheet(sheet.id, tabName);
      // Re-fetch tabs to get the actual name assigned by Sheets
      final tabs = await GoogleService.getSheetTabs(sheet.id);
      final actualName = tabs.firstWhere((t) => t.gid == gid).title;
      if (!mounted) return;
      _showModePicker(sheet, actualName, gid, false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error creating tab: $e')));
      }
    }
  }

  /// Scan mode selection dialog (ISBN, QR+Photo, or Basic).
  void _showModePicker(
      SpreadsheetInfo sheet, String tabName, int gid, bool isExisting) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Mode'),
        content: const Text('What are you scanning?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _prepareAndLaunch(sheet, ScanMode.isbn, tabName, gid, isExisting);
            },
            child: const Text('ISBN Books'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _prepareAndLaunch(
                  sheet, ScanMode.qrPhoto, tabName, gid, isExisting);
            },
            child: const Text('QR Codes + Photos'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _prepareAndLaunch(
                  sheet, ScanMode.basic, tabName, gid, isExisting);
            },
            child: const Text('Basic Scan'),
          ),
        ],
      ),
    );
  }

  /// For existing tabs, auto-finds the first empty row. For new tabs, shows cell picker.
  Future<void> _prepareAndLaunch(SpreadsheetInfo sheet, ScanMode mode,
      String tabName, int gid, bool isExisting) async {
    if (isExisting) {
      final row = await GoogleService.getFirstEmptyRow(sheet.id, tabName, 'A');
      final cell = 'A$row';
      if (!mounted) return;
      _launchScanner(sheet, mode, tabName, gid, cell);
    } else {
      _showCellPicker(sheet, mode, tabName, gid);
    }
  }

  /// Dialog for the user to specify which cell to start scanning from.
  void _showCellPicker(
      SpreadsheetInfo sheet, ScanMode mode, String tabName, int gid) {
    final controller = TextEditingController(text: 'A1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tab: $tabName'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Start cell',
            hintText: 'e.g. A1',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final cell = controller.text.trim().isEmpty
                  ? 'A1'
                  : controller.text.trim();
              _launchScanner(sheet, mode, tabName, gid, cell);
            },
            child: const Text('Start Scanning'),
          ),
        ],
      ),
    );
  }

  /// Navigates to the appropriate scanner page based on the selected mode.
  void _launchScanner(SpreadsheetInfo sheet, ScanMode mode, String tabName,
      int gid, String cell) {
    if (mode == ScanMode.qrPhoto) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QrPhotoPage(
              sheetId: sheet.id,
              sheetName: sheet.name,
              startCell: cell,
              tabName: tabName,
              sheetGid: gid,
            ),
          ));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanPage(
              sheetId: sheet.id,
              sheetName: sheet.name,
              startCell: cell,
              isbnMode: mode == ScanMode.isbn,
              tabName: tabName,
            ),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Sheets Document'),
        actions: [
          IconButton(
            onPressed: () => SystemNavigator.pop(),
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Error: $_error'))
          : _sheets == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _sheets!.length + 1,
                  itemBuilder: (_, i) {
                    // First item is the "Create new document" option
                    if (i == 0) {
                      return ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create new document'),
                        onTap: _createNewDoc,
                      );
                    }
                    final sheet = _sheets![i - 1];
                    return ListTile(
                      title: Text(sheet.name),
                      onTap: () => _onSelect(sheet),
                    );
                  },
                ),
    );
  }

  /// Dialog to create a new Google Sheets document with a custom name.
  void _createNewDoc() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Sheets Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'e.g. My Inventory',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final sheet = await GoogleService.createSpreadsheet(name);
                if (mounted) _onSelect(sheet);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
