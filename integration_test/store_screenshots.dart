import 'dart:io';

import 'package:amber_night/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture the shipping UI in English and Chinese', (tester) async {
    await tester.pumpWidget(const AmberNightApp());
    await tester.pumpAndSettle();
    // Accept the normal first-run message before choosing the screenshot locale.
    for (final text in ['Got it', '知道了']) {
      if (find.text(text).evaluate().isNotEmpty) {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }
    }
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    final controller = tester
        .widget<NightHome>(find.byType(NightHome))
        .controller;
    for (final language in ['en', 'zh']) {
      await controller.updateSettings(
        controller.settings.copyWith(
          language: language,
          introSeen: true,
          seconds: 900,
          brightness: 0.35,
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('home-$language');
      await tester.tap(find.byKey(const Key('custom-duration')));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('duration-$language');
      await tester.tap(find.text(language == 'zh' ? '取消' : 'Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start')));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(const Key('companion-mark')), findsOneWidget);
      await binding.takeScreenshot('running-$language');
      await controller.returnToSetup();
      await tester.pumpAndSettle();
    }
  });
}
