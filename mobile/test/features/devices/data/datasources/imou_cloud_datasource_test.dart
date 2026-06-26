import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';

void main() {
  group('ImouCloudDataSourceImpl', () {
    test('getAccessToken posts nested system block and empty params', () async {
      Map<String, dynamic>? requestBody;
      final dataSource = _dataSource((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _imouResponse(
          data: {'accessToken': 'access-token', 'expireTime': 4102444800},
        );
      });

      final token = await dataSource.getAccessToken();

      expect(token.token, 'access-token');
      expect(requestBody?['params'], isEmpty);
      expect(requestBody?['id'], isA<String>());
      _expectSystemBlock(requestBody);
    });

    test('getAccessToken parses Imou result.data payload', () async {
      final dataSource = _dataSource(
        (_) async => _imouResponse(
          data: {
            'accessToken': 'nested-access-token',
            'expireTime': 4102444800,
          },
          nestDataInResult: true,
        ),
      );

      final token = await dataSource.getAccessToken();

      expect(token.token, 'nested-access-token');
    });

    test('bindDeviceLive posts device and stream params', () async {
      Map<String, dynamic>? requestBody;
      final dataSource = _dataSource((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _imouResponse();
      });

      await dataSource.bindDeviceLive(
        accessToken: 'access-token',
        deviceSn: 'CAM123',
        channelId: '1',
        streamId: 1,
      );

      expect(requestBody?['id'], isA<String>());
      _expectSystemBlock(requestBody);
      expect(requestBody?['params'], {
        'token': 'access-token',
        'deviceId': 'CAM123',
        'channelId': '1',
        'streamId': 1,
      });
    });

    test('bindDeviceLive treats existing live session as success', () async {
      final dataSource = _dataSource(
        (_) async =>
            _imouResponse(code: 'LV1001', msg: 'The video live exists.'),
      );

      await expectLater(
        dataSource.bindDeviceLive(
          accessToken: 'access-token',
          deviceSn: 'CAM123',
        ),
        completes,
      );
    });

    test('getLiveStreamInfo parses live token and URLs', () async {
      final dataSource = _dataSource(
        (_) async => _imouResponse(
          data: {
            'liveToken': 'live-token',
            'hls': 'https://hls.example.com/live/camera.m3u8',
            'flv': 'https://flv.example.com/live/camera.flv',
            'status': 'ready',
          },
        ),
      );

      final result = await dataSource.getLiveStreamInfo(
        accessToken: 'access-token',
        deviceSn: 'CAM123',
      );

      expect(result.liveToken, 'live-token');
      expect(result.hlsUrl, 'https://hls.example.com/live/camera.m3u8');
      expect(result.flvUrl, 'https://flv.example.com/live/camera.flv');
      expect(result.status, 'ready');
    });

    test('getLiveStreamInfo selects playable HLS from streams list', () async {
      final dataSource = _dataSource(
        (_) async => _imouResponse(
          data: {
            'streams': [
              {
                'streamId': 0,
                'status': '1',
                'hls': 'https://hls.example.com:8890/live/camera.m3u8',
                'liveToken': 'blocked-token',
              },
              {
                'streamId': 0,
                'status': '1',
                'hls': 'http://hls.example.com:8888/live/camera.m3u8',
                'liveToken': 'live-token',
              },
            ],
          },
        ),
      );

      final result = await dataSource.getLiveStreamInfo(
        accessToken: 'access-token',
        deviceSn: 'CAM123',
      );

      expect(result.liveToken, 'live-token');
      expect(result.hlsUrl, 'http://hls.example.com:8888/live/camera.m3u8');
      expect(result.status, '1');
    });

    test('unbindLive posts live token', () async {
      Map<String, dynamic>? requestBody;
      final dataSource = _dataSource((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _imouResponse();
      });

      await dataSource.unbindLive(
        accessToken: 'access-token',
        liveToken: 'live-token',
      );

      _expectSystemBlock(requestBody);
      expect(requestBody?['params'], {
        'token': 'access-token',
        'liveToken': 'live-token',
      });
    });

    test('getDeviceList parses devices', () async {
      final dataSource = _dataSource(
        (_) async => _imouResponse(
          data: {
            'devices': [
              {
                'deviceSn': 'CAM123',
                'deviceName': 'Living Room',
                'status': 'online',
                'channelId': '0',
              },
            ],
          },
        ),
      );

      final devices = await dataSource.getDeviceList(
        accessToken: 'access-token',
      );

      expect(devices.single.deviceSn, 'CAM123');
      expect(devices.single.deviceName, 'Living Room');
      expect(devices.single.channelId, '0');
    });

    test('isDeviceOnline calls deviceOnline endpoint with deviceId', () async {
      Map<String, dynamic>? requestBody;
      final dataSource = _dataSource((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _imouResponse(data: {'onLine': '1'});
      });

      final isOnline = await dataSource.isDeviceOnline(
        accessToken: 'access-token',
        deviceSn: 'CAM123',
      );

      expect(isOnline, isTrue);
      expect(requestBody?['params'], {
        'token': 'access-token',
        'deviceId': 'CAM123',
      });
    });

    test('throws ImouApiException when result code is not successful', () {
      final dataSource = _dataSource(
        (_) async => _imouResponse(code: 'device_no_response', msg: 'Offline'),
      );

      expect(
        () => dataSource.getLiveStreamInfo(
          accessToken: 'access-token',
          deviceSn: 'CAM123',
        ),
        throwsA(
          isA<ImouApiException>()
              .having((error) => error.code, 'code', 'device_no_response')
              .having((error) => error.message, 'message', 'Offline'),
        ),
      );
    });
  });
}

ImouCloudDataSourceImpl _dataSource(
  Future<http.Response> Function(http.Request request) handler,
) {
  return ImouCloudDataSourceImpl(
    apiClient: ApiClient(
      client: MockClient(handler),
      baseUrl: 'https://openapi-sg.easy4ip.com/openapi',
    ),
    appId: 'app-id',
    appSecret: 'app-secret',
  );
}

void _expectSystemBlock(Map<String, dynamic>? requestBody) {
  final system = Map<String, dynamic>.from(requestBody?['system'] as Map);
  final timestamp = system['time'] as int;
  final nonce = system['nonce'] as String;
  final expectedSign = md5
      .convert(utf8.encode('time:$timestamp,nonce:$nonce,appSecret:app-secret'))
      .toString();

  expect(system['ver'], '1.0');
  expect(system['appId'], 'app-id');
  expect(timestamp, lessThan(10000000000));
  expect(nonce, isNotEmpty);
  expect(nonce, isNot(contains('=')));
  expect(system['sign'], expectedSign);
  expect(system['sign'], expectedSign.toLowerCase());
}

http.Response _imouResponse({
  String code = '0',
  String msg = 'OK',
  Map<String, dynamic> data = const {},
  bool nestDataInResult = false,
}) {
  return http.Response(
    jsonEncode({
      'result': {'code': code, 'msg': msg, if (nestDataInResult) 'data': data},
      if (!nestDataInResult) 'data': data,
    }),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
