/// App entry point. Launches the MaterialApp with SignInPage as the home screen.
library;
import 'package:flutter/material.dart';
import 'sign_in_page.dart';

void main() {
  runApp(const MaterialApp(
    title: 'QR Sheets Scanner',
    home: SignInPage(),
  ));
}
