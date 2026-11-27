import 'dart:async';
import 'package:amber_night/night_light.dart';

class FakeDevice implements LightDevice {
  NightSettings settings = const NightSettings(introSeen: true, language: 'en');
  final List<String> calls = [];
  Completer<void>? beginGate;
  bool failBegin = false;
  bool failBrightness = false;
  bool failSave = false;
  double brightness = 0.7;
  double? originalBrightness;
  bool awake = false;
  final Stopwatch _clock = Stopwatch()..start();
  Duration clockOffset = Duration.zero;
  @override
  Future<Duration> clock() async => _clock.elapsed + clockOffset;
  @override
  Future<NightSettings> load() async => settings;
  @override
  Future<void> save(NightSettings value) async {
    if (failSave) throw StateError('disk');
    settings = value;
  }

  @override
  Future<void> begin(double value) async {
    calls.add('begin');
    if (failBegin) throw StateError('screen');
    await beginGate?.future;
    originalBrightness ??= brightness;
    brightness = value;
    awake = true;
  }

  @override
  Future<void> preview(double value) async {
    calls.add('preview');
    originalBrightness ??= brightness;
    brightness = value;
  }

  @override
  Future<void> suspend() async {
    calls.add('suspend');
    awake = false;
    brightness = originalBrightness ?? brightness;
    originalBrightness = null;
  }

  @override
  Future<void> setBrightness(double value) async {
    calls.add('brightness');
    if (failBrightness) throw StateError('screen');
    brightness = value;
  }

  @override
  Future<void> release({required bool keepDark}) async {
    calls.add('release:$keepDark');
    awake = false;
    if (keepDark) {
      originalBrightness ??= brightness;
      brightness = 0.01;
    } else {
      brightness = originalBrightness ?? brightness;
      originalBrightness = null;
    }
  }
}
