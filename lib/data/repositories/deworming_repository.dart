import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/deworming_model.dart';
import '../services/history_service.dart';

class DewormingRepository {
  static final DewormingRepository _instance = DewormingRepository._internal();
  factory DewormingRepository() => _instance;

  DewormingRepository._internal();

  final HistoryService _remote = HistoryService();
  final AppDatabase _local = database;
  final Uuid _uuid = const Uuid();

  Future<List<DewormingModel>> fetchDewormings(String petId) async {
    final localRows = await _local.getDewormingsForPet(petId);

    try {
      final remoteData = await _remote.fetchDewormings(petId);
      await _local.replaceDewormingsForPet(
        petId,
        remoteData
            .map((d) => _toLocalCompanion(d, syncState: 'synced'))
            .toList(),
      );
      final merged = await _local.getDewormingsForPet(petId);
      return merged.map(_fromLocal).toList();
    } catch (_) {
      return localRows.map(_fromLocal).toList();
    }
  }

  Future<DewormingModel> addDeworming(DewormingModel deworming) async {
    final withId = deworming.id.isEmpty
        ? _copyWithGeneratedId(deworming)
        : deworming;

    await _local.upsertDeworming(
      _toLocalCompanion(withId, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'deworming',
      entityId: withId.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(withId)),
    );

    await syncPendingQueue();
    final local = await _local.getDewormingById(withId.id);
    return local != null ? _fromLocal(local) : withId;
  }

  Future<DewormingModel> updateDeworming(DewormingModel deworming) async {
    await _local.upsertDeworming(
      _toLocalCompanion(deworming, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'deworming',
      entityId: deworming.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(deworming)),
    );

    await syncPendingQueue();
    final local = await _local.getDewormingById(deworming.id);
    return local != null ? _fromLocal(local) : deworming;
  }

  Future<void> deleteDeworming(String dewormingId) async {
    await _local.deleteDeworming(dewormingId);
    await _local.enqueueSyncAction(
      entityType: 'deworming',
      entityId: dewormingId,
      operation: 'delete',
    );
    await syncPendingQueue();
  }

  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'deworming') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deleteDeworming(action.entityId);
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
            ? await _remote.updateDeworming(model)
            : await _remote.addDeworming(model);

        await _local.upsertDeworming(
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

  Future<bool> _existsInRemote(String petId, String dewormingId) async {
    final remote = await _remote.fetchDewormings(petId);
    return remote.any((d) => d.id == dewormingId);
  }

  DewormingModel _copyWithGeneratedId(DewormingModel deworming) {
    return DewormingModel(
      id: _uuid.v4(),
      petId: deworming.petId,
      product: deworming.product,
      dose: deworming.dose,
      route: deworming.route,
      applicationDate: deworming.applicationDate,
      nextDueDate: deworming.nextDueDate,
      createdAt: deworming.createdAt,
    );
  }

  Map<String, dynamic> _toSyncPayload(DewormingModel deworming) {
    return {
      'id': deworming.id,
      'pet_id': deworming.petId,
      'product': deworming.product,
      'dose': deworming.dose,
      'route': deworming.route,
      'application_date': deworming.applicationDate.toIso8601String(),
      'next_due_date': deworming.nextDueDate?.toIso8601String(),
      'created_at': deworming.createdAt.toIso8601String(),
    };
  }

  DewormingModel _fromSyncPayload(Map<String, dynamic> map) {
    return DewormingModel(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      product: map['product'] as String,
      dose: map['dose'] as String?,
      route: map['route'] as String?,
      applicationDate: DateTime.parse(map['application_date'] as String),
      nextDueDate: map['next_due_date'] != null
          ? DateTime.parse(map['next_due_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LocalDewormingsCompanion _toLocalCompanion(
    DewormingModel d, {
    required String syncState,
  }) {
    return LocalDewormingsCompanion(
      id: Value(d.id),
      petId: Value(d.petId),
      product: Value(d.product),
      dose: Value(d.dose),
      route: Value(d.route),
      applicationDate: Value(d.applicationDate),
      nextDueDate: Value(d.nextDueDate),
      createdAt: Value(d.createdAt),
      syncState: Value(syncState),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  DewormingModel _fromLocal(LocalDeworming row) {
    return DewormingModel(
      id: row.id,
      petId: row.petId,
      product: row.product,
      dose: row.dose,
      route: row.route,
      applicationDate: row.applicationDate,
      nextDueDate: row.nextDueDate,
      createdAt: row.createdAt,
    );
  }
}
