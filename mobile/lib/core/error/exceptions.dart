// lib/core/error/exceptions.dart

class NoInternetException implements Exception {
  const NoInternetException([this.message = 'Không có kết nối mạng']);

  final String message;

  @override
  String toString() => message;
}
