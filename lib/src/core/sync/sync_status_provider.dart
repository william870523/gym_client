import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  yield SyncStatusSnapshot.checking();

  while (true) {
    yield await _loadSyncStatus(client);
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});

Future<SyncStatusSnapshot> _loadSyncStatus(Dio client) async {
  if (kIsWeb) {
    return _loadRemoteApiStatus(client);
  }

  if (isDesktopPlatform) {
    return _loadLocalSyncStatus(client);
  }

  return _loadRemoteApiStatus(client);
}

Future<SyncStatusSnapshot> _loadRemoteApiStatus(Dio client) async {
  try {
    await client.get<dynamic>('/health').timeout(const Duration(seconds: 5));
    return SyncStatusSnapshot(
      level: SyncStatusLevel.synced,
      label: 'API conectada',
      detail: 'Servicio remoto disponible',
      checkedAt: appClock.nowUtc(),
      source: 'api-remota',
    );
  } catch (error) {
    return SyncStatusSnapshot.offline(
      detail: 'Sin conexión con la API remota',
      source: 'api-remota',
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
