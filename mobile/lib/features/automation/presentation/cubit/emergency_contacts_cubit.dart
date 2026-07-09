// lib/features/automation/presentation/cubit/emergency_contacts_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';
import 'package:mobile/features/automation/domain/repositories/emergency_contacts_repository.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_state.dart';
import 'package:uuid/uuid.dart';

class EmergencyContactsCubit extends Cubit<EmergencyContactsState> {
  EmergencyContactsCubit(this._repository)
    : super(const EmergencyContactsInitial());

  final EmergencyContactsRepository _repository;

  Future<void> loadContacts() async {
    emit(EmergencyContactsLoading(contacts: state.contacts));
    final result = await _repository.getContacts();
    result.fold(
      (failure) => emit(
        EmergencyContactsError(message: failure, contacts: state.contacts),
      ),
      (contacts) => emit(EmergencyContactsLoaded(contacts: contacts)),
    );
  }

  Future<bool> addContact({
    required String name,
    required String phoneNumber,
  }) async {
    emit(EmergencyContactsSaving(contacts: state.contacts));
    final contact = EmergencyContact(
      id: const Uuid().v4(),
      name: name,
      phoneNumber: phoneNumber,
      priorityOrder: state.contacts.length + 1,
      createdAt: DateTime.now(),
    );

    final result = await _repository.addContact(contact);
    return result.fold(
      (failure) {
        emit(
          EmergencyContactsError(message: failure, contacts: state.contacts),
        );
        return false;
      },
      (_) {
        loadContacts();
        return true;
      },
    );
  }

  Future<bool> updateContact(EmergencyContact contact) async {
    emit(EmergencyContactsSaving(contacts: state.contacts));
    final updatedContact = contact.copyWith(updatedAt: DateTime.now());
    final result = await _repository.updateContact(updatedContact);
    return result.fold(
      (failure) {
        emit(
          EmergencyContactsError(message: failure, contacts: state.contacts),
        );
        return false;
      },
      (_) {
        loadContacts();
        return true;
      },
    );
  }

  Future<bool> deleteContact(String id) async {
    emit(EmergencyContactsDeleting(contacts: state.contacts));
    final result = await _repository.deleteContact(id);
    return result.fold(
      (failure) {
        emit(
          EmergencyContactsError(message: failure, contacts: state.contacts),
        );
        return false;
      },
      (_) {
        loadContacts();
        return true;
      },
    );
  }
}
