// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sajiloparking/main.dart';
import 'package:provider/provider.dart';
import 'package:sajiloparking/providers/parking_provider.dart';
import 'package:sajiloparking/providers/theme_provider.dart';

void main() {
  testWidgets('Sajilo Parking app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ParkingProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const SajiloParking(),
      ),
    );

    // Basic render test - we're just checking if the app builds
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
