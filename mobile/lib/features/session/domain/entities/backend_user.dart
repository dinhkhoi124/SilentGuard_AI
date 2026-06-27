import 'package:equatable/equatable.dart';

class BackendUser extends Equatable {
  const BackendUser({
    required this.id,
    required this.firebaseUid,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String firebaseUid;
  final String fullName;
  final String email;
  final String role;

  @override
  List<Object?> get props => [id, firebaseUid, fullName, email, role];
}
