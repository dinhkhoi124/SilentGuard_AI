import 'package:equatable/equatable.dart';
import 'package:mobile/features/session/domain/entities/backend_user.dart';
import 'package:mobile/features/session/domain/entities/household.dart';

class BackendSession extends Equatable {
  const BackendSession({required this.backendUser, required this.household});

  final BackendUser backendUser;
  final Household household;

  String get householdId => household.householdId;

  @override
  List<Object?> get props => [backendUser, household];
}
