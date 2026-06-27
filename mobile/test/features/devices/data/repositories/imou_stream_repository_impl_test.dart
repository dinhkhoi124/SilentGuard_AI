import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/data/models/imou_models.dart';
import 'package:mobile/features/devices/data/repositories/imou_stream_repository_impl.dart';

void main() {
  const deviceId = 'CAM123456';

  group('ImouStreamRepositoryImpl', () {
    test(
      'unbinds bind token when closed before bindDeviceLive completes',
      () async {
        final bindStarted = Completer<void>();
        final bindCompleter = Completer<String?>();
        final dataSource = _FakeImouCloudDataSource()
          ..bindDeviceLiveHandler =
              ({
                required accessToken,
                required deviceSn,
                required channelId,
                required streamId,
              }) {
                bindStarted.complete();
                return bindCompleter.future;
              };
        final repository = ImouStreamRepositoryImpl(dataSource);

        final startFuture = repository.getStreamUrl(deviceId);
        await bindStarted.future;
        await repository.releaseStreamSession(deviceId);
        bindCompleter.complete('bind_token');

        await expectLater(
          startFuture,
          throwsA(isA<LiveStartCancelledException>()),
        );
        expect(repository.hasActiveSession(deviceId), isFalse);
        expect(dataSource.unboundLiveTokens, ['bind_token']);
        expect(dataSource.getLiveStreamInfoCalls, 0);
      },
    );

    test('unbinds bind token when getLiveStreamInfo fails', () async {
      final dataSource = _FakeImouCloudDataSource();
      dataSource.bindDeviceLiveHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
            required streamId,
          }) async => 'bind_token';
      dataSource.getLiveStreamInfoHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
          }) async {
            throw TimeoutException('network timeout');
          };
      final repository = ImouStreamRepositoryImpl(dataSource);

      await expectLater(
        repository.getStreamUrl(deviceId),
        throwsA(isA<TimeoutException>()),
      );
      expect(repository.hasActiveSession(deviceId), isFalse);
      expect(dataSource.unboundLiveTokens, ['bind_token']);
    });

    test('unbinds bind token when no playable stream is returned', () async {
      final dataSource = _FakeImouCloudDataSource();
      dataSource.bindDeviceLiveHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
            required streamId,
          }) async => 'bind_token';
      dataSource.getLiveStreamInfoHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
          }) async => const ImouLiveStreamInfo(streams: [], status: 'ready');
      final repository = ImouStreamRepositoryImpl(dataSource);

      await expectLater(
        repository.getStreamUrl(deviceId),
        throwsA(
          isA<ImouApiException>().having(
            (error) => error.code,
            'code',
            'NO_STREAM_URL',
          ),
        ),
      );
      expect(repository.hasActiveSession(deviceId), isFalse);
      expect(dataSource.unboundLiveTokens, ['bind_token']);
    });

    test(
      'unbinds tokens when closed after bind before stream info completes',
      () async {
        final infoStarted = Completer<void>();
        final infoCompleter = Completer<ImouLiveStreamInfo>();
        final dataSource = _FakeImouCloudDataSource();
        dataSource.bindDeviceLiveHandler =
            ({
              required accessToken,
              required deviceSn,
              required channelId,
              required streamId,
            }) async => 'bind_token';
        dataSource.getLiveStreamInfoHandler =
            ({required accessToken, required deviceSn, required channelId}) {
              infoStarted.complete();
              return infoCompleter.future;
            };
        final repository = ImouStreamRepositoryImpl(dataSource);

        final startFuture = repository.getStreamUrl(deviceId);
        await infoStarted.future;
        await repository.releaseStreamSession(deviceId);
        infoCompleter.complete(_streamInfo(liveToken: 'sd_token'));

        await expectLater(
          startFuture,
          throwsA(isA<LiveStartCancelledException>()),
        );
        expect(repository.hasActiveSession(deviceId), isFalse);
        expect(
          dataSource.unboundLiveTokens,
          unorderedEquals(['bind_token', 'sd_token']),
        );
      },
    );

    test('normal start then stop saves and removes active session', () async {
      final dataSource = _FakeImouCloudDataSource();
      dataSource.bindDeviceLiveHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
            required streamId,
          }) async => 'bind_token';
      dataSource.getLiveStreamInfoHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
          }) async => _streamInfo(liveToken: 'sd_token');
      final repository = ImouStreamRepositoryImpl(dataSource);

      final url = await repository.getStreamUrl(deviceId);

      expect(url, 'https://sd.example.com/live/camera.m3u8');
      expect(repository.hasActiveSession(deviceId), isTrue);
      expect(repository.activeSessionLiveToken(deviceId), 'sd_token');

      await repository.releaseStreamSession(deviceId);

      expect(repository.hasActiveSession(deviceId), isFalse);
      expect(dataSource.unboundLiveTokens, ['sd_token']);
    });

    test('stop is idempotent', () async {
      final dataSource = _FakeImouCloudDataSource();
      final repository = ImouStreamRepositoryImpl(dataSource);

      await repository.releaseStreamSession(deviceId);
      await repository.releaseStreamSession(deviceId);

      expect(repository.hasActiveSession(deviceId), isFalse);
      expect(dataSource.unboundLiveTokens, isEmpty);
    });

    test('old request cannot overwrite or unbind new session', () async {
      final bindStarted = [Completer<void>(), Completer<void>()];
      final bindCompleters = [Completer<String?>(), Completer<String?>()];
      var bindCall = 0;
      final dataSource = _FakeImouCloudDataSource()
        ..bindDeviceLiveHandler =
            ({
              required accessToken,
              required deviceSn,
              required channelId,
              required streamId,
            }) {
              final index = bindCall++;
              bindStarted[index].complete();
              return bindCompleters[index].future;
            }
        ..getLiveStreamInfoHandler =
            ({
              required accessToken,
              required deviceSn,
              required channelId,
            }) async => _streamInfo(
              hls: 'https://sd.example.com/live/new-camera.m3u8',
              liveToken: 'token_b',
            );
      final repository = ImouStreamRepositoryImpl(dataSource);

      final futureA = repository.getStreamUrl(deviceId);
      await bindStarted[0].future;
      await repository.releaseStreamSession(deviceId);

      final futureB = repository.getStreamUrl(deviceId);
      await bindStarted[1].future;
      bindCompleters[1].complete('bind_b');
      final urlB = await futureB;

      bindCompleters[0].complete('bind_a');
      await expectLater(futureA, throwsA(isA<LiveStartCancelledException>()));

      expect(urlB, 'https://sd.example.com/live/new-camera.m3u8');
      expect(repository.activeSessionLiveToken(deviceId), 'token_b');
      expect(dataSource.unboundLiveTokens, contains('bind_a'));
      expect(dataSource.unboundLiveTokens, isNot(contains('token_b')));
    });

    test('selected stream liveToken has priority over bind token', () async {
      final dataSource = _FakeImouCloudDataSource();
      dataSource.bindDeviceLiveHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
            required streamId,
          }) async => 'bind_token';
      dataSource.getLiveStreamInfoHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
          }) async => _streamInfo(liveToken: 'sd_token');
      final repository = ImouStreamRepositoryImpl(dataSource);

      await repository.getStreamUrl(deviceId);
      await repository.releaseStreamSession(deviceId);

      expect(dataSource.unboundLiveTokens, ['sd_token']);
    });

    test('bind token is used when selected stream has no liveToken', () async {
      final dataSource = _FakeImouCloudDataSource();
      dataSource.bindDeviceLiveHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
            required streamId,
          }) async => 'bind_token';
      dataSource.getLiveStreamInfoHandler =
          ({
            required accessToken,
            required deviceSn,
            required channelId,
          }) async => _streamInfo();
      final repository = ImouStreamRepositoryImpl(dataSource);

      await repository.getStreamUrl(deviceId);
      expect(repository.activeSessionLiveToken(deviceId), 'bind_token');

      await repository.releaseStreamSession(deviceId);
      expect(dataSource.unboundLiveTokens, ['bind_token']);
    });
  });
}

ImouLiveStreamInfo _streamInfo({
  String? hls = 'https://sd.example.com/live/camera.m3u8',
  String? flv,
  String? liveToken,
}) {
  return ImouLiveStreamInfo(
    streams: [
      ImouLiveStream(
        streamId: 1,
        status: 'ready',
        hls: hls,
        flv: flv,
        liveToken: liveToken,
      ),
    ],
    status: 'ready',
  );
}

typedef _BindDeviceLiveHandler =
    Future<String?> Function({
      required String accessToken,
      required String deviceSn,
      required String channelId,
      required int streamId,
    });

typedef _GetLiveStreamInfoHandler =
    Future<ImouLiveStreamInfo> Function({
      required String accessToken,
      required String deviceSn,
      required String channelId,
    });

class _FakeImouCloudDataSource implements ImouCloudDataSource {
  _BindDeviceLiveHandler? bindDeviceLiveHandler;
  _GetLiveStreamInfoHandler? getLiveStreamInfoHandler;
  final List<String> unboundLiveTokens = [];
  var getLiveStreamInfoCalls = 0;

  @override
  Future<ImouAccessToken> getAccessToken() async {
    return ImouAccessToken(
      token: 'access_token',
      expireAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<String?> bindDeviceLive({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
    int streamId = 1,
  }) {
    final handler = bindDeviceLiveHandler;
    if (handler != null) {
      return handler(
        accessToken: accessToken,
        deviceSn: deviceSn,
        channelId: channelId,
        streamId: streamId,
      );
    }
    return Future.value('bind_token');
  }

  @override
  Future<ImouLiveStreamInfo> getLiveStreamInfo({
    required String accessToken,
    required String deviceSn,
    String channelId = '0',
  }) {
    getLiveStreamInfoCalls++;
    final handler = getLiveStreamInfoHandler;
    if (handler != null) {
      return handler(
        accessToken: accessToken,
        deviceSn: deviceSn,
        channelId: channelId,
      );
    }
    return Future.value(_streamInfo(liveToken: 'sd_token'));
  }

  @override
  Future<void> unbindLive({
    required String accessToken,
    required String liveToken,
  }) async {
    unboundLiveTokens.add(liveToken);
  }

  @override
  Future<List<ImouDevice>> getDeviceList({required String accessToken}) async {
    return const [];
  }

  @override
  Future<bool> isDeviceOnline({
    required String accessToken,
    required String deviceSn,
  }) async {
    return true;
  }

  @override
  void clearAccessToken() {}
}
