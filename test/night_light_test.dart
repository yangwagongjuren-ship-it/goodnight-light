import 'dart:async';
import 'package:amber_night/night_light.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_device.dart';

void main() {
  test('a delayed completion cannot release a newly started session', () async {
    Future<void> Function() nextFrame = () async {};
    final device = FakeDevice();
    final c = NightController(device, afterBlackFrame: () => nextFrame());
    addTearDown(c.dispose);
    await c.initialize();
    await c.start();
    final delayedFrame = Completer<void>();
    nextFrame = () => delayedFrame.future;
    final oldCompletion = c.end();
    nextFrame = () async {};
    await c.returnToSetup();
    await c.start();
    delayedFrame.complete();
    await oldCompletion;
    expect(c.phase, NightPhase.running);
    expect(device.calls, ['begin', 'release:false', 'begin']);
  });
  test('curve stays bounded and monotonic through the hardware floor', () {
    for (final initial in [0.02, 0.2, 1.0]) {
      var lastHardware = 1.0;
      var lastOpacity = 1.0;
      for (var ms = 0; ms <= 901000; ms += 50) {
        final frame = LightFrame.at(
          Duration(milliseconds: ms),
          const Duration(minutes: 15),
          initial,
        );
        expect(frame.hardware, inInclusiveRange(0.01, lastHardware));
        expect(frame.opacity, inInclusiveRange(0.0, lastOpacity));
        lastHardware = frame.hardware;
        lastOpacity = frame.opacity;
      }
      expect(lastOpacity, 0);
    }
  });

  test('corrupt preferences are bounded and non-finite values rejected', () {
    final settings = NightSettings.fromMap({
      'minutes': 999,
      'brightness': double.nan,
      'language': 'invalid',
    });
    expect(settings.minutes, 999);
    expect(settings.brightness, 0.2);
    expect(settings.language, 'system');
    expect(NightSettings.fromMap({'minutes': -1}).minutes, 15);
    expect(NightSettings.fromMap({'seconds': 7}).seconds, 7);
    expect(NightSettings.fromMap({'seconds': 172801}).seconds, 172801);
    expect(NightSettings.fromMap({'seconds': 0}).seconds, 900);
  });

  test(
    'late timer tick uses elapsed time and releases once at the deadline',
    () async {
      var elapsed = Duration.zero;
      final device = FakeDevice();
      final c = NightController(device, elapsed: () => elapsed);
      addTearDown(c.dispose);
      await c.initialize();
      await c.start();
      elapsed = const Duration(minutes: 7);
      c.tick();
      expect(c.remaining, const Duration(minutes: 8));
      elapsed = const Duration(minutes: 16);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, NightPhase.dark);
      expect(c.frame.opacity, 0);
      expect(c.remaining, Duration.zero);
      c.tick();
      expect(device.calls.where((c) => c == 'release:true').length, 1);
    },
  );

  test(
    'leaving during asynchronous begin restores brightness and resumes the timer',
    () async {
      final device = FakeDevice()..beginGate = Completer<void>();
      final c = NightController(device);
      addTearDown(c.dispose);
      await c.initialize();
      final start = c.start();
      await Future<void>.delayed(Duration.zero);
      final stop = c.suspended();
      device.beginGate!.complete();
      await Future.wait([start, stop]);
      expect(c.phase, NightPhase.starting);
      expect(c.frame.opacity, 0);
      expect(device.calls, ['begin', 'suspend']);
      expect(device.brightness, 0.7);
      expect(device.awake, isFalse);
      await c.resumed();
      expect(c.phase, NightPhase.running);
      expect(device.calls.where((c) => c == 'begin').length, 2);
    },
  );

  test(
    'custom seconds expire without changing the selected duration',
    () async {
      var elapsed = Duration.zero;
      final c = NightController(FakeDevice(), elapsed: () => elapsed);
      addTearDown(c.dispose);
      await c.initialize();
      await c.updateSettings(c.settings.copyWith(seconds: 7));
      await c.start();
      elapsed = const Duration(seconds: 7);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, NightPhase.dark);
      expect(c.settings.seconds, 7);
    },
  );

  test(
    'platform failure restores brightness and shows actionable settings',
    () async {
      final device = FakeDevice()..failBegin = true;
      final c = NightController(device);
      addTearDown(c.dispose);
      await c.initialize();
      await c.start();
      expect(c.error, 'device');
      expect(c.phase, NightPhase.setup);
      expect(device.calls.last, 'release:false');
    },
  );

  test(
    'brightness failure ends running session and restores on explicit return',
    () async {
      final device = FakeDevice()..failBrightness = true;
      final c = NightController(device);
      addTearDown(c.dispose);
      await c.initialize();
      await c.start();
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, NightPhase.setup);
      expect(c.frame.opacity, 0);
      await c.returnToSetup();
      expect(device.calls.last, 'release:false');
      expect(c.phase, NightPhase.setup);
    },
  );

  test(
    'preview changes real brightness without a wake lock and restores on leave',
    () async {
      final device = FakeDevice();
      final c = NightController(device);
      addTearDown(c.dispose);
      await c.initialize();
      await c.updateSettings(c.settings.copyWith(brightness: 0.4));
      await Future<void>.delayed(Duration.zero);
      expect(device.brightness, 0.4);
      expect(device.awake, isFalse);
      await c.start();
      await c.suspended();
      expect(device.brightness, 0.7);
    },
  );

  test(
    'switching apps preserves elapsed time and adopts later system brightness',
    () async {
      var elapsed = Duration.zero;
      final device = FakeDevice();
      final c = NightController(device, elapsed: () => elapsed);
      addTearDown(c.dispose);
      await c.initialize();
      await c.start();
      elapsed = const Duration(minutes: 3);
      c.tick();
      await c.suspended();
      expect(device.brightness, 0.7);
      expect(device.awake, isFalse);
      device.brightness =
          0.6; // The user changes system brightness in another app.
      elapsed = const Duration(minutes: 7);
      await c.resumed();
      expect(c.phase, NightPhase.running);
      expect(c.remaining, const Duration(minutes: 8));
      expect(
        device.brightness,
        closeTo(LightFrame.at(elapsed, c.duration, 0.2).hardware, 0.0001),
      );
      await c.returnToSetup();
      expect(device.brightness, 0.6);
      expect(device.awake, isFalse);
    },
  );

  test(
    'deadline passed in background returns to completed settings, never relights',
    () async {
      var elapsed = Duration.zero;
      final device = FakeDevice();
      final c = NightController(device, elapsed: () => elapsed);
      addTearDown(c.dispose);
      await c.initialize();
      await c.updateSettings(c.settings.copyWith(seconds: 4));
      await c.start();
      await c.suspended();
      elapsed = const Duration(seconds: 5);
      await c.resumed();
      expect(c.phase, NightPhase.setup);
      expect(c.completed, isTrue);
      expect(device.brightness, 0.7);
      expect(device.calls.where((call) => call == 'begin').length, 1);
    },
  );

  test('completed black screen restores brightness when reopened', () async {
    final device = FakeDevice();
    final c = NightController(device);
    addTearDown(c.dispose);
    await c.initialize();
    await c.start();
    await c.end();
    expect(device.brightness, 0.01);
    await c.suspended();
    expect(device.brightness, 0.7);
    await c.resumed();
    expect(c.phase, NightPhase.setup);
    expect(c.completed, isTrue);
    expect(device.brightness, 0.7);
    expect(device.awake, isFalse);
  });

  test(
    'resume calibrates against native time that includes device sleep',
    () async {
      final device = FakeDevice();
      final c = NightController(device);
      addTearDown(c.dispose);
      await c.initialize();
      await c.start();
      await c.suspended();
      device.clockOffset = const Duration(minutes: 5);
      await c.resumed();
      expect(c.remaining.inSeconds, inInclusiveRange(599, 600));
      expect(c.phase, NightPhase.running);
      await c.suspended();
      device.clockOffset = const Duration(minutes: 16);
      await c.resumed();
      expect(c.phase, NightPhase.setup);
      expect(c.completed, isTrue);
      expect(device.awake, isFalse);
    },
  );
}
