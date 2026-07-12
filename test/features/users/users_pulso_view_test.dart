import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_preference.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_provider.dart';
import 'package:gym_client/src/core/theme/pulso/appearance_store.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/users/presentation/providers/users_provider.dart';
import 'package:gym_client/src/features/users/presentation/screens/users_pulso_view.dart';

void main() {
  const sizes = <String, Size>{
    'compacto': Size(390, 844),
    'mediano': Size(760, 900),
    'escritorio': Size(1280, 900),
    'ventana baja': Size(1024, 650),
  };

  for (final entry in sizes.entries) {
    testWidgets('Usuarios PULSO se adapta al ancho ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(find.text('USUARIOS.', findRichText: true), findsOneWidget);
      expect(find.text('María'), findsOneWidget);
      expect(find.text('Pedro'), findsOneWidget);
      expect(find.text('MODO LOCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final row = find.descendant(
        of: find.byKey(const PageStorageKey('pulso-users-list')),
        matching: find.text('María'),
      );
      if (entry.key == 'mediano') {
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      if (entry.key == 'escritorio') {
        await tester.tap(row);
        await tester.pump();
        expect(find.text('DETALLE SELECCIONADO'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resume la distribución de roles', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Administradores'), findsOneWidget);
    expect(find.text('con control total'), findsOneWidget);
    expect(find.text('Recepción'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa cuando no queda ningún administrador activo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        users: [
          const User(
            id: 'u-pedro',
            name: 'Pedro',
            email: 'pedro@gym.test',
            role: 'reception',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ninguno activo — atención'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite editar un usuario y guarda los cambios', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final usersNotifier = _UsersNotifier(_users());
    await tester.pumpWidget(_harness(usersNotifier: usersNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar María'));
    await tester.pumpAndSettle();
    // Formulario PULSO en diálogo: el shell sigue visible detrás.
    expect(find.text('EDITAR USUARIO'), findsOneWidget);
    expect(find.text('USUARIOS.', findRichText: true), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-name')),
      'María Luisa',
    );
    await tester.tap(find.text('GUARDAR CAMBIOS'));
    await tester.pumpAndSettle();

    expect(usersNotifier.updates, hasLength(1));
    final updated = usersNotifier.updates.single;
    expect(updated.id, 'u-maria');
    expect(updated.name, 'María Luisa');
    expect(updated.role, 'admin');
    // Sin restablecer contraseña, no se envía ninguna.
    expect(updated.password, isNull);
    expect(find.text('EDITAR USUARIO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear usuario exige contraseña segura y confirmada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final usersNotifier = _UsersNotifier(_users());
    await tester.pumpWidget(_harness(usersNotifier: usersNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NUEVO USUARIO'));
    await tester.pumpAndSettle();
    expect(find.text('NUEVO USUARIO'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-name')),
      'Laura Fernández',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-email')),
      'laura@gym.test',
    );
    // Contraseña débil: no debe crear.
    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-password')),
      'abc',
    );
    await tester.tap(find.text('CREAR'));
    await tester.pumpAndSettle();
    expect(usersNotifier.creates, isEmpty);
    expect(
      find.text('La contraseña no cumple los requisitos de seguridad.'),
      findsOneWidget,
    );

    // Contraseña válida y confirmada: crea con el rol elegido.
    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-password')),
      'Abcdef1!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pulso-user-password-confirm')),
      'Abcdef1!',
    );
    await tester.tap(find.text('CREAR'));
    await tester.pumpAndSettle();

    expect(usersNotifier.creates, hasLength(1));
    final created = usersNotifier.creates.single;
    expect(created.name, 'Laura Fernández');
    expect(created.email, 'laura@gym.test');
    expect(created.password, 'Abcdef1!');
    expect(created.role, 'reception');
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra usuarios inactivos', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inactivos').last);
    await tester.pump();
    final list = find.byKey(const PageStorageKey('pulso-users-list'));
    expect(
      find.descendant(of: list, matching: find.text('Carla')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('María')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

List<User> _users() => const [
  User(id: 'u-maria', name: 'María', email: 'maria@gym.test', role: 'admin'),
  User(id: 'u-pedro', name: 'Pedro', email: 'pedro@gym.test', role: 'reception'),
  User(
    id: 'u-carla',
    name: 'Carla',
    email: 'carla@gym.test',
    role: 'reception',
    active: false,
  ),
];

Widget _harness({List<User>? users, _UsersNotifier? usersNotifier}) {
  return ProviderScope(
    overrides: [
      appearanceStoreProvider.overrideWithValue(_MemoryAppearanceStore()),
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          SyncStatusSnapshot.offline(
            detail: 'API remota no disponible',
            source: 'sync-local',
          ),
        ),
      ),
      usersProvider.overrideWith(
        () => usersNotifier ?? _UsersNotifier(users ?? _users()),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: UsersPulsoView())),
  );
}

class _UsersNotifier extends Users {
  _UsersNotifier(this.items);
  final List<User> items;
  final updates = <User>[];
  final creates = <User>[];

  @override
  Future<List<User>> build() async => items;

  @override
  Future<void> updateUser(User user) async {
    updates.add(user);
  }

  @override
  Future<void> createUser(User user) async {
    creates.add(user);
  }
}

class _MemoryAppearanceStore implements AppearanceStore {
  @override
  Future<AppearancePreference?> load() async => null;

  @override
  Future<void> save(AppearancePreference preference) async {}
}
