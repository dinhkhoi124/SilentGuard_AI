import 'package:equatable/equatable.dart';

class DeviceCredentials extends Equatable {
  const DeviceCredentials({required this.username, required this.password});

  final String username;
  final String password;

  bool get isEmpty => username.trim().isEmpty && password.isEmpty;

  @override
  List<Object?> get props => [username, password];
}
