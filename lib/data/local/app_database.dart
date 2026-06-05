import 'package:drift/drift.dart';

import 'db_connection.dart';

part 'app_database.g.dart';

/// Singleton de la base de datos para evitar múltiples instancias
AppDatabase? _databaseInstance;

AppDatabase get database {
  _databaseInstance ??= AppDatabase._internal();
  return _databaseInstance!;
}

class LocalPets extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().named('user_id')();

  TextColumn get name => text()();

  TextColumn get species => text()();

  TextColumn get breed => text().nullable()();

  DateTimeColumn get birthDate => dateTime().named('birth_date').nullable()();

  TextColumn get sex => text().nullable()();

  TextColumn get photoUrl => text().named('photo_url').nullable()();

  BoolColumn get notificationsEnabled => boolean()
      .named('notifications_enabled')
      .withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  // Marca el estado local del registro para sincronizacion incremental.
  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('synced'))();

  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get entityType => text().named('entity_type')();

  TextColumn get entityId => text().named('entity_id')();

  TextColumn get operation => text()();

  TextColumn get payloadJson => text().named('payload_json').nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().named('last_error').nullable()();
}

class LocalConsultations extends Table {
  TextColumn get id => text()();

  TextColumn get petId => text().named('pet_id')();

  DateTimeColumn get visitDate => dateTime().named('visit_date')();

  TextColumn get motive => text()();

  TextColumn get diagnosis => text().nullable()();

  TextColumn get treatment => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('synced'))();

  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalVaccines extends Table {
  TextColumn get id => text()();

  TextColumn get petId => text().named('pet_id')();

  TextColumn get vaccineName => text().named('vaccine_name')();

  DateTimeColumn get applicationDate => dateTime().named('application_date')();

  DateTimeColumn get nextDueDate =>
      dateTime().named('next_due_date').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('synced'))();

  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalDewormings extends Table {
  TextColumn get id => text()();

  TextColumn get petId => text().named('pet_id')();

  TextColumn get product => text()();

  TextColumn get dose => text().nullable()();

  TextColumn get route => text().nullable()();

  DateTimeColumn get applicationDate => dateTime().named('application_date')();

  DateTimeColumn get nextDueDate =>
      dateTime().named('next_due_date').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('synced'))();

  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingConsultationPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get consultationId => text().named('consultation_id')();

  TextColumn get localPath => text().named('local_path')();

  TextColumn get mimeType => text().named('mime_type').nullable()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [
    LocalPets,
    SyncQueue,
    LocalConsultations,
    LocalVaccines,
    LocalDewormings,
    PendingConsultationPhotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal() : super(openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(localConsultations);
      }
      if (from < 3) {
        await m.createTable(localVaccines);
        await m.createTable(localDewormings);
      }
      if (from < 4) {
        await m.createTable(pendingConsultationPhotos);
      }
    },
  );

  Future<List<LocalPet>> getPetsForUser(String userId) {
    return (select(localPets)
          ..where(
            (tbl) =>
                tbl.userId.equals(userId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Future<LocalPet?> getPetById(String petId) {
    return (select(
      localPets,
    )..where((tbl) => tbl.id.equals(petId))).getSingleOrNull();
  }

  Stream<List<LocalPet>> watchPetsForUser(String userId) {
    return (select(localPets)
          ..where(
            (tbl) =>
                tbl.userId.equals(userId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<void> upsertPet(LocalPetsCompanion companion) {
    return into(localPets).insertOnConflictUpdate(companion);
  }

  Future<void> markPetDeleted(String petId) {
    return (update(localPets)..where((tbl) => tbl.id.equals(petId))).write(
      LocalPetsCompanion(
        syncState: const Value('pending_delete'),
        localUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> hardDeletePet(String petId) {
    return (delete(localPets)..where((tbl) => tbl.id.equals(petId))).go();
  }

  Future<void> markPetSynced(String petId) {
    return (update(localPets)..where((tbl) => tbl.id.equals(petId))).write(
      LocalPetsCompanion(
        syncState: const Value('synced'),
        localUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> enqueueSyncAction({
    required String entityType,
    required String entityId,
    required String operation,
    String? payloadJson,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<List<SyncQueueData>> getPendingSyncActions({int limit = 100}) {
    return (select(syncQueue)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> getPendingSyncCount() async {
    final rows = await select(syncQueue).get();
    return rows.length;
  }

  Stream<int> watchPendingSyncCount() {
    return select(syncQueue).watch().map((rows) => rows.length);
  }

  Future<void> markSyncAttemptFailed(int queueId, String error) {
    return (update(syncQueue)..where((tbl) => tbl.id.equals(queueId))).write(
      SyncQueueCompanion.custom(
        attempts: syncQueue.attempts + const Constant(1),
        lastError: Constant(error),
        createdAt: Constant(DateTime.now()),
      ),
    );
  }

  Future<void> removeSyncAction(int queueId) {
    return (delete(syncQueue)..where((tbl) => tbl.id.equals(queueId))).go();
  }

  Future<List<LocalConsultation>> getConsultationsForPet(String petId) {
    return (select(localConsultations)
          ..where(
            (tbl) =>
                tbl.petId.equals(petId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.visitDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<LocalConsultation?> getConsultationById(String consultationId) {
    return (select(
      localConsultations,
    )..where((tbl) => tbl.id.equals(consultationId))).getSingleOrNull();
  }

  Future<void> upsertConsultation(LocalConsultationsCompanion companion) {
    return into(localConsultations).insertOnConflictUpdate(companion);
  }

  Future<void> replaceConsultationsForPet(
    String petId,
    List<LocalConsultationsCompanion> items,
  ) async {
    await transaction(() async {
      await (delete(
        localConsultations,
      )..where((tbl) => tbl.petId.equals(petId))).go();
      for (final item in items) {
        await into(localConsultations).insert(item);
      }
    });
  }

  Future<void> deleteConsultation(String consultationId) {
    return (delete(
      localConsultations,
    )..where((tbl) => tbl.id.equals(consultationId))).go();
  }

  Future<int> addPendingConsultationPhoto(
    PendingConsultationPhotosCompanion companion,
  ) {
    return into(pendingConsultationPhotos).insert(companion);
  }

  Future<List<PendingConsultationPhoto>> getPendingPhotosForConsultation(
    String consultationId,
  ) {
    return (select(pendingConsultationPhotos)
          ..where((tbl) => tbl.consultationId.equals(consultationId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  Future<void> deletePendingPhoto(int id) {
    return (delete(
      pendingConsultationPhotos,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> deletePendingPhotosForConsultation(String consultationId) {
    return (delete(
      pendingConsultationPhotos,
    )..where((tbl) => tbl.consultationId.equals(consultationId))).go();
  }

  Future<Set<String>> getConsultationIdsWithPendingPhotosForPet(
    String petId,
  ) async {
    final rows = await customSelect(
      '''
      SELECT DISTINCT p.consultation_id
      FROM pending_consultation_photos p
      INNER JOIN local_consultations c ON c.id = p.consultation_id
      WHERE c.pet_id = ?
      ''',
      variables: [Variable.withString(petId)],
    ).get();

    return rows.map((row) => row.read<String>('consultation_id')).toSet();
  }

  Future<List<LocalVaccine>> getVaccinesForPet(String petId) {
    return (select(localVaccines)
          ..where(
            (tbl) =>
                tbl.petId.equals(petId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.applicationDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<LocalVaccine?> getVaccineById(String vaccineId) {
    return (select(
      localVaccines,
    )..where((tbl) => tbl.id.equals(vaccineId))).getSingleOrNull();
  }

  Future<void> upsertVaccine(LocalVaccinesCompanion companion) {
    return into(localVaccines).insertOnConflictUpdate(companion);
  }

  Future<void> replaceVaccinesForPet(
    String petId,
    List<LocalVaccinesCompanion> items,
  ) async {
    await transaction(() async {
      await (delete(
        localVaccines,
      )..where((tbl) => tbl.petId.equals(petId))).go();
      for (final item in items) {
        await into(localVaccines).insert(item);
      }
    });
  }

  Future<void> deleteVaccine(String vaccineId) {
    return (delete(
      localVaccines,
    )..where((tbl) => tbl.id.equals(vaccineId))).go();
  }

  Future<List<LocalDeworming>> getDewormingsForPet(String petId) {
    return (select(localDewormings)
          ..where(
            (tbl) =>
                tbl.petId.equals(petId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.applicationDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  Future<LocalDeworming?> getDewormingById(String dewormingId) {
    return (select(
      localDewormings,
    )..where((tbl) => tbl.id.equals(dewormingId))).getSingleOrNull();
  }

  Future<void> upsertDeworming(LocalDewormingsCompanion companion) {
    return into(localDewormings).insertOnConflictUpdate(companion);
  }

  Future<void> replaceDewormingsForPet(
    String petId,
    List<LocalDewormingsCompanion> items,
  ) async {
    await transaction(() async {
      await (delete(
        localDewormings,
      )..where((tbl) => tbl.petId.equals(petId))).go();
      for (final item in items) {
        await into(localDewormings).insert(item);
      }
    });
  }

  Future<void> deleteDeworming(String dewormingId) {
    return (delete(
      localDewormings,
    )..where((tbl) => tbl.id.equals(dewormingId))).go();
  }
}
