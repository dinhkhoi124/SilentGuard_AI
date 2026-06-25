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

    test(
      'prefers a ready HTTPS HLS stream over an earlier inactive one',
      () async {
        final dataSource = ImouCloudDataSourceImpl(
          client: _imouClient(
            liveStreams: [
              {
                'hls': 'https://stale.example.com/live/camera.m3u8?token=old',
                'status': 'pending',
              },
              {
                'hls': 'https://ready.example.com/live/camera.m3u8?token=fresh',
                'status': 'active',
              },
            ],
          ),
        );

        final result = await dataSource.getStreamUrl('camera-id');

        expect(
          result,
          'https://ready.example.com/live/camera.m3u8?token=fresh',
        );
      },
    );

    test('passes liveToken and streamId to getLiveStreamInfo', () async {
      Map<String, dynamic>? infoParams;
      final dataSource = ImouCloudDataSourceImpl(
        client: _imouClient(
          bindData: const {
            'liveToken': 'private-live-token',
            'streamId': 'stream-123',
          },
          onInfoParams: (params) => infoParams = params,
          liveStreams: [
            {
              'hls': 'https://ready.example.com/live/camera.m3u8',
              'status': 'ready',
            },
          ],
        ),
      );

      await dataSource.getStreamUrl('camera-id');

      expect(infoParams?['liveToken'], 'private-live-token');
      expect(infoParams?['streamId'], 'stream-123');
    });

    test('rejects HLS served on inaccessible port 8890', () async {
      final dataSource = ImouCloudDataSourceImpl(
        client: _imouClient(
          liveStreams: [
            {
              'hls': 'http://hls.example.com:8890/live/camera.m3u8',
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
            'device_no_response',
          ),
        ),
      );
    });
  });
}

MockClient _imouClient({
  required List<Map<String, dynamic>> liveStreams,
  Map<String, dynamic> bindData = const {},
  void Function(Map<String, dynamic> params)? onInfoParams,
}) {
  return MockClient((request) async {
    final method = request.url.pathSegments.last;
    final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
    final params = Map<String, dynamic>.from(requestBody['params'] as Map);
    if (method == 'getLiveStreamInfo') onInfoParams?.call(params);
    final data = switch (method) {
      'accessToken' => {'accessToken': 'test-access-token', 'expireTime': 3600},
      'bindDeviceLive' => bindData,
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
