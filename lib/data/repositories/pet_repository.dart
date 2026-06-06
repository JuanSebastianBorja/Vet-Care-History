import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';

/// Repositorio de Mascotas que implementa la estrategia offline-first.
///
/// Gestiona la lectura y escritura prioritaria en la base de datos local SQLite y
/// encola las operaciones pendientes en [SyncQueue] para su posterior envío
/// y sincronización con el servidor remoto (Supabase).
class PetRepository {
  static final PetRepository _instance = PetRepository._internal();
  factory PetRepository() => _instance;

  PetRepository._internal();

  final PetService _remote = PetService();
  final AppDatabase _local = AppDatabase();
  final Uuid _uuid = const Uuid();

  /// Escucha reactivamente los cambios en las mascotas locales asociadas a un [userId].
  Stream<List<PetModel>> watchPets(String userId) {
    return _local
        .watchPetsForUser(userId)
        .map((rows) => rows.map(_mapLocalToDomain).toList());
  }

  /// Escucha en tiempo real la cantidad de acciones de sincronización pendientes en la cola local.
  Stream<int> watchPendingSyncCount() {
    return _local.watchPendingSyncCount();
  }

  /// Obtiene la cantidad actual de acciones pendientes por sincronizar en local.
  Future<int> getPendingSyncCount() {
    return _local.getPendingSyncCount();
  }

  /// Trae la lista de mascotas para el usuario.
  ///
  /// Primero intenta consultar remotamente a Supabase. Si tiene éxito, actualiza y guarda las mascotas
  /// en la base de datos local (evitando sobrescribir mascotas locales con fotos pendientes de subir).
  /// Si ocurre un fallo de red o servidor, retorna la lista guardada en la base de datos local.
  Future<List<PetModel>> fetchPets(String userId) async {
    final localRows = await _local.getPetsForUser(userId);

    try {
      final remotePets = await _remote.fetchPets(userId);
      for (final pet in remotePets) {
        final existing = await _local.getPetById(pet.id);
        if (existing != null &&
            existing.syncState != 'synced' &&
            existing.localPhotoPath != null) {
          continue;
        }
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

  /// Agrega una nueva mascota localmente y encola su sincronización.
  ///
  /// Asigna un ID único tipo UUID, resuelve el guardado local o remoto de su foto,
  /// inserta el registro en SQLite con estado `pending_upsert` e inserta la operación en la cola de sincronización.
  /// Por último, intenta disparar un ciclo inmediato de sincronización.
  Future<PetModel> addPet(PetModel pet, {XFile? photo}) async {
    final withId = pet.copyWith(id: pet.id.isEmpty ? _uuid.v4() : pet.id);
    final petToSave = await _resolvePetPhoto(withId, photo);

    await _local.savePetPendingSync(
      pet: _mapDomainToLocalCompanion(petToSave, syncState: 'pending_upsert'),
      entityType: 'pet',
      entityId: petToSave.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(petToSave)),
    );

    await syncPendingQueue();
    final local = await _local.getPetById(petToSave.id);
    return local != null ? _mapLocalToDomain(local) : petToSave;
  }

  Future<PetModel> updatePet(PetModel pet, {XFile? newPhoto}) async {
    final petToSave = await _resolvePetPhoto(pet, newPhoto);

    await _local.savePetPendingSync(
      pet: _mapDomainToLocalCompanion(petToSave, syncState: 'pending_upsert'),
      entityType: 'pet',
      entityId: pet.id,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(petToSave)),
    );

    try {
      await syncPendingQueue();
    } catch (_) {
      // La mascota ya quedo guardada localmente; el sync se reintentara luego.
    }

    final local = await _local.getPetById(pet.id);
    return local != null ? _mapLocalToDomain(local) : petToSave;
  }

  Future<void> deletePet(String petId) async {
    await _local.markPetPendingDelete(
      petId: petId,
      entityType: 'pet',
      entityId: petId,
      operation: 'delete',
    );

    await syncPendingQueue();
  }

  Future<PetModel> toggleNotifications(String petId, bool enabled) async {
    final local = await _local.getPetById(petId);
    if (local == null) {
      return _remote.toggleNotifications(petId, enabled);
    }

    final updated = _mapLocalToDomain(
      local,
    ).copyWith(notificationsEnabled: enabled);
    await _local.savePetPendingSync(
      pet: _mapDomainToLocalCompanion(updated, syncState: 'pending_upsert'),
      entityType: 'pet',
      entityId: petId,
      operation: 'upsert',
      payloadJson: jsonEncode(_toSyncPayload(updated)),
    );

    await syncPendingQueue();
    final result = await _local.getPetById(petId);
    return result != null ? _mapLocalToDomain(result) : updated;
  }

  /// Sincroniza la cola local de pendientes de tipo 'pet' hacia el servidor remoto.
  ///
  /// Recorre los elementos de la cola local [SyncQueue]. Para cada uno:
  /// 1. Verifica si corresponde al tipo de entidad y si cumple con las condiciones de reintento (backoff exponencial).
  /// 2. Si la operación es `delete`, realiza la eliminación remota y local.
  /// 3. Si la mascota tiene una foto guardada temporalmente en local (offline), intenta subirla primero a Supabase Storage.
  /// 4. Determina si la mascota existe remotamente para realizar un INSERT (add) o UPDATE (update).
  /// 5. Marca el registro local como `synced` y elimina la acción de la cola.
  /// 6. En caso de error, incrementa el contador de intentos y registra el último error en la base de datos.
  Future<void> syncPendingQueue() async {
    final pending = await _local.getPendingSyncActions();

    for (final action in pending) {
      if (action.entityType != 'pet') continue;
      if (!_shouldRetry(action)) continue;

      try {
        if (action.operation == 'delete') {
          await _remote.deletePet(action.entityId);
          await _deleteLocalPetPhotoIfExists(action.entityId);
          await _local.hardDeletePet(action.entityId);
          await _local.removeSyncAction(action.id);
          continue;
        }

        if (action.payloadJson == null || action.payloadJson!.isEmpty) {
          await _local.removeSyncAction(action.id);
          continue;
        }

        final map = jsonDecode(action.payloadJson!) as Map<String, dynamic>;
        var model = _fromSyncPayload(map);
        final localRow = await _local.getPetById(model.id);

        final uploadedUrl = await _tryUploadLocalPetPhoto(localRow);
        if (uploadedUrl != null) {
          model = model.copyWith(photoUrl: uploadedUrl, clearLocalPhotoPath: true);
        }

        final existsRemotely = await _existsInRemote(model.userId, model.id);
        final synced = existsRemotely
            ? await _remote.updatePet(model)
            : await _remote.addPet(model);

        await _local.upsertPet(
          _mapDomainToLocalCompanion(
            synced,
            syncState: 'synced',
            localPhotoPath: uploadedUrl != null
                ? null
                : localRow?.localPhotoPath,
          ),
        );
        await _local.removeSyncAction(action.id);
      } catch (e) {
        await _local.markSyncAttemptFailed(action.id, e.toString());
      }
    }
  }

  Future<PetModel> _resolvePetPhoto(PetModel pet, XFile? photo) async {
    if (photo == null) return pet;

    try {
      final bytes = await photo.readAsBytes();
      final mime = photo.mimeType ?? 'image/jpeg';
      final url = await _remote.uploadPetPhoto(pet.id, bytes, mime);
      await _deleteStoredLocalPhoto(pet.localPhotoPath);
      return pet.copyWith(photoUrl: url, clearLocalPhotoPath: true);
    } catch (_) {
      final localPath = await _persistPetPhotoLocally(pet.id, photo);
      await _deleteStoredLocalPhoto(pet.localPhotoPath);
      return pet.copyWith(localPhotoPath: localPath);
    }
  }

  Future<String> _persistPetPhotoLocally(String petId, XFile photo) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'pending_pet_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final mime = photo.mimeType ?? 'image/jpeg';
    final ext = mime.split('/').last;
    final destPath = p.join(
      photosDir.path,
      '${petId}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );

    if (photo.path.isNotEmpty) {
      await File(photo.path).copy(destPath);
    } else {
      await File(destPath).writeAsBytes(await photo.readAsBytes());
    }

    return destPath;
  }

  Future<String?> _tryUploadLocalPetPhoto(LocalPet? localRow) async {
    final localPath = localRow?.localPhotoPath;
    if (localPath == null || localPath.isEmpty) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      final ext = p.extension(file.path).replaceFirst('.', '');
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final url = await _remote.uploadPetPhoto(localRow!.id, bytes, mime);
      await file.delete();
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLocalPetPhotoIfExists(String petId) async {
    final local = await _local.getPetById(petId);
    await _deleteStoredLocalPhoto(local?.localPhotoPath);
  }

  Future<void> _deleteStoredLocalPhoto(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
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
    String? localPhotoPath,
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
      localPhotoPath: Value(localPhotoPath ?? pet.localPhotoPath),
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
      localPhotoPath: row.localPhotoPath,
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
