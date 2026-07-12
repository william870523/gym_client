import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_client/src/core/time/app_clock.dart';

void main() {
  test('calibra el reloj con el punto medio de la petición', () async {
    const expectedOffsetMs = 60000;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'server_utc_ms':
              DateTime.now().toUtc().millisecondsSinceEpoch + expectedOffsetMs,
          'gym_timezone': 'America/Havana',
        }),
      );
      await request.response.close();
    });

    final clock = AppClock();
    expect(clock.gymTimezone, 'Etc/UTC');
    await clock.synchronize('http://127.0.0.1:${server.port}');

    expect(
      (clock.offset.inMilliseconds - expectedOffsetMs).abs(),
      lessThan(250),
    );
    expect(clock.gymTimezone, 'America/Havana');
    await server.close(force: true);
  });
}
