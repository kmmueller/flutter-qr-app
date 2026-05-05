import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_sheets_scanner/sign_in_page.dart';

void main() {
  group('SignInPage', () {
    testWidgets('shows sign in button initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignInPage()));
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in to get started'), findsOneWidget);
    });

    testWidgets('shows exit app button', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignInPage()));
      expect(find.text('Exit App'), findsOneWidget);
    });

    testWidgets('shows app title in app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignInPage()));
      expect(find.text('QR Sheets Scanner'), findsOneWidget);
    });

    testWidgets('has exit icon in app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignInPage()));
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    });
  });
}
