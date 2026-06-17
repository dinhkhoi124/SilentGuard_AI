import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/devices/data/datasources/imou_cloud_datasource.dart';
import 'package:mobile/features/devices/domain/entities/imou_device_status.dart';
import 'package:mobile/features/devices/domain/failures/imou_stream_failure.dart';
import 'package:mobile/features/devices/domain/repositories/imou_stream_repository.dart';

class ImouStreamRepositoryImpl implements ImouStreamRepository {
  const ImouStreamRepositoryImpl(this._dataSource);

  final ImouCloudDataSource _dataSource;

  @override
  Future<Either<ImouStreamFailure, ImouDeviceStatus>> checkDeviceStatus(
    String serialNumber,
  ) async {
    return _guard(() async {
      return _dataSource.checkDeviceStatus(serialNumber);
    });
  }

  @override
  Future<Either<ImouStreamFailure, String>> getStreamUrl(
    String serialNumber, {
    int channel = 0,
  }) {
    return _guard(
      () => _dataSource.getStreamUrl(serialNumber, channel: channel),
    );
  }

  Future<Either<ImouStreamFailure, T>> _guard<T>(
    Future<T> Function() task,
  ) async {
    try {
      return Right(await task());
    } on ImouStreamFailure catch (failure) {
      return Left(failure);
    } on ImouCloudException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      final message = error.message.toLowerCase();
      if (message.contains('app') || message.contains('secret')) {
        return Left(ImouConfigurationFailure(error.message));
      }
      if (message.contains('token') || message.contains('auth')) {
        return Left(ImouAuthFailure(error.message));
      }
      return Left(ImouStreamUnavailableFailure(error.message));
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        ImouStreamUnavailableFailure('Kết nối Imou Cloud quá thời gian chờ.'),
      );
    } on SocketException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        ImouStreamUnavailableFailure('Không thể kết nối Imou Cloud.'),
      );
    } on http.ClientException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(
        ImouStreamUnavailableFailure('Không thể kết nối Imou Cloud.'),
      );
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      return const Left(ImouUnknownFailure());
    }
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    developer.log(
      'Imou stream request failed.',
      name: 'ImouStreamRepository',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
