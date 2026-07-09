// lib/features/automation/domain/repositories/emergency_contacts_repository.dart

import 'package:dartz/dartz.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';

abstract interface class EmergencyContactsRepository {
  Future<Either<String, List<EmergencyContact>>> getContacts();
  Future<Either<String, void>> addContact(EmergencyContact contact);
  Future<Either<String, void>> updateContact(EmergencyContact contact);
  Future<Either<String, void>> deleteContact(String id);
}
