import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/vaccine_model.dart';
import '../services/history_service.dart';

class VaccineRepository {
  static final VaccineRepository _instance = VaccineRepository._internal();
  factory VaccineRepository() => _instance;

  VaccineRepository._internal();

  final HistoryService _remote = HistoryService();
  final AppDatabase _local = database;
  final Uuid _uuid = const Uuid();

  Future<List<VaccineModel>> fetchVaccines(String petId) async {
    final localRows = await _local.getVaccinesForPet(petId);

    try {
      final remoteData = await _remote.fetchVaccines(petId);
      await _local.replaceVaccinesForPet(
        petId,
        remoteData
            .map((v) => _toLocalCompanion(v, syncState: 'synced'))
            .toList(),
      );
      final merged = await _local.getVaccinesForPet(petId);
      return merged.map(_fromLocal).toList();
    } catch (_) {
      return localRows.map(_fromLocal).toList();
    }
  }

  Future<VaccineModel> addVaccine(VaccineModel vaccine) async {
    final withId = vaccine.id.isEmpty ? _copyWithGeneratedId(vaccine) : vaccine;

    await _local.upsertVaccine(
      _toLocalCompanion(withId, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'vaccine',
      entityId: withId.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(withId)),
    );

    await syncPendingQueue();
    final local = await _local.getVaccineById(withId.id);
    return local != null ? _fromLocal(local) : withId;
  }

  Future<VaccineModel> updateVaccine(VaccineModel vaccine) async {
    await _local.upsertVaccine(
      _toLocalCompanion(vaccine, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'vaccine',
      entityId: vaccine.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(vaccine)),
    );

    await syncPendingQueue();
    final local = await _local.getVaccineById(vaccine.id);
    return local != null ? _fromLocal(local) : vaccine;
  }

  Future<void> deleteVaccine(String vaccineId) async {
    await _local.deleteVaccine(vaccineId);
    await _local.enqueueSyncAction(
      entityType: 'vaccine',
      entityId: vaccineId,
      operation: 'delete',
    );
    await syncPendingQueue();
  }

  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'vaccine') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deleteVaccine(action.entityId);
          await _local.removeSyncAction(action.id);
          continue;
        }

        if (action.payloadJson == null || action.payloadJson!.isEmpty) {
          await _local.removeSyncAction(action.id);
          continue;
        }

        final map = jsonDecode(action.payloadJson!) as Map<String, dynamic>;
        final model = _fromSyncPayload(map);

        final existsRemotely = await _existsInRemote(model.petId, model.id);
        final synced = existsRemotely
            ? await _remote.updateVaccine(model)
            : await _remote.addVaccine(model);

        await _local.upsertVaccine(
          _toLocalCompanion(synced, syncState: 'synced'),
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

  Future<bool> _existsInRemote(String petId, String vaccineId) async {
    final remote = await _remote.fetchVaccines(petId);
    return remote.any((v) => v.id == vaccineId);
  }

  VaccineModel _copyWithGeneratedId(VaccineModel vaccine) {
    return VaccineModel(
      id: _uuid.v4(),
      petId: vaccine.petId,
      vaccineName: vaccine.vaccineName,
      applicationDate: vaccine.applicationDate,
      nextDueDate: vaccine.nextDueDate,
      createdAt: vaccine.createdAt,
    );
  }

  Map<String, dynamic> _toSyncPayload(VaccineModel vaccine) {
    return {
      'id': vaccine.id,
      'pet_id': vaccine.petId,
      'vaccine_name': vaccine.vaccineName,
      'application_date': vaccine.applicationDate.toIso8601String(),
      'next_due_date': vaccine.nextDueDate?.toIso8601String(),
      'created_at': vaccine.createdAt.toIso8601String(),
    };
  }

  VaccineModel _fromSyncPayload(Map<String, dynamic> map) {
    return VaccineModel(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      vaccineName: map['vaccine_name'] as String,
      applicationDate: DateTime.parse(map['application_date'] as String),
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LocalVaccinesCompanion _toLocalCompanion(
    VaccineModel v, {
    required String syncState,
  }) {
    return LocalVaccinesCompanion(
      id: Value(v.id),
      petId: Value(v.petId),
      vaccineName: Value(v.vaccineName),
      applicationDate: Value(v.applicationDate),
      nextDueDate: Value(v.nextDueDate),
      createdAt: Value(v.createdAt),
      syncState: Value(syncState),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  VaccineModel _fromLocal(LocalVaccine row) {
    return VaccineModel(
      id: row.id,
      petId: row.petId,
      vaccineName: row.vaccineName,
      applicationDate: row.applicationDate,
      nextDueDate: row.nextDueDate,
      createdAt: row.createdAt,
    );
  }
}
