import 'package:amber_night/main.dart';
import 'package:amber_night/night_light.dart';
import 'package:amber_night/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_device.dart';

void main() {
  testWidgets('deadline hides revealed controls immediately', (tester) async {
    var elapsed = Duration.zero;
    final device = FakeDevice();
    final controller = NightController(device, elapsed: () => elapsed);
    await tester.pumpWidget(AmberNightApp(controller: controller));
    await tester.pumpAndSettle();
    await controller.updateSettings(controller.settings.copyWith(seconds: 30));
    await controller.start();
    await tester.pump();
    expect(find.byKey(const Key('companion-mark')), findsOneWidget);
    final touch = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('light-surface'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await touch.up();
    await tester.pump();
    expect(find.byKey(const Key('stop')), findsOneWidget);
    elapsed = const Duration(seconds: 30);
    controller.tick();
    await tester.pump();
    expect(find.byKey(const Key('stop')), findsNothing);
    expect(find.byKey(const Key('companion-mark')), findsNothing);
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('light-surface'))).color,
      Colors.black,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  Future<void> mount(WidgetTester tester, FakeDevice device) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AmberNightApp(device: device));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'original hold behavior stays unchanged while the hint says three seconds',
    (tester) async {
      final device = FakeDevice();
      await mount(tester, device);
      expect(find.byKey(const Key('preview')), findsNothing);
      expect(find.text('Try a 30-second fade'), findsNothing);
      expect(
        find.text('Hold the screen for 3 seconds to reveal controls.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('start')));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(device.calls, contains('begin'));
      expect(find.byKey(const Key('stop')), findsNothing);
      await tester.tap(find.byKey(const Key('light-surface')));
      await tester.pump();
      expect(find.byKey(const Key('stop')), findsNothing);
      final touch = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('light-surface'))),
      );
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byKey(const Key('stop')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      await touch.up();
      await tester.pump();
      expect(find.byKey(const Key('stop')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('stop')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'background restores brightness and resume continues the existing fade',
    (tester) async {
      final device = FakeDevice();
      await mount(tester, device);
      await tester.ensureVisible(find.byKey(const Key('start')));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(device.brightness, 0.7);
      expect(device.awake, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('light-surface'))).color,
        isNot(Colors.black),
      );
      expect(device.calls.where((e) => e == 'begin').length, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'hour minute second wheels reject zero and support more than a day',
    (tester) async {
      final device = FakeDevice();
      await mount(tester, device);
      await tester.tap(find.byKey(const Key('custom-duration')));
      await tester.pumpAndSettle();
      void choose(int wheel, int item) {
        tester
            .widget<CupertinoPicker>(find.byKey(Key('duration-wheel-$wheel')))
            .scrollController!
            .jumpToItem(item);
      }

      choose(0, 0);
      choose(1, 0);
      choose(2, 0);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('duration-wheel-0')),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(find.text('-1'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('duration-done')))
            .onPressed,
        isNull,
      );
      choose(0, 49);
      choose(1, 17);
      choose(2, 3);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('duration-done')));
      await tester.pumpAndSettle();
      expect(device.settings.seconds, 49 * 3600 + 17 * 60 + 3);
      expect(find.text('49 h 17 min 3 sec'), findsOneWidget);
    },
  );

  testWidgets('brightness slider changes hardware preview immediately', (
    tester,
  ) async {
    final device = FakeDevice();
    await mount(tester, device);
    await tester.ensureVisible(find.byKey(const Key('brightness')));
    await tester.drag(
      find.byKey(const Key('brightness')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(device.calls, contains('preview'));
    expect(device.brightness, device.settings.brightness);
    expect(device.awake, isFalse);
  });

  testWidgets('finished screen opens completed settings with a single tap', (
    tester,
  ) async {
    final device = FakeDevice();
    final c = NightController(device);
    await tester.pumpWidget(AmberNightApp(controller: c));
    await tester.pumpAndSettle();
    await c.start();
    await c.end();
    await tester.pump();
    await tester.tap(find.byKey(const Key('light-surface')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completed')), findsOneWidget);
    expect(find.byKey(const Key('start')), findsOneWidget);
    expect(device.brightness, 0.7);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('reopening after completion shows a message rather than black', (
    tester,
  ) async {
    final device = FakeDevice();
    final c = NightController(device);
    await tester.pumpWidget(AmberNightApp(controller: c));
    await tester.pumpAndSettle();
    await c.start();
    await c.end();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('completed')), findsOneWidget);
    expect(find.byKey(const Key('light-surface')), findsNothing);
    expect(device.brightness, 0.7);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Chinese introduction is shown once and acknowledged locally', (
    tester,
  ) async {
    final device = FakeDevice()..settings = const NightSettings(language: 'zh');
    await mount(tester, device);
    expect(find.text('开始之前'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(device.settings.introSeen, isTrue);
    expect(find.text('开始渐暗'), findsOneWidget);
  });

  testWidgets('small phone with large text can scroll without layout errors', (
    tester,
  ) async {
    await mount(tester, FakeDevice());
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('start')));
    expect(find.byKey(const Key('start')).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'home story opens, scrolls and returns on small phones in both languages',
    (tester) async {
      for (final language in ['en', 'zh']) {
        final words = Words(language == 'zh');
        final device = FakeDevice()
          ..settings = NightSettings(language: language, introSeen: true);
        await mount(tester, device);
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('our-story')));
        await tester.tap(find.byKey(const Key('our-story')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(words.story), findsOneWidget);
        final scroll = find
            .descendant(
              of: find.byKey(const Key('story-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(
          find.byKey(const Key('story-scroll')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        await tester.tap(find.text(words.done));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('our-story')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('start')));
        await tester.tap(find.byKey(const Key('start')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(words.companion), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
