/// Sign-in screen — the first page users see.
/// Handles Google Sign-In and navigates to the sheet picker on success.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'google_service.dart';
import 'sheet_picker_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String _status = 'Sign in to get started';

  /// Initiates Google Sign-In and updates the UI with the result.
  Future<void> _signIn() async {
    final success = await GoogleService.signIn();
    if (success && mounted) {
      setState(
          () => _status = 'Signed in as ${GoogleService.currentUser!.email}');
    } else if (mounted) {
      setState(() => _status = 'Sign-in failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = GoogleService.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Sheets Scanner'),
        actions: [
          // Exit button available on every screen
          IconButton(
            onPressed: () => SystemNavigator.pop(),
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Exit App',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status message showing sign-in state
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),

              // Show sign-in button when not authenticated
              if (!signedIn)
                ElevatedButton(
                  onPressed: _signIn,
                  child: const Text('Sign in with Google'),
                ),

              // Show spreadsheet picker button when authenticated
              if (signedIn)
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SheetPickerPage()),
                  ),
                  child: const Text('Choose Spreadsheet'),
                ),
              const SizedBox(height: 24),

              // Exit button at the bottom of the screen
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Exit App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
