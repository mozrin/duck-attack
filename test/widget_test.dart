import 'package:duck_attack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Duck Attack smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: DuckAttackApp()));

    // Verify that Splash Screen is shown.
    expect(find.byType(Image), findsOneWidget);

    // Pump to allow SplashScreen timer to complete and navigation to happen (3s native + 3s app)
    await tester.pumpAndSettle(const Duration(seconds: 7));

    // After 2 seconds, it should have navigated away (Splash Image gone)
    expect(find.byType(Image), findsNothing);
  });
}
