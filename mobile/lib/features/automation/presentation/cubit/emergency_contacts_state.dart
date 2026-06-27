// lib/features/automation/presentation/cubit/emergency_contacts_state.dart

import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';

sealed class EmergencyContactsState {
  const EmergencyContactsState({this.contacts = const []});
  final List<EmergencyContact> contacts;
}

final class EmergencyContactsInitial extends EmergencyContactsState {
  const EmergencyContactsInitial() : super();
}

final class EmergencyContactsLoading extends EmergencyContactsState {
  const EmergencyContactsLoading({super.contacts});
}

final class EmergencyContactsLoaded extends EmergencyContactsState {
  const EmergencyContactsLoaded({required super.contacts});
}

final class EmergencyContactsSaving extends EmergencyContactsState {
  const EmergencyContactsSaving({required super.contacts});
}

final class EmergencyContactsDeleting extends EmergencyContactsState {
  const EmergencyContactsDeleting({required super.contacts});
}

final class EmergencyContactsError extends EmergencyContactsState {
  const EmergencyContactsError({
    required this.message,
    required super.contacts,
  });
  final String message;
}
