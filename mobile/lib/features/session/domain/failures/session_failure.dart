import 'package:equatable/equatable.dart';

class SessionFailure extends Equatable {
  const SessionFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
