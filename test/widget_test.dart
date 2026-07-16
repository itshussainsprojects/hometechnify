// Home Technify Widget Test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_technify/main.dart';

void main() {
  testWidgets('App should build successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HomeTechnifyApp());

    // Verify app builds
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
