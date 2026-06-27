// lib/features/automation/data/repositories/emergency_contacts_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:mobile/features/automation/data/datasources/emergency_contacts_local_data_source.dart';
import 'package:mobile/features/automation/data/models/emergency_contact_model.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';
import 'package:mobile/features/automation/domain/repositories/emergency_contacts_repository.dart';

class EmergencyContactsRepositoryImpl implements EmergencyContactsRepository {
  const EmergencyContactsRepositoryImpl(this._localDataSource);

  final EmergencyContactsLocalDataSource _localDataSource;

  @override
  Future<Either<String, List<EmergencyContact>>> getContacts() async {
    try {
      final models = await _localDataSource.getContacts();
      models.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      return Right(models);
    } catch (e) {
      return const Left('Không thể tải danh sách liên hệ. Vui lòng thử lại.');
    }
  }

  @override
  Future<Either<String, void>> addContact(EmergencyContact contact) async {
    try {
      final models = await _localDataSource.getContacts();
      models.add(EmergencyContactModel.fromEntity(contact));
      _reorder(models);
      await _localDataSource.saveContacts(models);
      return const Right(null);
    } catch (e) {
      return const Left('Không thể thêm liên hệ. Vui lòng thử lại.');
    }
  }

  @override
  Future<Either<String, void>> updateContact(EmergencyContact contact) async {
    try {
      final models = await _localDataSource.getContacts();
      final index = models.indexWhere((c) => c.id == contact.id);
      if (index == -1) {
        return const Left('Không tìm thấy liên hệ để cập nhật.');
      }
      models[index] = EmergencyContactModel.fromEntity(contact);
      _reorder(models);
      await _localDataSource.saveContacts(models);
      return const Right(null);
    } catch (e) {
      return const Left('Không thể cập nhật liên hệ. Vui lòng thử lại.');
    }
  }

  @override
  Future<Either<String, void>> deleteContact(String id) async {
    try {
      final models = await _localDataSource.getContacts();
      models.removeWhere((c) => c.id == id);
      _reorder(models);
      await _localDataSource.saveContacts(models);
      return const Right(null);
    } catch (e) {
      return const Left('Không thể xóa liên hệ. Vui lòng thử lại.');
    }
  }

  void _reorder(List<EmergencyContactModel> contacts) {
    contacts.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
    for (int i = 0; i < contacts.length; i++) {
      contacts[i] = EmergencyContactModel.fromEntity(
        contacts[i].copyWith(priorityOrder: i + 1),
      );
    }
  }
}
