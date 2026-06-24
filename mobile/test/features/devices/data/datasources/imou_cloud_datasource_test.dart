import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';

void main() {
  group('ImouCloudDataSourceImpl.getStreamUrl', () {
    test('prefers HTTPS HLS from streams over RTMP', () async {
      final dataSource = ImouCloudDataSourceImpl(
        client: _imouClient(
          liveStreams: [
            {
              'rtmp': 'rtmp://rtmp.example.com/live/private-token',
              'hls': 'https://hls.example.com/live/camera.m3u8?token=private',
              'status': 'ready',
            },
          ],
        ),
      );

      final result = await dataSource.getStreamUrl('camera-id');

      expect(result, 'https://hls.example.com/live/camera.m3u8?token=private');
    });

    test('rejects an RTMP-only response with a controlled code', () async {
      final dataSource = ImouCloudDataSourceImpl(
        client: _imouClient(
          liveStreams: [
            {
              'rtmp': 'rtmp://rtmp.example.com/live/private-token',
              'status': 'ready',
            },
          ],
        ),
      );

      expect(
        () => dataSource.getStreamUrl('camera-id'),
        throwsA(
          isA<ImouCloudException>().having(
            (error) => error.code,
            'code',
            ImouCloudDataSourceImpl.unsupportedStreamFormatCode,
          ),
        ),
      );
    });
  });
}

MockClient _imouClient({required List<Map<String, dynamic>> liveStreams}) {
  return MockClient((request) async {
    final method = request.url.pathSegments.last;
    final data = switch (method) {
      'accessToken' => {'accessToken': 'test-access-token', 'expireTime': 3600},
      'bindDeviceLive' => <String, dynamic>{},
      'getLiveStreamInfo' => {'streams': liveStreams},
      _ => throw StateError('Unexpected Imou method: $method'),
    };

    return http.Response(
      jsonEncode({
        'result': {'code': '0', 'data': data},
      }),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}
