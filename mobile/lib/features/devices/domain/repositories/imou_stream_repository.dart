import 'package:dartz/dartz.dart';
import 'package:mobile/features/devices/domain/entities/imou_device_status.dart';
import 'package:mobile/features/devices/domain/failures/imou_stream_failure.dart';

abstract interface class ImouStreamRepository {
  Future<Either<ImouStreamFailure, ImouDeviceStatus>> checkDeviceStatus(
    String serialNumber,
  );

  Future<Either<ImouStreamFailure, String>> getStreamUrl(
    String serialNumber, {
    int channel = 0,
  });
}
