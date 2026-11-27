import 'package:amber_night/main.dart';
import 'package:amber_night/night_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real platform: 30-second fade reaches black and can be exited', (
    tester,
  ) async {
    await tester.pumpWidget(const AmberNightApp());
    await tester.pumpAndSettle();
    for (final text in ['Got it', '知道了']) {
      if (find.text(text).evaluate().isNotEmpty) {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }
    }
    final controller = tester
        .widget<NightHome>(find.byType(NightHome))
        .controller;
    await controller.updateSettings(
      controller.settings.copyWith(brightness: 0.35, seconds: 49 * 3600 + 3),
    );
    final saved = await controller.device.load();
    expect(saved.seconds, 49 * 3600 + 3);
    expect(saved.brightness, closeTo(0.35, 0.001));
    await controller.updateSettings(controller.settings.copyWith(seconds: 30));
    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.tap(find.byKey(const Key('start')));
    await tester.pump();
    // Real elapsed time (not the widget fake clock). Exercise the native bridge.
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('light-surface'))),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byKey(const Key('stop')), findsNothing);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await tester.pump();
    await hold.up();
    expect(find.byKey(const Key('stop')), findsOneWidget);
    await controller.suspended();
    await Future<void>.delayed(const Duration(seconds: 2));
    await controller.resumed();
    expect(controller.phase, NightPhase.running);
    expect(controller.remaining.inSeconds, lessThanOrEqualTo(27));
    await Future<void>.delayed(
      controller.remaining + const Duration(seconds: 1),
    );
    await tester.pump();
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('light-surface'))).color,
      Colors.black,
    );
    await tester.tap(find.byKey(const Key('light-surface')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start')), findsOneWidget);
    expect(find.byKey(const Key('completed')), findsOneWidget);
    expect(find.textContaining('Screen control failed'), findsNothing);
    expect(find.textContaining('屏幕控制失败'), findsNothing);
  });
}
