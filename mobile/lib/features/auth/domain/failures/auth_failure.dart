sealed class AuthFailure {
  const AuthFailure(this.message);

  final String message;
}

final class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
    : super(
        'Email này đã được sử dụng. Vui lòng đăng nhập hoặc dùng email khác.',
      );
}

final class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure() : super('Email không hợp lệ.');
}

final class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
    : super('Mật khẩu quá yếu. Vui lòng dùng ít nhất 6 ký tự.');
}

final class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure()
    : super('Không tìm thấy tài khoản với email này.');
}

final class WrongPasswordFailure extends AuthFailure {
  const WrongPasswordFailure()
    : super('Mật khẩu không đúng. Vui lòng kiểm tra lại.');
}

final class InvalidCredentialFailure extends AuthFailure {
  const InvalidCredentialFailure()
    : super('Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.');
}

final class UserDisabledFailure extends AuthFailure {
  const UserDisabledFailure() : super('Tài khoản này đã bị vô hiệu hóa.');
}

final class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure()
    : super('Bạn đã thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.');
}

final class NetworkFailure extends AuthFailure {
  const NetworkFailure()
    : super('Không thể kết nối mạng. Vui lòng kiểm tra kết nối Internet.');
}

final class AccountExistsWithDifferentCredentialFailure extends AuthFailure {
  const AccountExistsWithDifferentCredentialFailure()
    : super(
        'Email này đã được đăng ký bằng phương thức khác. Vui lòng đăng nhập bằng email và mật khẩu.',
      );
}

final class GoogleSignInCancelledFailure extends AuthFailure {
  const GoogleSignInCancelledFailure() : super('');
}

final class GoogleSignInUnavailableFailure extends AuthFailure {
  const GoogleSignInUnavailableFailure()
    : super('Google Sign-In chưa khả dụng trên thiết bị này.');
}

final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([String? message])
    : super(message ?? 'Đã xảy ra lỗi xác thực. Vui lòng thử lại.');
}
