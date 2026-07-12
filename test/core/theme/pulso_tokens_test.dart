import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';

void main() {
  group('PulsoTokens', () {
    for (final palette in PulsoPaletteId.values) {
      for (final brightness in Brightness.values) {
        test(
          '${palette.storageValue} ${brightness.name} mantiene contraste AA',
          () {
            final tokens = PulsoTokens.resolve(palette, brightness);

            expect(tokens.palette, palette);
            expect(tokens.brightness, brightness);
            expect(
              _contrast(tokens.chalk, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.muted, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.accent, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.accentInk, tokens.accent),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.success, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.warning, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              _contrast(tokens.danger, tokens.surface),
              greaterThanOrEqualTo(4.5),
            );
          },
        );
      }
    }
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
