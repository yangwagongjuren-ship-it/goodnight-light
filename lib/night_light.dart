import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NightPhase { setup, starting, running, dark }

@immutable
class NightSettings {
  const NightSettings({
    int minutes = 15,
    int? seconds,
    this.brightness = 0.2,
    this.language = 'system',
    this.introSeen = false,
  }) : seconds = seconds ?? minutes * 60;
  final int seconds;
  int get minutes => seconds ~/ 60;
  // The limit is the native Duration representation, not a product time limit.
  static const maxSeconds = 9223372036854;
  final double brightness;
  final String language;
  final bool introSeen;

  factory NightSettings.fromMap(Map<Object?, Object?> map) {
    final minutes = map['minutes'];
    final seconds = map['seconds'];
    final brightness = map['brightness'];
    final language = map['language'];
    return NightSettings(
      seconds: seconds is num && seconds.isFinite && seconds > 0
          ? seconds.toInt().clamp(1, maxSeconds)
          : minutes is num && minutes.isFinite && minutes > 0
          ? (minutes * 60).toInt().clamp(1, maxSeconds)
          : 900,
      brightness: brightness is num && brightness.isFinite
          ? brightness.toDouble().clamp(0.02, 1.0)
          : 0.2,
      language: const ['system', 'en', 'zh'].contains(language)
          ? language as String
          : 'system',
      introSeen: map['introSeen'] == true,
    );
  }

  NightSettings copyWith({
    int? minutes,
    int? seconds,
    double? brightness,
    String? language,
    bool? introSeen,
  }) => NightSettings(
    seconds: seconds ?? (minutes == null ? this.seconds : minutes * 60),
    brightness: brightness ?? this.brightness,
    language: language ?? this.language,
    introSeen: introSeen ?? this.introSeen,
  );
  Map<String, Object> toMap() => {
    'seconds': seconds,
    'brightness': brightness,
    'language': language,
    'introSeen': introSeen,
  };
}

@immutable
class LightFrame {
  const LightFrame(this.hardware, this.opacity);
  final double hardware;
  final double opacity;

  static LightFrame at(Duration elapsed, Duration duration, double initial) {
    final p = (elapsed.inMicroseconds / math.max(1, duration.inMicroseconds))
        .clamp(0.0, 1.0);
    final light = (1 - 3 * p * p + 2 * p * p * p).clamp(0.0, 1.0);
    // Split the control value between hardware and software. This is not a lux calibration.
    final software = math.sqrt(light);
    return LightFrame(math.max(0.01, initial * software), software);
  }
}

abstract interface class LightDevice {
  Future<NightSettings> load();
  Future<void> save(NightSettings settings);
  Future<void> begin(double brightness);
  Future<void> preview(double brightness);
  Future<void> suspend();
  Future<Duration> clock();
  Future<void> setBrightness(double brightness);
  Future<void> release({required bool keepDark});
}

class NativeLightDevice implements LightDevice {
  static const channel = MethodChannel('amber_night/light');
  @override
  Future<NightSettings> load() async => NightSettings.fromMap(
    await channel.invokeMapMethod<Object?, Object?>('loadSettings') ?? {},
  );
  @override
  Future<void> save(NightSettings settings) =>
      channel.invokeMethod<void>('saveSettings', settings.toMap());
  @override
  Future<void> begin(double brightness) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await channel.invokeMethod<void>('begin', {'brightness': brightness});
  }

  @override
  Future<void> setBrightness(double brightness) =>
      channel.invokeMethod<void>('setBrightness', {'brightness': brightness});

  @override
  Future<void> preview(double brightness) =>
      channel.invokeMethod<void>('preview', {'brightness': brightness});

  @override
  Future<void> suspend() => channel.invokeMethod<void>('suspend');

  @override
  Future<Duration> clock() async =>
      Duration(milliseconds: (await channel.invokeMethod<int>('clock'))!);
  @override
  Future<void> release({required bool keepDark}) async {
    await channel.invokeMethod<void>('release', {'keepDark': keepDark});
    if (!keepDark) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}

class NightController extends ChangeNotifier {
  NightController(
    this.device, {
    Duration Function()? elapsed,
    Future<void> Function()? afterBlackFrame,
  }) : _elapsedOverride = elapsed,
       _afterBlackFrame = afterBlackFrame ?? (() async {});
  final LightDevice device;
  final Duration Function()? _elapsedOverride;
  final Future<void> Function() _afterBlackFrame;
  final Stopwatch _watch = Stopwatch();
  Future<Duration> _sessionClock = Future.value(Duration.zero);
  Duration _elapsedBase = Duration.zero;
  Duration get _currentElapsed =>
      _elapsedOverride?.call() ?? (_elapsedBase + _watch.elapsed);
  Timer? _ticker;
  Future<void> _operations = Future<void>.value();
  Future<void> _saves = Future<void>.value();
  bool _disposed = false;
  bool _brightnessPending = false;
  bool _foreground = true;
  int _generation = 0;
  NightPhase phase = NightPhase.setup;
  NightSettings settings = const NightSettings();
  Duration duration = const Duration(minutes: 15);
  Duration elapsed = Duration.zero;
  LightFrame frame = const LightFrame(0.01, 0);
  bool loaded = false;
  bool completed = false;
  String? error;

  Duration get remaining => Duration(
    microseconds: math.max(0, duration.inMicroseconds - elapsed.inMicroseconds),
  );

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.catchError((Object _) {});
    return result;
  }

  Future<void> initialize() async {
    try {
      settings = await device.load();
    } catch (_) {
      error = 'load';
    }
    loaded = true;
    _notify();
  }

  Future<void> updateSettings(NightSettings value) async {
    final brightnessChanged = settings.brightness != value.brightness;
    settings = value;
    _notify();
    if (brightnessChanged && phase == NightPhase.setup && _foreground) {
      final generation = _generation;
      unawaited(
        _enqueue(() async {
          if (generation == _generation &&
              _foreground &&
              phase == NightPhase.setup) {
            await device.preview(settings.brightness);
          }
        }).catchError((Object _) {
          error = 'device';
          _notify();
        }),
      );
    }
    // Preserve write order when a slider generates multiple changes.
    final save = _saves.then((_) => device.save(value));
    _saves = save.catchError((Object _) {});
    try {
      await save;
    } catch (_) {
      error = 'save';
      _notify();
    }
  }

  Future<void> start() async {
    if (!loaded || phase != NightPhase.setup || !_foreground) return;
    final generation = ++_generation;
    error = null;
    completed = false;
    phase = NightPhase.starting;
    duration = Duration(seconds: settings.seconds);
    elapsed = Duration.zero;
    frame = const LightFrame(0.01, 0);
    _watch
      ..reset()
      ..start();
    _elapsedBase = Duration.zero;
    _notify();
    try {
      _sessionClock = device.clock();
      await _sessionClock;
      if (_disposed || generation != _generation) return;
      _watch
        ..reset()
        ..start();
      await _afterBlackFrame();
      await _enqueue(() async {
        if (generation == _generation && _foreground) {
          await device.begin(settings.brightness);
        }
      });
      if (_disposed || generation != _generation) return;
      phase = NightPhase.running;
      elapsed = _currentElapsed;
      frame = LightFrame.at(elapsed, duration, settings.brightness);
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => tick());
      _notify();
    } catch (_) {
      if (generation == _generation) await _fail();
    }
  }

  @visibleForTesting
  void tick() {
    if (phase != NightPhase.running || !_foreground) return;
    elapsed = _currentElapsed;
    if (elapsed >= duration) {
      unawaited(end());
      return;
    }
    frame = LightFrame.at(elapsed, duration, settings.brightness);
    _notify();
    if (_brightnessPending) return;
    _brightnessPending = true;
    final generation = _generation;
    unawaited(
      _enqueue(() async {
            if (_foreground &&
                phase == NightPhase.running &&
                generation == _generation) {
              await device.setBrightness(frame.hardware);
            }
          })
          .catchError((Object _) async {
            if (generation == _generation) await _fail();
          })
          .whenComplete(() {
            _brightnessPending = false;
          }),
    );
  }

  /// A finished foreground session stays dark until touched or reopened.
  Future<void> end() async {
    if (phase != NightPhase.running && phase != NightPhase.starting) return;
    final generation = ++_generation;
    _ticker?.cancel();
    _watch.stop();
    elapsed = duration;
    completed = true;
    phase = NightPhase.dark;
    frame = const LightFrame(0.01, 0);
    _notify();
    if (_foreground) await _afterBlackFrame();
    try {
      await _enqueue(() async {
        if (generation == _generation) {
          await device.release(keepDark: _foreground);
        }
      });
    } catch (_) {
      error = 'device';
      _notify();
    }
  }

  Future<void> returnToSetup({bool? finished}) async {
    final generation = ++_generation;
    _ticker?.cancel();
    _watch.stop();
    completed = finished ?? completed;
    phase = NightPhase.dark;
    frame = const LightFrame(0.01, 0);
    _notify();
    await _afterBlackFrame();
    try {
      await _enqueue(() async {
        if (generation == _generation) await device.release(keepDark: false);
      });
      if (_disposed || generation != _generation) return;
      phase = NightPhase.setup;
    } catch (_) {
      error = 'device';
    }
    _notify();
  }

  Future<void> resumed() async {
    if (_foreground) return;
    _foreground = true;
    if (phase == NightPhase.dark) {
      await returnToSetup(finished: true);
      return;
    }
    if (phase == NightPhase.setup) {
      await _enqueue(() => device.release(keepDark: false));
      return;
    }
    final generation = ++_generation;
    try {
      // Native clocks include device sleep and are unaffected by changing the time zone or clock.
      final started = await _sessionClock;
      final now = await device.clock();
      if (_disposed || generation != _generation) return;
      elapsed = _elapsedOverride?.call() ?? now - started;
      if (elapsed >= duration) {
        await returnToSetup(finished: true);
        return;
      }
      _elapsedBase = elapsed < Duration.zero ? Duration.zero : elapsed;
      _watch
        ..reset()
        ..start();
      phase = NightPhase.running;
      frame = LightFrame.at(elapsed, duration, settings.brightness);
      _notify();
      await _afterBlackFrame();
      await _enqueue(() async {
        if (_foreground &&
            phase == NightPhase.running &&
            generation == _generation) {
          // Paint the current fade before removing the native lifecycle cover.
          await device.begin(frame.hardware);
        }
      });
      if (_disposed || generation != _generation) return;
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => tick());
      tick();
    } catch (_) {
      if (generation == _generation) await _fail();
    }
  }

  Future<void> suspended() async {
    if (!_foreground) return;
    _foreground = false;
    ++_generation;
    _ticker?.cancel();
    // Stopwatch keeps measuring elapsed time; no background light or wake lock.
    try {
      await _enqueue(() => device.suspend());
    } catch (_) {
      error = 'device';
      _notify();
    }
  }

  Future<void> _fail() async {
    final generation = ++_generation;
    _ticker?.cancel();
    _watch.stop();
    phase = NightPhase.dark;
    frame = const LightFrame(0.01, 0);
    error = 'device';
    _notify();
    try {
      await _enqueue(() async {
        if (generation == _generation) await device.release(keepDark: false);
      });
    } catch (_) {
      /* Native cleanup also runs on background. */
    }
    if (!_disposed && generation == _generation) {
      phase = NightPhase.setup;
      _notify();
    }
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _ticker?.cancel();
    _watch.stop();
    unawaited(
      _enqueue(() => device.release(keepDark: false)).catchError((Object _) {}),
    );
    super.dispose();
  }
}
