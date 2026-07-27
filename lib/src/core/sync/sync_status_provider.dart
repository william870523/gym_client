import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/state/auth_notifier.dart';
import '../network/api_client.dart';
import '../time/app_clock.dart';
import '../utils/datetime_zone.dart';
import '../window/window_manager.dart';

enum SyncStatusLevel { checking, synced, pending, offline }

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.level,
    required this.label,
    required this.detail,
    required this.checkedAt,
    this.pendingEvents = 0,
    this.lastServerSyncAt,
    this.lastUploadAt,
    this.source = 'api',
    this.errorMessage,
  });

  factory SyncStatusSnapshot.checking() {
    return SyncStatusSnapshot(
      level: SyncStatusLevel.checking,
      label: 'Verificando',
      detail: 'Comprobando conexión',
      checkedAt: appClock.nowUtc(),
      source: kIsWeb ? 'api-remota' : 'api-local',
    );
  }

  factory SyncStatusSnapshot.offline({
    required String detail,
    required String source,
    String? errorMessage,
    int pendingEvents = 0,
  }) {
    return SyncStatusSnapshot(
      level: SyncStatusLevel.offline,
      label: 'Reintento luego',
      detail: detail,
      checkedAt: appClock.nowUtc(),
      source: source,
      pendingEvents: pendingEvents,
      errorMessage: errorMessage,
    );
  }

  final SyncStatusLevel level;
  final String label;
  final String detail;
  final int pendingEvents;
  final DateTime? lastServerSyncAt;
  final DateTime? lastUploadAt;
  final DateTime checkedAt;
  final String source;
  final String? errorMessage;

  bool get isHealthy => level == SyncStatusLevel.synced;
  bool get hasPendingWork => pendingEvents > 0;

  String get lastSyncLabel {
    final date = lastUploadAt ?? lastServerSyncAt;
    if (date == null) return 'Sin registro';

    final gymTime = toGymWallClock(date, appClock.gymTimezone);
    final hour = gymTime.hour.toString().padLeft(2, '0');
    final minute = gymTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

final syncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) async* {
  final client = ref.watch(apiClientProvider);
  final authenticated =
      ref.watch(authProvider).value?.token?.isNotEmpty == true;
  var disposed = false;
  Timer? pollTimer;
  Completer<void>? pollDelay;
  ref.onDispose(() {
    disposed = true;
    pollTimer?.cancel();
    final delay = pollDelay;
    if (delay != null && !delay.isCompleted) {
      delay.complete();
    }
  });

  yield SyncStatusSnapshot.checking();

  while (!disposed) {
    yield await _loadSyncStatus(client, authenticated: authenticated);
    pollDelay = Completer<void>();
    pollTimer = Timer(const Duration(seconds: 15), pollDelay.complete);
    await pollDelay.future;
  }
});

Future<SyncStatusSnapshot> _loadSyncStatus(
  Dio client, {
  required bool authenticated,
}) async {
  if (kIsWeb) {
    return _loadApiAvailability(
      client,
      source: 'api-remota',
      availableDetail: 'Servicio remoto disponible',
      unavailableDetail: 'Sin conexión con la API remota',
    );
  }

  if (isDesktopPlatform) {
    // El chip también existe en la pantalla de acceso. /sync/status está
    // protegido deliberadamente, por lo que antes del login solo comprobamos
    // la ruta pública /health y evitamos llenar el registro con 401 esperados.
    if (!authenticated) {
      return _loadApiAvailability(
        client,
        source: 'api-local',
        availableDetail: 'API local disponible · inicia sesión',
        unavailableDetail: 'API local no responde',
      );
    }
    return _loadLocalSyncStatus(client);
  }

  return _loadApiAvailability(
    client,
    source: 'api-remota',
    availableDetail: 'Servicio remoto disponible',
    unavailableDetail: 'Sin conexión con la API remota',
  );
}

Future<SyncStatusSnapshot> _loadApiAvailability(
  Dio client, {
  required String source,
  required String availableDetail,
  required String unavailableDetail,
}) async {
  try {
    await client.get<dynamic>('/health').timeout(const Duration(seconds: 5));
    return SyncStatusSnapshot(
      level: SyncStatusLevel.synced,
      label: 'API conectada',
      detail: availableDetail,
      checkedAt: appClock.nowUtc(),
      source: source,
    );
  } catch (error) {
    return SyncStatusSnapshot.offline(
      detail: unavailableDetail,
      source: source,
      errorMessage: error.toString(),
    );
  }
}

Future<SyncStatusSnapshot> _loadLocalSyncStatus(Dio client) async {
  try {
    final response = await client
        .get<Map<String, dynamic>>('/sync/status')
        .timeout(const Duration(seconds: 5));

    final data = response.data ?? <String, dynamic>{};
    final pendingEvents = _asInt(data['pending_events_count']);
    final failedEvents = _asInt(data['failed_events_count']);
    final remoteStatus = (data['remote_status'] ?? data['status'] ?? '')
        .toString()
        .toLowerCase();
    final lastServerSyncAt = _asDateTime(data['last_server_sync_at']);
    final lastUploadAt = _asDateTime(data['last_upload_at']);

    if (remoteStatus == 'offline') {
      return SyncStatusSnapshot(
        level: SyncStatusLevel.offline,
        label: 'Reintento luego',
        detail: pendingEvents > 0
            ? '$pendingEvents cambio(s) en cola'
            : 'API remota no disponible',
        pendingEvents: pendingEvents,
        lastServerSyncAt: lastServerSyncAt,
        lastUploadAt: lastUploadAt,
        checkedAt: appClock.nowUtc(),
        source: 'sync-local',
        errorMessage: data['remote_error']?.toString(),
      );
    }

    if (pendingEvents > 0) {
      return SyncStatusSnapshot(
        level: SyncStatusLevel.pending,
        label: 'Pendiente',
        detail: failedEvents > 0
            ? '$failedEvents cambio(s) requieren revisión'
            : '$pendingEvents cambio(s) por sincronizar',
        pendingEvents: pendingEvents,
        lastServerSyncAt: lastServerSyncAt,
        lastUploadAt: lastUploadAt,
        checkedAt: appClock.nowUtc(),
        source: 'sync-local',
      );
    }

    return SyncStatusSnapshot(
      level: SyncStatusLevel.synced,
      label: 'Sincronizado',
      detail: 'Base local al día',
      pendingEvents: pendingEvents,
      lastServerSyncAt: lastServerSyncAt,
      lastUploadAt: lastUploadAt,
      checkedAt: appClock.nowUtc(),
      source: 'sync-local',
    );
  } catch (error) {
    return SyncStatusSnapshot.offline(
      detail: 'API local no responde',
      source: 'api-local',
      errorMessage: error.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
