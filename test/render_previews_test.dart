// Optional render export. Not device screenshots and not a hardware verification.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:amber_night/main.dart';
import 'package:amber_night/night_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fake_device.dart';

void main() {
  testWidgets('export English and Chinese UI previews', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('Roboto')
        ..addFont(
          File(
            'C:/Windows/Fonts/msyh.ttc',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await font.load();
      final fallback = FontLoader('Ahem')
        ..addFont(
          File(
            'C:/Windows/Fonts/msyh.ttc',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await fallback.load();
      for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
        await (FontLoader(family)..addFont(
              File(
                'C:/Windows/Fonts/msyh.ttc',
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            ))
            .load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '.tooling/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
    });
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    for (final language in ['en', 'zh']) {
      final boundary = GlobalKey();
      final device = FakeDevice()
        ..settings = NightSettings(introSeen: true, language: language);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: AmberNightApp(device: device),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) => tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory =
            Platform.environment['PREVIEW_DIR'] ?? 'release/previews';
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/$name-$language.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await capture('home');
      await tester.tap(find.byKey(const Key('custom-duration')));
      await tester.pumpAndSettle();
      await capture('duration');
      await tester.tap(find.text(language == 'zh' ? '取消' : 'Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start')));
      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('companion-mark')), findsOneWidget);
      await capture('running');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: Platform.environment['GENERATE_PREVIEWS'] != '1');
}
