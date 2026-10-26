// Renders the app's rider-on-a-bike logo (Icons.directions_bike on the brand
// gradient) into the PNGs used for the launcher icon and the native splash.
//
// Run:  flutter test tool/generate_brand_assets_test.dart
// Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bike_transit/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDir = 'assets/branding';
const _teal = Color(0xFF168A83); // light theme secondary

Future<void> _loadIconFont() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final bytes = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
      .readAsBytesSync();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

Shader _gradient(Rect r) => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.brandBlue, _teal],
    ).createShader(r);

void _drawRider(Canvas canvas, Offset center, double size) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(Icons.directions_bike.codePoint),
      style: TextStyle(
        fontFamily: Icons.directions_bike.fontFamily,
        fontSize: size,
        color: Colors.white,
      ),
    ),
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

Future<void> _write(
  String name,
  int size,
  void Function(Canvas canvas, double s) draw,
) async {
  final recorder = ui.PictureRecorder();
  final s = size.toDouble();
  draw(Canvas(recorder, Rect.fromLTWH(0, 0, s, s)), s);
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_outDir/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('generate brand assets', (tester) async {
    await tester.runAsync(() async {
      await _loadIconFont();
      final full = Rect.fromLTWH(0, 0, 1024, 1024);

      // Full-bleed icon (iOS + legacy Android).
      await _write('app_icon.png', 1024, (c, s) {
        c.drawRect(full, Paint()..shader = _gradient(full));
        _drawRider(c, Offset(s / 2, s / 2), s * 0.6);
      });

      // Android adaptive icon: gradient background + rider inside the safe zone.
      await _write('app_icon_background.png', 1024, (c, s) {
        c.drawRect(full, Paint()..shader = _gradient(full));
      });
      await _write('app_icon_foreground.png', 1024, (c, s) {
        _drawRider(c, Offset(s / 2, s / 2), s * 0.7);
      });

      // Splash: the in-app logo (gradient circle + white rider).
      void logo(Canvas c, double canvas, double diameter) {
        final center = Offset(canvas / 2, canvas / 2);
        final circle = Rect.fromCircle(center: center, radius: diameter / 2);
        c.drawOval(circle, Paint()..shader = _gradient(circle));
        _drawRider(c, center, diameter * 0.5);
      }

      await _write('splash_logo.png', 640, (c, s) => logo(c, s, s));
      // Android 12+: 1152 px image whose content fits a 768 px circle.
      await _write('splash_android12.png', 1152, (c, s) => logo(c, s, 720));
    });
  });
}
