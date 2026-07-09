import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/device.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';
import 'package:mobile/features/home/domain/usecases/delete_camera_device.dart';
import 'package:mobile/features/home/domain/usecases/get_camera_devices.dart';
import 'package:mobile/features/home/domain/usecases/get_weather.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/session/domain/entities/backend_session.dart';
import 'package:mobile/features/session/domain/entities/backend_user.dart';
import 'package:mobile/features/session/domain/entities/household.dart';
import 'package:mobile/features/session/domain/failures/session_failure.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

void main() {
  group('HomeBloc Imou stream lifecycle', () {
    test(
      'does not emit loaded when camera closes before stream URL returns',
      () async {
        final streamUrlCompleter = Completer<String>();
        final imouRepository = _FakeImouStreamRepository(
          streamUrlCompleter.future,
        );
        final bloc = HomeBloc(
          getWeather: GetWeather(_FakeHomeRepository()),
          getCameraDevices: GetCameraDevices(_FakeHomeRepository()),
          deleteCameraDevice: DeleteCameraDevice(_FakeHomeRepository()),
          sessionRepository: _FakeSessionRepository(),
          imouStreamRepository: imouRepository,
        );
        final states = <HomeState>[];
        final subscription = bloc.stream.listen(states.add);

        bloc.add(
          const CameraStreamUrlRequested(
            cameraId: 'camera-1',
            serialNumber: 'CAM123456',
          ),
        );
        await imouRepository.getRequested.future;

        bloc.add(const CameraDetailClosed(serialNumber: 'CAM123456'));
        await imouRepository.releaseRequested.future;

        streamUrlCompleter.complete('https://sd.example.com/live/camera.m3u8');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(states.whereType<CameraStreamUrlLoading>(), hasLength(1));
        expect(states.whereType<CameraStreamUrlLoaded>(), isEmpty);
        expect(states.whereType<CameraStreamUrlFailure>(), isEmpty);
        expect(imouRepository.releaseCalls, 1);

        await subscription.cancel();
        await bloc.close();
      },
    );
  });
}

class _FakeImouStreamRepository implements ImouStreamRepository {
  _FakeImouStreamRepository(this.streamUrlFuture);

  final Future<String> streamUrlFuture;
  final getRequested = Completer<void>();
  final releaseRequested = Completer<void>();
  var releaseCalls = 0;

  @override
  Future<String> getStreamUrl(String deviceSn) {
    if (!getRequested.isCompleted) getRequested.complete();
    return streamUrlFuture;
  }

  @override
  Future<void> releaseStreamSession(String deviceSn) async {
    releaseCalls++;
    if (!releaseRequested.isCompleted) releaseRequested.complete();
  }
}

class _FakeHomeRepository implements HomeRepository {
  @override
  Future<Either<String, List<Device>>> getDevices() async => const Right([]);

  @override
  Future<Either<String, List<CameraDevice>>> getCameraDevices() async {
    return const Right([]);
  }

  @override
  Future<Either<String, void>> deleteCameraDevice(String deviceId) async {
    return const Right(null);
  }

  @override
  Future<Either<String, WeatherInfo?>> getWeather() async {
    return const Right(null);
  }
}

class _FakeSessionRepository implements SessionRepository {
  @override
  BackendSession? get currentSession => const BackendSession(
    backendUser: BackendUser(
      id: 'user-1',
      firebaseUid: 'firebase-1',
      fullName: 'Test User',
      email: 'test@example.com',
      role: 'member',
    ),
    household: Household(
      householdId: 'household-1',
      role: 'member',
      elderlyName: 'Elder',
    ),
  );

  @override
  Household? get currentHousehold => currentSession?.household;

  @override
  String? get currentHouseholdId => currentSession?.householdId;

  @override
  Future<Either<SessionFailure, BackendSession>> provisionSession({
    String? inviteCode,
  }) async {
    return Right(currentSession!);
  }

  @override
  Future<Either<SessionFailure, void>> logout({String? idToken}) async {
    return const Right(null);
  }

  @override
  Future<Either<SessionFailure, void>> switchHousehold(
    String householdId,
  ) async {
    return const Right(null);
  }

  @override
  void clearCachedSession() {}
}
