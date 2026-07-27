import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/network/api_client.dart';
import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/features/auth/domain/models/user.dart';
import 'package:gym_client/src/features/auth/presentation/state/auth_notifier.dart';

void main() {
  testWidgets(
    'sin sesión comprueba health y no consulta el estado protegido de sync',
    (tester) async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://local.test'))
        ..httpClientAdapter = adapter;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(dio)],
          child: const MaterialApp(home: _SyncProbe()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(adapter.paths, ['/health']);
      expect(adapter.paths, isNot(contains('/sync/status')));
      expect(find.text('API local disponible · inicia sesión'), findsOneWidget);
    },
  );

  testWidgets('con sesión consulta el estado protegido de sincronización', (
    tester,
  ) async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://local.test'))
      ..httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(dio),
          authProvider.overrideWith(_LoggedInAuthNotifier.new),
        ],
        child: const MaterialApp(home: _SyncProbe()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(adapter.paths, ['/sync/status']);
    expect(find.text('Base local al día'), findsOneWidget);
  });
}

class _SyncProbe extends ConsumerWidget {
  const _SyncProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(syncStatusProvider).value;
    return Text(snapshot?.detail ?? 'esperando');
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final body = options.path == '/sync/status'
        ? '{"pending_events_count":0,"failed_events_count":0,'
              '"remote_status":"online"}'
        : '{"status":"healthy"}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  FutureOr<User?> build() => const User(
    id: 'admin-test',
    name: 'Administración',
    email: 'admin@gym.test',
    role: 'admin',
    token: 'token-test',
  );
}
