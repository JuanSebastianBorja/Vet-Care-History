import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/consultation_model.dart';
import '../services/history_service.dart';

class ConsultationRepository {
  static final ConsultationRepository _instance =
      ConsultationRepository._internal();
  factory ConsultationRepository() => _instance;

  ConsultationRepository._internal();

  final HistoryService _remote = HistoryService();
  final AppDatabase _local = AppDatabase();
  final Uuid _uuid = const Uuid();

  Future<List<ConsultationModel>> fetchConsultations(String petId) async {
    final localRows = await _local.getConsultationsForPet(petId);

    try {
      final remoteData = await _remote.fetchConsultations(petId);
      await _local.replaceConsultationsForPet(
        petId,
        remoteData
            .map((c) => _toLocalCompanion(c, syncState: 'synced'))
            .toList(),
      );
      final merged = await _local.getConsultationsForPet(petId);
      return merged.map(_fromLocal).toList();
    } catch (_) {
      return localRows.map(_fromLocal).toList();
    }
  }

  Future<ConsultationModel> addConsultation(
    ConsultationModel consultation,
    List<XFile> photos,
  ) async {
    final withId = consultation.id.isEmpty
        ? _copyWithGeneratedId(consultation)
        : consultation;

    if (photos.isNotEmpty) {
      try {
        final saved = await _remote.addConsultation(withId, photos);
        await _local.upsertConsultation(
          _toLocalCompanion(saved, syncState: 'synced'),
        );
        return saved;
      } catch (_) {
        await _enqueueConsultationUpsert(withId);
        await _storePendingPhotos(withId.id, photos);
        final local = await _local.getConsultationById(withId.id);
        return local != null ? _fromLocal(local) : withId;
      }
    }

    await _local.upsertConsultation(
      _toLocalCompanion(withId, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'consultation',
      entityId: withId.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(withId)),
    );

    await syncPendingQueue();
    final local = await _local.getConsultationById(withId.id);
    return local != null ? _fromLocal(local) : withId;
  }

  Future<ConsultationModel> updateConsultation(
    ConsultationModel consultation,
    List<XFile> newPhotos,
    List<String> photoIdsToDelete,
  ) async {
    if (newPhotos.isNotEmpty || photoIdsToDelete.isNotEmpty) {
      try {
        final updated = await _remote.updateConsultation(
          consultation,
          newPhotos,
          photoIdsToDelete,
        );
        await _local.upsertConsultation(
          _toLocalCompanion(updated, syncState: 'synced'),
        );
        return updated;
      } catch (_) {
        if (photoIdsToDelete.isNotEmpty) rethrow;

        await _enqueueConsultationUpsert(consultation);
        await _storePendingPhotos(consultation.id, newPhotos);
        final local = await _local.getConsultationById(consultation.id);
        return local != null ? _fromLocal(local) : consultation;
      }
    }

    await _enqueueConsultationUpsert(consultation);

    await syncPendingQueue();
    final local = await _local.getConsultationById(consultation.id);
    return local != null ? _fromLocal(local) : consultation;
  }

  Future<void> deleteConsultation(String consultationId) async {
    await _local.deleteConsultation(consultationId);
    await _local.deletePendingPhotosForConsultation(consultationId);
    await _local.enqueueSyncAction(
      entityType: 'consultation',
      entityId: consultationId,
      operation: 'delete',
    );
    await syncPendingQueue();
  }

  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'consultation') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deleteConsultation(action.entityId);
          await _local.deletePendingPhotosForConsultation(action.entityId);
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
            ? await _remote.updateConsultation(model, const [], const [])
            : await _remote.addConsultation(model, const []);

        await _syncPendingPhotosForConsultation(synced.id);
        await _local.upsertConsultation(
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

  Future<Set<String>> getConsultationIdsWithPendingPhotosForPet(String petId) {
    return _local.getConsultationIdsWithPendingPhotosForPet(petId);
  }

  Future<bool> _existsInRemote(String petId, String consultationId) async {
    final remote = await _remote.fetchConsultations(petId);
    return remote.any((c) => c.id == consultationId);
  }

  ConsultationModel _copyWithGeneratedId(ConsultationModel c) {
    return ConsultationModel(
      id: _uuid.v4(),
      petId: c.petId,
      visitDate: c.visitDate,
      motive: c.motive,
      diagnosis: c.diagnosis,
      treatment: c.treatment,
      notes: c.notes,
      photos: c.photos,
      createdAt: c.createdAt,
    );
  }

  Future<void> _enqueueConsultationUpsert(
    ConsultationModel consultation,
  ) async {
    await _local.upsertConsultation(
      _toLocalCompanion(consultation, syncState: 'pending_upsert'),
    );
    await _local.enqueueSyncAction(
      entityType: 'consultation',
      entityId: consultation.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(consultation)),
    );
  }

  Future<void> _storePendingPhotos(
    String consultationId,
    List<XFile> photos,
  ) async {
    for (final photo in photos) {
      if (photo.path.isEmpty) continue;
      await _local.addPendingConsultationPhoto(
        PendingConsultationPhotosCompanion.insert(
          consultationId: consultationId,
          localPath: photo.path,
          mimeType: Value(photo.mimeType),
          description: const Value(null),
        ),
      );
    }
  }

  Future<void> _syncPendingPhotosForConsultation(String consultationId) async {
    final pending = await _local.getPendingPhotosForConsultation(
      consultationId,
    );

    for (final item in pending) {
      try {
        final file = File(item.localPath);
        if (!await file.exists()) {
          await _local.deletePendingPhoto(item.id);
          continue;
        }

        final xfile = XFile(item.localPath, mimeType: item.mimeType);
        final url = await _remote.uploadConsultationPhoto(
          consultationId,
          xfile,
        );
        await _remote.createConsultationPhotoRecord(
          consultationId: consultationId,
          photoUrl: url,
          description: item.description,
        );
        if (await file.exists()) {
          await file.delete();
        }
        await _local.deletePendingPhoto(item.id);
      } catch (_) {
        // Se reintentara en la proxima corrida de sincronizacion.
      }
    }
  }

  Map<String, dynamic> _toSyncPayload(ConsultationModel c) {
    return {
      'id': c.id,
      'pet_id': c.petId,
      'visit_date': c.visitDate.toIso8601String(),
      'motive': c.motive,
      'diagnosis': c.diagnosis,
      'treatment': c.treatment,
      'notes': c.notes,
      'created_at': c.createdAt.toIso8601String(),
    };
  }

  ConsultationModel _fromSyncPayload(Map<String, dynamic> map) {
    return ConsultationModel(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      visitDate: DateTime.parse(map['visit_date'] as String),
      motive: map['motive'] as String,
      diagnosis: map['diagnosis'] as String?,
      treatment: map['treatment'] as String?,
      notes: map['notes'] as String?,
      photos: const [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LocalConsultationsCompanion _toLocalCompanion(
    ConsultationModel c, {
    required String syncState,
  }) {
    return LocalConsultationsCompanion(
      id: Value(c.id),
      petId: Value(c.petId),
      visitDate: Value(c.visitDate),
      motive: Value(c.motive),
      diagnosis: Value(c.diagnosis),
      treatment: Value(c.treatment),
      notes: Value(c.notes),
      createdAt: Value(c.createdAt),
      syncState: Value(syncState),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  ConsultationModel _fromLocal(LocalConsultation row) {
    return ConsultationModel(
      id: row.id,
      petId: row.petId,
      visitDate: row.visitDate,
      motive: row.motive,
      diagnosis: row.diagnosis,
      treatment: row.treatment,
      notes: row.notes,
      photos: const [],
      createdAt: row.createdAt,
    );
  }
}
