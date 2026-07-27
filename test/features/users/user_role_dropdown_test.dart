import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_palette_id.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_theme.dart';
import 'package:gym_client/src/core/theme/pulso/pulso_tokens.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/users/presentation/widgets/user_pulso_form.dart';

/// Abrir la ficha de un usuario **no puede** reventar el formulario.
///
/// Pasó el 26-07-2026: una cuenta con el rol `recepcionista` —fuera de la lista
/// canónica del sistema— disparaba una aserción de `DropdownButtonFormField`
/// («exactly one item with value») y tumbaba la pantalla entera. Le puede pasar
/// a cualquier cuenta heredada: el esquema trae `role` por defecto en `user`,
/// que tampoco está en la lista.
Widget _harness(User user) {
  return ProviderScope(
    child: MaterialApp(
      theme: PulsoThemeFactory.build(
        PulsoTokens.resolve(PulsoPaletteId.clay, Brightness.light),
      ),
      home: Scaffold(
        body: UserPulsoForm(user: user, onSubmit: (_) async {}),
      ),
    ),
  );
}

User _user({required String role}) => User(
  id: 'u-1',
  name: 'Cuenta Heredada',
  email: 'cuenta@gym.test',
  role: role,
);

void main() {
  testWidgets('un rol conocido se muestra con su etiqueta', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_user(role: 'reception')));
    await tester.pumpAndSettle();

    expect(find.text('Recepción'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final role in const ['recepcionista', 'user', 'supervisor']) {
    testWidgets('un rol heredado ($role) abre la ficha en vez de romperla', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(_user(role: role)));
      await tester.pumpAndSettle();

      // Se conserva el valor tal cual y se rotula como heredado: abrir la
      // ficha no debe cambiarle el rol a nadie por su cuenta.
      expect(find.text('$role (rol heredado)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
