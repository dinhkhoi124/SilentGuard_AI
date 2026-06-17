import 'package:equatable/equatable.dart';

sealed class ImouStreamFailure extends Equatable {
  const ImouStreamFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class ImouConfigurationFailure extends ImouStreamFailure {
  const ImouConfigurationFailure(super.message);
}

final class ImouAuthFailure extends ImouStreamFailure {
  const ImouAuthFailure([super.message = 'Không thể xác thực với Imou Cloud.']);
}

final class DeviceNotBoundFailure extends ImouStreamFailure {
  const DeviceNotBoundFailure()
    : super('Camera chưa được liên kết với tài khoản Imou Life.');
}

final class DeviceNotOwnedFailure extends ImouStreamFailure {
  const DeviceNotOwnedFailure()
    : super('Camera không thuộc tài khoản Imou Cloud đã cấu hình.');
}

final class DeviceOfflineFailure extends ImouStreamFailure {
  const DeviceOfflineFailure()
    : super('Camera chưa được kết nối qua Imou Life hoặc đang offline.');
}

final class ImouStreamUnavailableFailure extends ImouStreamFailure {
  const ImouStreamUnavailableFailure([
    super.message = 'Không lấy được luồng phát từ Imou Cloud.',
  ]);
}

final class ImouUnknownFailure extends ImouStreamFailure {
  const ImouUnknownFailure([
    super.message = 'Imou Cloud trả về lỗi không xác định.',
  ]);
}
