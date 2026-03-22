// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ousia/main.dart';
import 'package:ousia/screens/welcome_screen.dart';
import 'package:ousia/screens/login_screen.dart';
import 'package:ousia/screens/signup_screen.dart';

void main() {
  group('Ousia App Tests', () {
    testWidgets('App starts with WelcomeScreen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const OusiaApp());

      // Verify that we start with the welcome screen
      expect(find.text('Ousia'), findsOneWidget);
      expect(find.text('Welcome to your journey'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Welcome screen navigation to login works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

      // Find and tap the Sign In button
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify that we navigated to the login screen
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to your account'), findsOneWidget);
    });

    testWidgets('Welcome screen navigation to signup works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

      // Find and tap the Create Account button
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify that we navigated to the signup screen
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign up to get started'), findsOneWidget);
    });

    testWidgets('Login screen form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Try to submit form without filling fields
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Verify validation messages appear
      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Login screen password visibility toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      // Find the visibility icon - initially password should be obscured
      final visibilityIcon = find.byIcon(Icons.visibility_off);
      expect(visibilityIcon, findsOneWidget);

      // Tap the visibility icon
      await tester.tap(visibilityIcon);
      await tester.pump();

      // Now the icon should change to visibility (showing password)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('Signup screen form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

      // Try to submit form without filling fields
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Verify validation messages appear
      expect(find.text('Please enter a username'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('Signup screen email validation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');
      
      // Try to submit
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Verify email validation message
      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('Signup screen password confirmation validation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

      // Enter different passwords
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(3), 'DifferentPassword123!');
      
      // Try to submit
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Verify password match validation message
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Signup screen terms agreement validation works', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

      // Fill all fields correctly but don't check terms
      await tester.enterText(find.byType(TextFormField).at(0), 'testuser');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password123!');
      
      // Try to submit without agreeing to terms
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Verify terms agreement message appears
      expect(find.text('Please agree to the terms and conditions'), findsOneWidget);
    });
  });
}
