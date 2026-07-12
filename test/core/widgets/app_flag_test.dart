import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/widgets/app_flag.dart';

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
}
