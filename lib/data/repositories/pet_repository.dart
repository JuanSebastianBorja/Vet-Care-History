import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';

class PetRepository {
  static final PetRepository _instance = PetRepository._internal();
  factory PetRepository() => _instance;

  PetRepository._internal();

  final PetService _remote = PetService();
  final AppDatabase _local = AppDatabase();
  final Uuid _uuid = const Uuid();

  Stream<List<PetModel>> watchPets(String userId) {
    return _local
        .watchPetsForUser(userId)
        .map((rows) => rows.map(_mapLocalToDomain).toList());
  }

  Stream<int> watchPendingSyncCount() {
    return _local.watchPendingSyncCount();
  }

  Future<int> getPendingSyncCount() {
    return _local.getPendingSyncCount();
  }

  Future<List<PetModel>> fetchPets(String userId) async {
    final localRows = await _local.getPetsForUser(userId);

    try {
      final remotePets = await _remote.fetchPets(userId);
      for (final pet in remotePets) {
        await _local.upsertPet(
          _mapDomainToLocalCompanion(pet, syncState: 'synced'),
        );
      }
      final mergedRows = await _local.getPetsForUser(userId);
      return mergedRows.map(_mapLocalToDomain).toList();
    } catch (_) {
      return localRows.map(_mapLocalToDomain).toList();
    }
  }

  Future<PetModel> addPet(PetModel pet) async {
    final withId = pet.copyWith(id: pet.id.isEmpty ? _uuid.v4() : pet.id);

    await _local.upsertPet(
      _mapDomainToLocalCompanion(withId, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'pet',
      entityId: withId.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(withId)),
    );

    await syncPendingQueue();
    final local = await _local.getPetById(withId.id);
    return local != null ? _mapLocalToDomain(local) : withId;
  }

  Future<PetModel> updatePet(PetModel pet) async {
    await _local.upsertPet(
      _mapDomainToLocalCompanion(pet, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'pet',
      entityId: pet.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(pet)),
    );

    await syncPendingQueue();
    final local = await _local.getPetById(pet.id);
    return local != null ? _mapLocalToDomain(local) : pet;
  }

  Future<void> deletePet(String petId) async {
    await _local.markPetDeleted(petId);
    await _local.enqueueSyncAction(
      entityType: 'pet',
      entityId: petId,
      operation: 'delete',
    );

    await syncPendingQueue();
  }

  Future<String> uploadPetPhoto(String key, Uint8List bytes, String mimeType) {
    return _remote.uploadPetPhoto(key, bytes, mimeType);
  }

  Future<PetModel> toggleNotifications(String petId, bool enabled) async {
    final local = await _local.getPetById(petId);
    if (local == null) {
      return _remote.toggleNotifications(petId, enabled);
    }

    final updated = _mapLocalToDomain(
      local,
    ).copyWith(notificationsEnabled: enabled);
    await _local.upsertPet(
      _mapDomainToLocalCompanion(updated, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'pet',
      entityId: petId,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(updated)),
    );

    await syncPendingQueue();
    final result = await _local.getPetById(petId);
    return result != null ? _mapLocalToDomain(result) : updated;
  }

  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'pet') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deletePet(action.entityId);
          await _local.hardDeletePet(action.entityId);
          await _local.removeSyncAction(action.id);
          continue;
        }

        if (action.payloadJson == null || action.payloadJson!.isEmpty) {
          await _local.removeSyncAction(action.id);
          continue;
        }

        final map = jsonDecode(action.payloadJson!) as Map<String, dynamic>;
        final model = _fromSyncPayload(map);

        final existsRemotely = await _existsInRemote(model.userId, model.id);
        final synced = existsRemotely
            ? await _remote.updatePet(model)
            : await _remote.addPet(model);

        await _local.upsertPet(
          _mapDomainToLocalCompanion(synced, syncState: 'synced'),
        );
        await _local.removeSyncAction(action.id);
      } catch (e) {
        await _local.markSyncAttemptFailed(action.id, e.toString());
      }
    }
  }

  bool _shouldRetry(SyncQueueData action) {
    if (action.attempts <= 0) return true;
    if (action.attempts >= 8) return false;

    final delaySeconds = 10 * (1 << (action.attempts - 1).clamp(0, 4));
    final nextAttemptAt = action.createdAt.add(Duration(seconds: delaySeconds));
    return DateTime.now().isAfter(nextAttemptAt);
  }

  Future<bool> _existsInRemote(String userId, String petId) async {
    final remotePets = await _remote.fetchPets(userId);
    return remotePets.any((p) => p.id == petId);
  }

  LocalPetsCompanion _mapDomainToLocalCompanion(
    PetModel pet, {
    required String syncState,
  }) {
    return LocalPetsCompanion(
      id: Value(pet.id),
      userId: Value(pet.userId),
      name: Value(pet.name),
      species: Value(pet.species),
      breed: Value(pet.breed),
      birthDate: Value(pet.birthDate),
      sex: Value(pet.sex),
      photoUrl: Value(pet.photoUrl),
      notificationsEnabled: Value(pet.notificationsEnabled),
      createdAt: Value(pet.createdAt),
      syncState: Value(syncState),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  PetModel _mapLocalToDomain(LocalPet row) {
    return PetModel(
      id: row.id,
      userId: row.userId,
      name: row.name,
      species: row.species,
      breed: row.breed,
      birthDate: row.birthDate,
      sex: row.sex,
      photoUrl: row.photoUrl,
      notificationsEnabled: row.notificationsEnabled,
      createdAt: row.createdAt,
    );
  }

  Map<String, dynamic> _toSyncPayload(PetModel pet) {
    return {
      'id': pet.id,
      'user_id': pet.userId,
      'name': pet.name,
      'species': pet.species,
      'breed': pet.breed,
      'birth_date': pet.birthDate?.toIso8601String(),
      'sex': pet.sex,
      'photo_url': pet.photoUrl,
      'notifications_enabled': pet.notificationsEnabled,
      'created_at': pet.createdAt.toIso8601String(),
    };
  }

  PetModel _fromSyncPayload(Map<String, dynamic> map) {
    return PetModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: map['breed'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      sex: map['sex'] as String?,
      photoUrl: map['photo_url'] as String?,
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
