import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gym_client/src/core/widgets/app_flag.dart';
import 'package:gym_client/src/core/widgets/base64_image.dart';
import 'package:gym_client/src/core/widgets/flag_image.dart';

void main() {
  testWidgets('usa un marco rectangular por defecto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppFlag(fallbackCode: 'ARS')),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppFlag)), const Size(30, 20));
    expect(find.text('AR'), findsOneWidget);
  });

  testWidgets('preserva la imagen completa con filtrado de alta calidad', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR42mP8z8BQDwAEhQGAhKwMtQAAAABJRU5ErkJggg==',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppFlag(bytes: bytes)),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.filterQuality, FilterQuality.high);
    expect(image.width, 30);
    expect(image.height, 20);
  });

  testWidgets('renderiza SVG centrado y contenido dentro del marco', (
    tester,
  ) async {
    final svg = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 3">'
        '<rect width="4" height="3" fill="red"/></svg>',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppFlag(bytes: svg)),
      ),
    );
    await tester.pump();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.fit, BoxFit.contain);
    expect(picture.alignment, Alignment.center);
    expect(picture.width, 30);
    expect(picture.height, 20);
    expect(tester.getSize(find.byType(AppFlag)), const Size(30, 20));
  });

  testWidgets('Base64Image detecta SVG recibido por la API', (tester) async {
    final encoded = base64Encode(
      utf8.encode(
        '<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 4 3"><path fill="blue" d="M0 0h4v3H0z"/></svg>',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Base64Image(
            base64String: encoded,
            width: 42,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
    await tester.pump();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.fit, BoxFit.contain);
    expect(picture.alignment, Alignment.center);
    expect(picture.width, 42);
    expect(picture.height, 28);
  });

  test('la preparación conserva el SVG byte a byte', () {
    final svg = Uint8List.fromList(
      utf8.encode(
        '\uFEFF  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 3"/>',
      ),
    );

    expect(isSvgBytes(svg), isTrue);
    expect(normalizeFlagImageBytes(svg), orderedEquals(svg));
    expect(flagUploadFilename(svg), 'flag.svg');
  });
}
