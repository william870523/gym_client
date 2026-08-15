import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/features/auth/domain/models/sede_session.dart';
import 'package:gym_client/src/features/auth/presentation/state/sede_session_provider.dart';
import 'package:gym_client/src/features/configuration/presentation/widgets/global_catalog_authority.dart';

void main() {
  Widget app(bool platform) => ProviderScope(
    overrides: [
      sedeSessionProvider.overrideWith(() => _Session(platform)),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: GlobalCatalogAuthority(
          readOnly: Text('Solo lectura'),
          child: Text('Editar catálogo'),
        ),
      ),
    ),
  );

  testWidgets('una sesión de sede no ve mutaciones del catálogo global', (
    tester,
  ) async {
    await tester.pumpWidget(app(false));
    expect(find.text('Solo lectura'), findsOneWidget);
    expect(find.text('Editar catálogo'), findsNothing);
  });

  testWidgets('el dueño de cadena conserva los controles globales', (
    tester,
  ) async {
    await tester.pumpWidget(app(true));
    expect(find.text('Editar catálogo'), findsOneWidget);
    expect(find.text('Solo lectura'), findsNothing);
  });
}

class _Session extends SedeSessionNotifier {
  _Session(this.platform);

  final bool platform;

  @override
  SedeSession? build() => SedeSession(
    userId: 'user',
    gymId: 'gym',
    role: 'admin',
    esPlataforma: platform,
  );
}
