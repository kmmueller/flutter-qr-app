/// Central service for all Google API interactions.
/// Handles authentication, Google Sheets operations, and Google Drive operations.
library;
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';

class GoogleService {
  // ── Authentication ──────────────────────────────────────────────────

  /// Google Sign-In instance configured with Sheets and Drive scopes.
  static final _googleSignIn = GoogleSignIn(scopes: [
    sheets.SheetsApi.spreadsheetsScope,
    drive.DriveApi.driveScope,
  ]);

  /// The currently signed-in Google account, or null if not signed in.
  static GoogleSignInAccount? currentUser;

  /// Authenticated HTTP client for making API calls.
  static AuthClient? _authClient;

  /// Signs in with Google and obtains an authenticated API client.
  /// Returns true on success, false on failure or cancellation.
  static Future<bool> signIn() async {
    currentUser = await _googleSignIn.signIn();
    if (currentUser != null) {
      _authClient = await _googleSignIn.authenticatedClient();
    }
    return currentUser != null;
  }

  /// Signs out and clears cached credentials.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    currentUser = null;
    _authClient = null;
  }

  // ── Drive: Spreadsheet Listing & Creation ───────────────────────────

  /// Lists the user's Google Sheets documents, sorted by most recently modified.
  static Future<List<SpreadsheetInfo>> listSpreadsheets() async {
    final driveApi = drive.DriveApi(_authClient!);
    final result = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
      orderBy: 'modifiedTime desc',
      pageSize: 50,
      $fields: 'files(id,name)',
    );
    return result.files?.map((f) => SpreadsheetInfo(f.id!, f.name!)).toList() ??
        [];
  }

  /// Creates a new Google Sheets document with the given name.
  static Future<SpreadsheetInfo> createSpreadsheet(String name) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final ss = await sheetsApi.spreadsheets.create(
      sheets.Spreadsheet(properties: sheets.SpreadsheetProperties(title: name)),
    );
    return SpreadsheetInfo(ss.spreadsheetId!, name);
  }

  // ── Sheets: Reading & Writing ───────────────────────────────────────

  /// Writes a single value to a specific cell.
  /// If [tabName] is provided, targets that specific sheet tab.
  static Future<void> writeCell(String spreadsheetId, String cell, String value,
      {String? tabName}) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final range = tabName != null ? "'$tabName'!$cell" : cell;
    final body = sheets.ValueRange(values: [
      [value]
    ]);
    await sheetsApi.spreadsheets.values.update(
      body,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Writes a list of values as a single row starting at [startCell].
  /// If [tabName] is provided, targets that specific sheet tab.
  static Future<void> writeRow(
      String spreadsheetId, String startCell, List<String> values,
      {String? tabName}) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final range = tabName != null ? "'$tabName'!$startCell" : startCell;
    final body = sheets.ValueRange(values: [values]);
    await sheetsApi.spreadsheets.values.update(
      body,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Sets the pixel height of a specific row (used for thumbnail visibility).
  static Future<void> setRowHeight(
      String spreadsheetId, int sheetGid, int row, int height) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final request = sheets.BatchUpdateSpreadsheetRequest(requests: [
      sheets.Request(
        updateDimensionProperties: sheets.UpdateDimensionPropertiesRequest(
          range: sheets.DimensionRange(
            sheetId: sheetGid,
            dimension: 'ROWS',
            startIndex: row - 1, // API uses 0-based index
            endIndex: row,
          ),
          properties: sheets.DimensionProperties(pixelSize: height),
          fields: 'pixelSize',
        ),
      ),
    ]);
    await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
  }

  // ── Sheets: Tab Management ──────────────────────────────────────────

  /// Gets the GID (sheet ID) of the first tab in a spreadsheet.
  static Future<int> getSheetGid(String spreadsheetId) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final ss = await sheetsApi.spreadsheets.get(spreadsheetId);
    return ss.sheets!.first.properties!.sheetId!;
  }

  /// Reads a single row starting at [startCell] and returns the cell values.
  static Future<List<String>> readRow(String spreadsheetId, String startCell,
      {String? tabName}) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final range = tabName != null ? "'$tabName'!$startCell" : startCell;
    final result = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
    if (result.values != null && result.values!.isNotEmpty) {
      return result.values!.first.map((v) => v.toString()).toList();
    }
    return [];
  }

  /// Finds the first empty row in a given column of a tab.
  /// Used when appending to an existing tab.
  static Future<int> getFirstEmptyRow(
      String spreadsheetId, String tabName, String column) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    try {
      final result = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        "'$tabName'!$column:$column",
      );
      final rows = result.values;
      if (rows == null || rows.isEmpty) return 1;
      return rows.length + 1;
    } catch (_) {
      return 1;
    }
  }

  /// Lists all tabs (sheets) within a spreadsheet.
  static Future<List<SheetTab>> getSheetTabs(String spreadsheetId) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final ss = await sheetsApi.spreadsheets.get(spreadsheetId);
    return ss.sheets!
        .map((s) => SheetTab(s.properties!.sheetId!, s.properties!.title!))
        .toList();
  }

  /// Adds a new tab to a spreadsheet. If [title] is null, uses Sheets default naming.
  /// Returns the GID of the newly created tab.
  static Future<int> addSheet(String spreadsheetId, String? title) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final props = sheets.SheetProperties();
    if (title != null && title.isNotEmpty) props.title = title;
    final request = sheets.BatchUpdateSpreadsheetRequest(requests: [
      sheets.Request(
        addSheet: sheets.AddSheetRequest(properties: props),
      ),
    ]);
    final response =
        await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
    return response.replies!.first.addSheet!.properties!.sheetId!;
  }

  /// Renames an existing tab within a spreadsheet.
  static Future<void> renameSheet(
      String spreadsheetId, int sheetGid, String name) async {
    final sheetsApi = sheets.SheetsApi(_authClient!);
    final request = sheets.BatchUpdateSpreadsheetRequest(requests: [
      sheets.Request(
        updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
          properties: sheets.SheetProperties(sheetId: sheetGid, title: name),
          fields: 'title',
        ),
      ),
    ]);
    await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
  }

  // ── Drive: Photo Upload ─────────────────────────────────────────────

  /// Cached folder ID for the QR_Scan_Thumbs folder on Drive.
  static String? _thumbsFolderId;

  /// Gets or creates the "QR_Scan_Thumbs" folder on Google Drive.
  /// Caches the folder ID after first lookup to avoid repeated API calls.
  static Future<String> _getOrCreateThumbsFolder() async {
    if (_thumbsFolderId != null) return _thumbsFolderId!;
    final driveApi = drive.DriveApi(_authClient!);

    // Check if folder already exists
    final result = await driveApi.files.list(
      q: "name='QR_Scan_Thumbs' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      _thumbsFolderId = result.files!.first.id!;
      return _thumbsFolderId!;
    }

    // Folder doesn't exist — create it
    final folder = drive.File()
      ..name = 'QR_Scan_Thumbs'
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await driveApi.files.create(folder);
    _thumbsFolderId = created.id!;
    return _thumbsFolderId!;
  }

  /// Uploads a JPEG image to the QR_Scan_Thumbs folder on Google Drive.
  /// Makes the file publicly readable so the =IMAGE() formula works in Sheets.
  /// Returns the Drive file ID.
  static Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final driveApi = drive.DriveApi(_authClient!);
    final folderId = await _getOrCreateThumbsFolder();

    // Upload the image file
    final file = drive.File()
      ..name = fileName
      ..mimeType = 'image/jpeg'
      ..parents = [folderId];
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final uploaded = await driveApi.files.create(file, uploadMedia: media);

    // Make publicly viewable so the IMAGE() formula in Sheets can access it
    await driveApi.permissions.create(
      drive.Permission()
        ..role = 'reader'
        ..type = 'anyone',
      uploaded.id!,
    );

    return uploaded.id!;
  }

  /// Generates a Google Drive thumbnail URL for a given file ID.
  /// Used in the =IMAGE() formula written to Sheets cells.
  static String thumbnailUrl(String fileId) {
    return 'https://drive.google.com/thumbnail?id=$fileId&sz=w400';
  }
}

/// Represents a Google Sheets document with its Drive file ID and name.
class SpreadsheetInfo {
  final String id;
  final String name;
  SpreadsheetInfo(this.id, this.name);
}

/// Represents a single tab (sheet) within a spreadsheet.
class SheetTab {
  final int gid;
  final String title;
  SheetTab(this.gid, this.title);
}
