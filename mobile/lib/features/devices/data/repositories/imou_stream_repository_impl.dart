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
      final message = _messageForImouCloudException(error);
      final rawMessage = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';
      if (rawMessage.contains('app') || rawMessage.contains('secret')) {
        return const Left(
          ImouConfigurationFailure(
            'Cấu hình Imou Cloud chưa hợp lệ. Vui lòng kiểm tra lại ứng dụng.',
          ),
        );
      }
      if (rawMessage.contains('token') ||
          rawMessage.contains('auth') ||
          code.contains('token') ||
          code.contains('auth')) {
        return Left(ImouAuthFailure(message));
      }
      return Left(ImouStreamUnavailableFailure(message));
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

  void _logFailure(Object error, StackTrace _) {
    final code = error is ImouCloudException ? error.code : null;
    developer.log(
      'Imou stream request failed'
      '${code == null ? '' : ' (code: $code)'}.',
      name: 'ImouStreamRepository',
    );
  }

  String _messageForImouCloudException(ImouCloudException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    if (code == ImouCloudDataSourceImpl.unsupportedStreamFormatCode) {
      return 'Camera đang trực tuyến nhưng luồng trực tiếp hiện chưa hỗ trợ trên Android. Vui lòng thử lại sau hoặc kiểm tra cấu hình camera.';
    }
    if (code == 'device_no_response') {
      return 'Camera đang trực tuyến nhưng chưa phản hồi luồng trực tiếp. Vui lòng kiểm tra mạng của camera hoặc thử lại sau.';
    }
    if (code == 'lv1001' || message.contains('live')) {
      return 'Luồng camera đang bận. Vui lòng thử lại sau vài giây.';
    }
    if (message.contains('right') ||
        message.contains('operate') ||
        message.contains('permission') ||
        message.contains('auth')) {
      return 'Không có quyền truy cập camera. Vui lòng kiểm tra cấu hình Imou.';
    }
    if (message.contains('token')) {
      return 'Phiên Imou đã hết hạn. Đang thử kết nối lại...';
    }
    return 'Không thể lấy luồng camera từ Imou Cloud. Vui lòng thử lại.';
  }
}
