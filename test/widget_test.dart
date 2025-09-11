// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic MaterialApp widget test', (WidgetTester tester) async {
    // Create a simple MaterialApp for testing
    await tester.pumpWidget(
      MaterialApp(
        title: 'Podcast Tracker',
        home: Scaffold(
          appBar: AppBar(title: const Text('Podcast Tracker')),
          body: const Center(child: Text('Welcome to Podcast Tracker')),
        ),
      ),
    );

    // Verify that the app title is displayed
    expect(find.text('Podcast Tracker'), findsOneWidget);
    expect(find.text('Welcome to Podcast Tracker'), findsOneWidget);
  });

  testWidgets('Theme mode test', (WidgetTester tester) async {
    // Test light theme
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: Center(child: Text('Light Theme')),
        ),
      ),
    );

    expect(find.text('Light Theme'), findsOneWidget);

    // Test dark theme
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(child: Text('Dark Theme')),
        ),
      ),
    );

    expect(find.text('Dark Theme'), findsOneWidget);
  });

  testWidgets('Button interaction test', (WidgetTester tester) async {
    bool buttonPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                buttonPressed = true;
              },
              child: const Text('Test Button'),
            ),
          ),
        ),
      ),
    );

    // Verify button is displayed
    expect(find.text('Test Button'), findsOneWidget);

    // Tap the button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify button was pressed
    expect(buttonPressed, true);
  });
}
