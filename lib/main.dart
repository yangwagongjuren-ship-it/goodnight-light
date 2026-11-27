import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'night_light.dart';
import 'strings.dart';

const ink = Color(0xFF111310);
const panel = Color(0xFF1C201B);
const amber = Color(0xFFFFAE55);
const cream = Color(0xFFEAE5D8);
const muted = Color(0xFF969C8F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmberNightApp());
}

class AmberNightApp extends StatefulWidget {
  const AmberNightApp({super.key, this.device, this.controller});
  final LightDevice? device;
  final NightController? controller;
  @override
  State<AmberNightApp> createState() => _AmberNightAppState();
}

class _AmberNightAppState extends State<AmberNightApp>
    with WidgetsBindingObserver {
  late final NightController controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller =
        widget.controller ??
        NightController(
          widget.device ?? NativeLightDevice(),
          afterBlackFrame: () => WidgetsBinding.instance.endOfFrame.timeout(
            const Duration(milliseconds: 200),
            onTimeout: () {},
          ),
        );
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(controller.suspended());
    } else {
      unawaited(controller.resumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) =>
          Words(Localizations.localeOf(context).languageCode == 'zh').title,
      locale: controller.settings.language == 'system'
          ? null
          : Locale(controller.settings.language),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: amber,
          onPrimary: ink,
          surface: panel,
          onSurface: cream,
          secondary: amber,
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: cream,
          elevation: 0,
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 4,
          inactiveTrackColor: Color(0xFF363C32),
          thumbColor: cream,
          activeTrackColor: amber,
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            foregroundColor: ink,
            backgroundColor: amber,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: muted,
            minimumSize: const Size(48, 48),
          ),
        ),
      ),
      home: NightHome(controller: controller),
    ),
  );
}

class NightHome extends StatefulWidget {
  const NightHome({super.key, required this.controller});
  final NightController controller;
  @override
  State<NightHome> createState() => _NightHomeState();
}

class _NightHomeState extends State<NightHome> {
  NightController get c => widget.controller;
  bool _introScheduled = false;
  Words get words =>
      Words(Localizations.localeOf(context).languageCode == 'zh');

  void _maybeIntro() {
    if (!c.loaded || c.settings.introSeen || _introScheduled) return;
    _introScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showIntro();
    });
  }

  Future<void> _showIntro() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(words.introTitle),
      content: SingleChildScrollView(
        child: Text(words.introBody, style: const TextStyle(height: 1.6)),
      ),
      actions: [
        TextButton(
          onPressed: _openPrivacyPolicy,
          child: Text(words.privacyPolicy),
        ),
        TextButton(
          onPressed: () {
            unawaited(c.updateSettings(c.settings.copyWith(introSeen: true)));
            Navigator.pop(context);
          },
          child: Text(words.understand),
        ),
      ],
    ),
  );

  Future<void> _openPrivacyPolicy() async {
    var opened = false;
    try {
      opened =
          await NativeLightDevice.channel.invokeMethod<bool>(
            'openPrivacyPolicy',
          ) ??
          false;
    } catch (_) {
      // Keep the address available when the system cannot open a browser.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SelectableText(
            'https://yangwagongjuren-ship-it.github.io/amber-night-support/privacy.html',
          ),
        ),
      );
    }
  }

  Future<void> _customDuration() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) =>
          DurationPickerDialog(seconds: c.settings.seconds, words: words),
    );
    if (result != null && mounted) {
      await c.updateSettings(c.settings.copyWith(seconds: result));
    }
  }

  void _story() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(words.storyTitle),
      content: SingleChildScrollView(
        key: const Key('story-scroll'),
        child: Text(words.story, style: const TextStyle(height: 1.7)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(words.done),
        ),
      ],
    ),
  );

  void _about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(words.about),
      content: SingleChildScrollView(
        child: Text(words.privacy, style: const TextStyle(height: 1.6)),
      ),
      actions: [
        TextButton(
          onPressed: _openPrivacyPolicy,
          child: Text(words.privacyPolicy),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(words.done),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    _maybeIntro();
    final active = c.phase != NightPhase.setup;
    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && active) unawaited(c.returnToSetup());
      },
      child: active
          ? LightScreen(controller: c, words: words)
          : AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: ink,
                statusBarIconBrightness: Brightness.light,
              ),
              child: Scaffold(
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: CustomPaint(
                                    painter: CompanionPainter(amber),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    words.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: words.pick('Language', '语言'),
                                  icon: const Icon(
                                    Icons.translate_rounded,
                                    color: muted,
                                    size: 21,
                                  ),
                                  initialValue: c.settings.language,
                                  onSelected: (value) => unawaited(
                                    c.updateSettings(
                                      c.settings.copyWith(language: value),
                                    ),
                                  ),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'system',
                                      child: Text('System / 跟随系统'),
                                    ),
                                    PopupMenuItem(
                                      value: 'en',
                                      child: Text('English'),
                                    ),
                                    PopupMenuItem(
                                      value: 'zh',
                                      child: Text('简体中文'),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: words.about,
                                  onPressed: _about,
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    color: muted,
                                    size: 21,
                                  ),
                                ),
                              ],
                            ),
                            if (c.completed)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  words.completed,
                                  key: const Key('completed'),
                                  style: const TextStyle(
                                    color: cream,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Semantics(
                              label:
                                  '${words.brightness} ${(c.settings.brightness * 100).round()}%',
                              image: true,
                              child: SizedBox(
                                height: 174,
                                child: CustomPaint(
                                  painter: MoonPainter(c.settings.brightness),
                                ),
                              ),
                            ),
                            Text(
                              words.tagline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: cream,
                                height: 1.5,
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('our-story'),
                              onPressed: _story,
                              label: Text(words.storyTitle),
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                              iconAlignment: IconAlignment.end,
                            ),
                            const SizedBox(height: 12),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label(
                                    Icons.hourglass_empty_rounded,
                                    words.duration,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    words.durationHint,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final n in [5, 15, 30])
                                        _durationChip(
                                          words.minuteLabel(n),
                                          c.settings.seconds == n * 60,
                                          () => unawaited(
                                            c.updateSettings(
                                              c.settings.copyWith(minutes: n),
                                            ),
                                          ),
                                        ),
                                      _durationChip(
                                        [
                                              300,
                                              900,
                                              1800,
                                            ].contains(c.settings.seconds)
                                            ? words.custom
                                            : words.durationLabel(
                                                c.settings.seconds,
                                              ),
                                        ![
                                          300,
                                          900,
                                          1800,
                                        ].contains(c.settings.seconds),
                                        _customDuration,
                                        key: const Key('custom-duration'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _label(
                                          Icons.wb_sunny_outlined,
                                          words.brightness,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(c.settings.brightness * 100).round()}%',
                                        style: const TextStyle(
                                          color: amber,
                                          fontSize: 14,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    words.brightnessHint,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Slider(
                                    key: const Key('brightness'),
                                    value: c.settings.brightness,
                                    min: 0.02,
                                    max: 1,
                                    semanticFormatterCallback: (n) =>
                                        '${(n * 100).round()}%',
                                    onChanged: c.loaded
                                        ? (n) => unawaited(
                                            c.updateSettings(
                                              c.settings.copyWith(
                                                brightness: n,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            if (c.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  c.error == 'save'
                                      ? words.saveError
                                      : c.error == 'load'
                                      ? words.loadError
                                      : words.deviceError,
                                  style: const TextStyle(color: amber),
                                ),
                              ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              key: const Key('start'),
                              onPressed: c.loaded
                                  ? () => unawaited(c.start())
                                  : null,
                              icon: const Icon(
                                Icons.nightlight_outlined,
                                size: 19,
                              ),
                              label: Text(words.start),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              words.hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                            TextButton(
                              onPressed: _showIntro,
                              child: Text(
                                words.pick('How auto-lock works', '了解自动息屏'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _label(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: muted, size: 17),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF2B3028)),
    ),
    child: child,
  );
  Widget _durationChip(
    String label,
    bool selected,
    VoidCallback action, {
    Key? key,
  }) => ChoiceChip(
    key: key,
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: c.loaded ? (_) => action() : null,
    selectedColor: const Color(0xFF3F3424),
    backgroundColor: panel,
    side: BorderSide(
      color: selected ? const Color(0xFF846442) : const Color(0xFF3B4035),
    ),
    labelStyle: TextStyle(color: selected ? amber : muted, fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  );
}

class DurationPickerDialog extends StatefulWidget {
  const DurationPickerDialog({
    super.key,
    required this.seconds,
    required this.words,
  });
  final int seconds;
  final Words words;
  @override
  State<DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<DurationPickerDialog> {
  late final values = [
    widget.seconds ~/ 3600,
    widget.seconds ~/ 60 % 60,
    widget.seconds % 60,
  ];
  late final wheels = [
    for (final value in values) FixedExtentScrollController(initialItem: value),
  ];
  int get seconds => values[0] * 3600 + values[1] * 60 + values[2];
  @override
  void dispose() {
    for (final wheel in wheels) {
      wheel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.words;
    final valid = seconds > 0 && seconds <= NightSettings.maxSeconds;
    return AlertDialog(
      title: Text(words.duration),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          [words.hours, words.minutes, words.seconds][index],
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                        SizedBox(
                          height: 168,
                          child: CupertinoTheme(
                            data: const CupertinoThemeData(
                              brightness: Brightness.dark,
                              textTheme: CupertinoTextThemeData(
                                pickerTextStyle: TextStyle(
                                  color: cream,
                                  fontSize: 24,
                                  fontFamily: 'CupertinoSystemDisplay',
                                ),
                              ),
                            ),
                            child: CupertinoPicker.builder(
                              key: Key('duration-wheel-$index'),
                              itemExtent: 42,
                              scrollController: wheels[index],
                              childCount: index == 0 ? null : 60,
                              onSelectedItemChanged: (value) =>
                                  setState(() => values[index] = value),
                              itemBuilder: (context, value) => value < 0
                                  ? null
                                  : Center(child: Text('$value')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Text(
              words.durationLabel(seconds),
              key: const Key('duration-selection'),
              style: const TextStyle(color: amber, fontSize: 14),
            ),
            if (!valid)
              Text(
                words.nonzero,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(words.cancel),
        ),
        TextButton(
          key: const Key('duration-done'),
          onPressed: valid ? () => Navigator.pop(context, seconds) : null,
          child: Text(words.done),
        ),
      ],
    );
  }
}

class LightScreen extends StatefulWidget {
  const LightScreen({super.key, required this.controller, required this.words});
  final NightController controller;
  final Words words;
  @override
  State<LightScreen> createState() => _LightScreenState();
}

class _LightScreenState extends State<LightScreen> {
  bool _controls = false;
  Timer? _hide;
  late NightPhase _lastPhase;
  @override
  void initState() {
    super.initState();
    _lastPhase = widget.controller.phase;
  }

  @override
  void didUpdateWidget(LightScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final phase = widget.controller.phase;
    if (phase == NightPhase.dark && _lastPhase != NightPhase.dark) {
      _controls = false;
      _hide?.cancel();
    }
    _lastPhase = phase;
  }

  void _reveal() {
    if (widget.controller.phase == NightPhase.dark) {
      unawaited(widget.controller.returnToSetup());
      return;
    }
    setState(() => _controls = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final words = widget.words;
    final running = c.phase == NightPhase.running;
    final seconds = (c.remaining.inMilliseconds / 1000).ceil();
    final time =
        '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (instance) => instance.onTap = () {
                  if (c.phase == NightPhase.dark) unawaited(c.returnToSetup());
                },
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(seconds: 1),
                ),
                (instance) => instance.onLongPress = _reveal,
              ),
        },
        child: Semantics(
          label: c.phase == NightPhase.dark ? words.completedTap : words.hint,
          onTap: c.phase == NightPhase.dark
              ? () => unawaited(c.returnToSetup())
              : null,
          onLongPress: _reveal,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                key: const Key('light-surface'),
                color: Color.lerp(Colors.black, amber, c.frame.opacity)!,
              ),
              if (running)
                IgnorePointer(
                  child: Center(
                    child: Column(
                      key: const Key('companion-mark'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: CustomPaint(
                            painter: CompanionPainter(
                              Color.lerp(
                                Colors.black,
                                const Color(0xFF785432),
                                c.frame.opacity,
                              )!,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          words.companion,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.5,
                            color: Color.lerp(
                              Colors.black,
                              const Color(0xFF785432),
                              c.frame.opacity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_controls)
                SafeArea(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xF0000000),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (running) ...[
                            Text(
                              words.remaining,
                              style: const TextStyle(
                                color: Color(0xFF73634E),
                                letterSpacing: 2,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              time,
                              style: const TextStyle(
                                color: Color(0xFF9A805D),
                                fontSize: 36,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                          if (c.error == 'device')
                            Text(
                              words.deviceError,
                              style: const TextStyle(
                                color: Color(0xFF9A805D),
                                fontSize: 13,
                              ),
                            ),
                          TextButton(
                            key: const Key('stop'),
                            onPressed: () => unawaited(c.returnToSetup()),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF9A805D),
                            ),
                            child: Text(running ? words.stop : words.back),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A protective crescent with a heart: companionship without a specific role.
// The same geometry is used by assets/app-icon.svg.
class CompanionPainter extends CustomPainter {
  const CompanionPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final side = math.min(size.width, size.height);
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 200);
    final paint = Paint()..color = color;
    final moon = Path()
      ..addOval(Rect.fromCircle(center: const Offset(98, 100), radius: 76));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: const Offset(127, 78), radius: 66));
    canvas.drawPath(Path.combine(PathOperation.difference, moon, cut), paint);
    canvas.drawPath(
      Path()
        ..moveTo(120, 130)
        ..cubicTo(66, 96, 88, 65, 120, 88)
        ..cubicTo(152, 65, 174, 96, 120, 130)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompanionPainter oldDelegate) =>
      oldDelegate.color != color;
}

class MoonPainter extends CustomPainter {
  MoonPainter(this.brightness);
  final double brightness;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: 84);
    canvas.drawCircle(
      center,
      84,
      Paint()
        ..shader = RadialGradient(
          colors: [
            amber.withValues(alpha: 0.05 + brightness * 0.1),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      65,
      Paint()
        ..color = const Color(0xFF31382B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 76),
      -math.pi * 0.77,
      math.pi * 0.54,
      false,
      Paint()
        ..color = const Color(0xFF535743)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(center.dx - 60, center.dy - 60);
    CompanionPainter(
      Color.lerp(const Color(0xFF9D7347), const Color(0xFFFFD295), brightness)!,
    ).paint(canvas, const Size(120, 120));
    canvas.restore();
    canvas.drawCircle(
      center + const Offset(36, -42),
      2,
      Paint()..color = amber.withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      center + const Offset(-52, 25),
      1.5,
      Paint()..color = const Color(0xFF80785C),
    );
  }

  @override
  bool shouldRepaint(MoonPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
