import 'dart:async';
import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:mobile/core/error/exceptions.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/devices/data/datasources/device_permission_data_source.dart';
import 'package:mobile/features/devices/data/datasources/device_remote_data_source.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/domain/entities/resolved_device.dart';
import 'package:mobile/features/devices/domain/repositories/device_repository.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  const DeviceRepositoryImpl({
    required DeviceRemoteDataSource remoteDataSource,
    required DevicePermissionDataSource permissionDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _permissionDataSource = permissionDataSource;

  final DeviceRemoteDataSource _remoteDataSource;
  final DevicePermissionDataSource _permissionDataSource;

  @override
  Future<Either<String, bool>> requestCameraPermission() {
    return _guard(_permissionDataSource.requestCamera);
  }

  @override
  Future<Either<String, PairedDevice>> savePairedDevice({
    required ResolvedDevice resolvedDevice,
  }) {
    return _guard(
      () => _remoteDataSource.savePairedDevice(resolvedDevice: resolvedDevice),
    );
  }

  @override
  Future<Either<String, List<PairedDevice>>> getPairedDevices() {
    return _guard(_remoteDataSource.getPairedDevices);
  }

  @override
  Future<Either<String, void>> deletePairedDevice(String deviceId) {
    return _guard(() => _remoteDataSource.deletePairedDevice(deviceId));
  }

  Future<Either<String, T>> _guard<T>(Future<T> Function() task) async {
    try {
      return Right(await task());
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(_messageForApiException(error));
    } on NoInternetException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return Left(error.message);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left('Lỗi không xác định. Vui lòng thử lại.');
    }
  }

  String _messageForApiException(ApiException error) {
    return switch (error.kind) {
      ApiExceptionKind.configuration => error.message,
      ApiExceptionKind.unauthorized =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.', // FIX: let HomeBloc route 401 to session-expired UI.
      ApiExceptionKind.forbidden =>
        'Tài khoản không có quyền truy cập dữ liệu này.',
      ApiExceptionKind.notFound => 'Không tìm thấy dữ liệu trên máy chủ.',
      ApiExceptionKind.badRequest => error.message,
      ApiExceptionKind.invalidResponse => 'Phản hồi máy chủ không hợp lệ.',
      ApiExceptionKind.server =>
        'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.', // FIX: let HomeBloc classify 5xx as backend warming up.
      ApiExceptionKind.unknown => 'Lỗi không xác định. Vui lòng thử lại.',
    };
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    developer.log(
      'Device repository request failed.',
      name: 'DeviceRepository',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
