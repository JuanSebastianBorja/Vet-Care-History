import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/appointment_model.dart';
import '../services/history_service.dart';

class AppointmentRepository {
  static final AppointmentRepository _instance = AppointmentRepository._internal();
  factory AppointmentRepository() => _instance;

  AppointmentRepository._internal();

  final HistoryService _remote = HistoryService();
  final AppDatabase _local = AppDatabase();
  final Uuid _uuid = const Uuid();

  Future<List<AppointmentModel>> fetchAppointments(String petId) async {
    final localRows = await _local.getAppointmentsForPet(petId);

    try {
      final remoteData = await _remote.fetchAppointments(petId);
      await _local.replaceAppointmentsForPet(
        petId,
        remoteData
            .map((a) => _toLocalCompanion(a, syncState: 'synced'))
            .toList(),
      );
      final merged = await _local.getAppointmentsForPet(petId);
      return merged.map(_fromLocal).toList();
    } catch (_) {
      return localRows.map(_fromLocal).toList();
    }
  }

  Future<AppointmentModel> addAppointment(AppointmentModel appointment) async {
    final withId = appointment.id.isEmpty ? _copyWithGeneratedId(appointment) : appointment;

    await _local.upsertAppointment(
      _toLocalCompanion(withId, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'appointment',
      entityId: withId.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(withId)),
    );

    await syncPendingQueue();
    final local = await _local.getAppointmentById(withId.id);
    return local != null ? _fromLocal(local) : withId;
  }

  Future<AppointmentModel> updateAppointment(AppointmentModel appointment) async {
    await _local.upsertAppointment(
      _toLocalCompanion(appointment, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'appointment',
      entityId: appointment.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(appointment)),
    );

    await syncPendingQueue();
    final local = await _local.getAppointmentById(appointment.id);
    return local != null ? _fromLocal(local) : appointment;
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _local.deleteAppointment(appointmentId);
    await _local.enqueueSyncAction(
      entityType: 'appointment',
      entityId: appointmentId,
      operation: 'delete',
    );
    await syncPendingQueue();
  }

  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'appointment') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deleteAppointment(action.entityId);
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
            ? await _remote.updateAppointment(model)
            : await _remote.addAppointment(model);

        await _local.upsertAppointment(
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

  Future<bool> _existsInRemote(String petId, String appointmentId) async {
    final remote = await _remote.fetchAppointments(petId);
    return remote.any((a) => a.id == appointmentId);
  }

  AppointmentModel _copyWithGeneratedId(AppointmentModel a) {
    return AppointmentModel(
      id: _uuid.v4(),
      petId: a.petId,
      appointmentDatetime: a.appointmentDatetime,
      veterinarianName: a.veterinarianName,
      motive: a.motive,
      notes: a.notes,
      status: a.status,
      createdAt: a.createdAt,
    );
  }

  Map<String, dynamic> _toSyncPayload(AppointmentModel a) {
    return {
      'id': a.id,
      'pet_id': a.petId,
      'appointment_datetime': a.appointmentDatetime.toIso8601String(),
      'veterinarian_name': a.veterinarianName,
      'motive': a.motive,
      'notes': a.notes,
      'status': a.status,
      'created_at': a.createdAt.toIso8601String(),
    };
  }

  AppointmentModel _fromSyncPayload(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      appointmentDatetime: DateTime.parse(map['appointment_datetime'] as String),
      veterinarianName: map['veterinarian_name'] as String?,
      motive: map['motive'] as String,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LocalAppointmentsCompanion _toLocalCompanion(
    AppointmentModel a, {
    required String syncState,
  }) {
    return LocalAppointmentsCompanion(
      id: Value(a.id),
      petId: Value(a.petId),
      appointmentDatetime: Value(a.appointmentDatetime),
      veterinarianName: Value(a.veterinarianName),
      motive: Value(a.motive),
      notes: Value(a.notes),
      status: Value(a.status),
      createdAt: Value(a.createdAt),
      syncState: Value(syncState),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  AppointmentModel _fromLocal(LocalAppointment row) {
    return AppointmentModel(
      id: row.id,
      petId: row.petId,
      appointmentDatetime: row.appointmentDatetime,
      veterinarianName: row.veterinarianName,
      motive: row.motive,
      notes: row.notes,
      status: row.status,
      createdAt: row.createdAt,
    );
  }
}
