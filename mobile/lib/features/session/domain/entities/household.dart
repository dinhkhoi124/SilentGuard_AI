import 'package:equatable/equatable.dart';

class Household extends Equatable {
  const Household({
    required this.householdId,
    required this.role,
    required this.elderlyName,
  });

  final String householdId;
  final String role;
  final String elderlyName;

  @override
  List<Object?> get props => [householdId, role, elderlyName];
}
