/// ISBN lookup service using the Open Library API.
/// Also defines the BookInfo model used for ISBN scan results.
library;
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Holds metadata for a book looked up by ISBN.
class BookInfo {
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String year;
  final String pages;

  BookInfo({
    required this.isbn,
    this.title = '',
    this.author = '',
    this.publisher = '',
    this.year = '',
    this.pages = '',
  });

  /// Converts book info to a row of strings for writing to Sheets.
  /// [box] is the user-specified box/location value appended as the last column.
  List<String> toRow(String box) =>
      [isbn, title, author, publisher, year, pages, box];

  /// Returns the header row for ISBN mode in Sheets.
  static List<String> headers() =>
      ['ISBN', 'Title', 'Author', 'Publisher', 'Year', 'Pages', 'Box'];
}

/// Service for looking up book metadata by ISBN via the Open Library API.
class IsbnService {
  /// Looks up a book by ISBN using the Open Library Books API.
  /// Returns a [BookInfo] with all available metadata, or null if not found.
  static Future<BookInfo?> lookup(String isbn) async {
    try {
      // Query Open Library's Books API with the ISBN
      final url = Uri.parse(
          'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final key = 'ISBN:$isbn';

        // Check if the ISBN was found in the response
        if (data.containsKey(key)) {
          final book = data[key];

          // Extract fields, joining multiple authors/publishers with commas
          return BookInfo(
            isbn: isbn,
            title: book['title'] ?? '',
            author:
                (book['authors'] as List?)?.map((a) => a['name']).join(', ') ??
                    '',
            publisher: (book['publishers'] as List?)
                    ?.map((p) => p['name'])
                    .join(', ') ??
                '',
            year: book['publish_date'] ?? '',
            pages: book['number_of_pages']?.toString() ?? '',
          );
        }
      }
    } catch (_) {
      // Silently fail — caller handles null return
    }
    return null;
  }
}
