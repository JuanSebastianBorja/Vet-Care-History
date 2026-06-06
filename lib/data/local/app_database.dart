import 'package:drift/drift.dart';

import 'database_write_queue.dart';
import 'db_connection.dart';

part 'app_database.g.dart';

/// Tabla Drift para almacenar de manera local la información de las mascotas.
class LocalPets extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().named('user_id')();

  TextColumn get name => text()();

  TextColumn get species => text()();

  TextColumn get breed => text().nullable()();

  DateTimeColumn get birthDate => dateTime().named('birth_date').nullable()();

  TextColumn get sex => text().nullable()();

  TextColumn get photoUrl => text().named('photo_url').nullable()();

  /// Ruta local de foto pendiente de subir cuando no hay conexion.
  TextColumn get localPhotoPath =>
      text().named('local_photo_path').nullable()();

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

/// Tabla Drift que actúa como cola de sincronización de operaciones pendientes (offline queue).
///
/// Guarda los registros de cambios realizados mientras la aplicación no tiene conexión a internet
/// (o cuando falla la subida inicial), permitiendo su sincronización diferida hacia Supabase.
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

/// Tabla Drift para almacenar de manera local las consultas clínicas asociadas a una mascota.
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

/// Tabla Drift para almacenar de manera local el registro de vacunas aplicadas a las mascotas.
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

/// Tabla Drift para almacenar de manera local el registro de desparasitaciones de las mascotas.
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

/// Tabla Drift para rastrear de manera local las fotos de consultas pendientes por subir.
class PendingConsultationPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get consultationId => text().named('consultation_id')();

  TextColumn get localPath => text().named('local_path')();

  TextColumn get mimeType => text().named('mime_type').nullable()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

/// Tabla Drift para almacenar citas veterinarias de manera local.
class LocalAppointments extends Table {
  TextColumn get id => text()();

  TextColumn get petId => text().named('pet_id')();

  DateTimeColumn get appointmentDatetime => dateTime().named('appointment_datetime')();

  TextColumn get veterinarianName => text().named('veterinarian_name').nullable()();

  TextColumn get motive => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('synced'))();

  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Servicio de base de datos local SQLite administrado con Drift.
///
/// Implementa patrón Singleton para garantizar una única conexión abierta a la base de datos local,
/// y expone métodos de consulta y transacciones seguras bajo una cola de escritura serializada.
@DriftDatabase(
  tables: [
    LocalPets,
    SyncQueue,
    LocalConsultations,
    LocalVaccines,
    LocalDewormings,
    PendingConsultationPhotos,
    LocalAppointments,
  ],
)
class AppDatabase extends _$AppDatabase {
  // Inicialización privada del Singleton.
  AppDatabase._() : super(openConnection());

  /// Instancia compartida única para toda la aplicación.
  static final AppDatabase instance = AppDatabase._();

  /// Constructor factory que retorna la instancia única de [AppDatabase].
  factory AppDatabase() => instance;

  bool _inWrite = false;

  /// Ejecuta una acción de escritura serializada a través de la cola global de reintentos.
  ///
  /// Evita colisiones de bloqueos de archivo SQLite en escenarios de alta concurrencia.
  Future<T> runWrite<T>(Future<T> Function() action) {
    return DatabaseWriteQueue.instance.enqueue(() async {
      return DatabaseWriteQueue.runWithRetry(() async {
        _inWrite = true;
        try {
          return await action();
        } finally {
          _inWrite = false;
        }
      });
    });
  }

  // Ejecuta directamente si ya estamos en un contexto de escritura, de lo contrario encola.
  Future<T> _write<T>(Future<T> Function() action) {
    if (_inWrite) return action();
    return runWrite(action);
  }

  @override
  int get schemaVersion => 6;

  /// Lógica de actualización e inicialización del esquema de base de datos (SQLite Schema Migrations).
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
      if (from < 5) {
        await m.createTable(localAppointments);
      }
      if (from < 6) {
        await m.addColumn(localPets, localPets.localPhotoPath);
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
    return _write(
      () => into(localPets).insertOnConflictUpdate(companion),
    );
  }

  Future<void> markPetDeleted(String petId) {
    return _write(
      () => (update(localPets)..where((tbl) => tbl.id.equals(petId))).write(
        LocalPetsCompanion(
          syncState: const Value('pending_delete'),
          localUpdatedAt: Value(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> hardDeletePet(String petId) {
    return _write(
      () => (delete(localPets)..where((tbl) => tbl.id.equals(petId))).go(),
    );
  }

  Future<void> markPetSynced(String petId) {
    return _write(
      () => (update(localPets)..where((tbl) => tbl.id.equals(petId))).write(
        LocalPetsCompanion(
          syncState: const Value('synced'),
          localUpdatedAt: Value(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> savePetPendingSync({
    required LocalPetsCompanion pet,
    required String entityType,
    required String entityId,
    required String operation,
    String? payloadJson,
  }) {
    return runWrite(
      () => transaction(() async {
        await into(localPets).insertOnConflictUpdate(pet);
        await into(syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: Value(payloadJson),
          ),
        );
      }),
    );
  }

  Future<void> markPetPendingDelete({
    required String petId,
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return runWrite(
      () => transaction(() async {
        await (update(localPets)..where((tbl) => tbl.id.equals(petId))).write(
          LocalPetsCompanion(
            syncState: const Value('pending_delete'),
            localUpdatedAt: Value(DateTime.now()),
          ),
        );
        await into(syncQueue).insert(
          SyncQueueCompanion.insert(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
          ),
        );
      }),
    );
  }

  Future<int> enqueueSyncAction({
    required String entityType,
    required String entityId,
    required String operation,
    String? payloadJson,
  }) {
    return _write(
      () => into(syncQueue).insert(
        SyncQueueCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payloadJson: Value(payloadJson),
        ),
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
    return _write(
      () => (update(syncQueue)..where((tbl) => tbl.id.equals(queueId))).write(
        SyncQueueCompanion.custom(
          attempts: syncQueue.attempts + const Constant(1),
          lastError: Constant(error),
          createdAt: Constant(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> removeSyncAction(int queueId) {
    return _write(
      () => (delete(syncQueue)..where((tbl) => tbl.id.equals(queueId))).go(),
    );
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
    return _write(
      () => into(localConsultations).insertOnConflictUpdate(companion),
    );
  }

  Future<void> replaceConsultationsForPet(
    String petId,
    List<LocalConsultationsCompanion> items,
  ) {
    return runWrite(
      () => transaction(() async {
        await (delete(
          localConsultations,
        )..where((tbl) => tbl.petId.equals(petId))).go();
        for (final item in items) {
          await into(localConsultations).insert(item);
        }
      }),
    );
  }

  Future<void> deleteConsultation(String consultationId) {
    return _write(
      () => (delete(
        localConsultations,
      )..where((tbl) => tbl.id.equals(consultationId))).go(),
    );
  }

  Future<int> addPendingConsultationPhoto(
    PendingConsultationPhotosCompanion companion,
  ) {
    return _write(() => into(pendingConsultationPhotos).insert(companion));
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
    return _write(
      () => (delete(
        pendingConsultationPhotos,
      )..where((tbl) => tbl.id.equals(id))).go(),
    );
  }

  Future<void> deletePendingPhotosForConsultation(String consultationId) {
    return _write(
      () => (delete(
        pendingConsultationPhotos,
      )..where((tbl) => tbl.consultationId.equals(consultationId))).go(),
    );
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
    return _write(
      () => into(localVaccines).insertOnConflictUpdate(companion),
    );
  }

  Future<void> replaceVaccinesForPet(
    String petId,
    List<LocalVaccinesCompanion> items,
  ) {
    return runWrite(
      () => transaction(() async {
        await (delete(
          localVaccines,
        )..where((tbl) => tbl.petId.equals(petId))).go();
        for (final item in items) {
          await into(localVaccines).insert(item);
        }
      }),
    );
  }

  Future<void> deleteVaccine(String vaccineId) {
    return _write(
      () => (delete(
        localVaccines,
      )..where((tbl) => tbl.id.equals(vaccineId))).go(),
    );
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
    return _write(
      () => into(localDewormings).insertOnConflictUpdate(companion),
    );
  }

  Future<void> replaceDewormingsForPet(
    String petId,
    List<LocalDewormingsCompanion> items,
  ) {
    return runWrite(
      () => transaction(() async {
        await (delete(
          localDewormings,
        )..where((tbl) => tbl.petId.equals(petId))).go();
        for (final item in items) {
          await into(localDewormings).insert(item);
        }
      }),
    );
  }

  Future<void> deleteDeworming(String dewormingId) {
    return _write(
      () => (delete(
        localDewormings,
      )..where((tbl) => tbl.id.equals(dewormingId))).go(),
    );
  }

  Future<List<LocalAppointment>> getAppointmentsForPet(String petId) {
    return (select(localAppointments)
          ..where(
            (tbl) =>
                tbl.petId.equals(petId) &
                tbl.syncState.isNotValue('pending_delete'),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.appointmentDatetime,
              mode: OrderingMode.asc,
            ),
          ]))
        .get();
  }

  Future<LocalAppointment?> getAppointmentById(String id) {
    return (select(localAppointments)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertAppointment(LocalAppointmentsCompanion companion) {
    return _write(
      () => into(localAppointments).insertOnConflictUpdate(companion),
    );
  }

  Future<void> replaceAppointmentsForPet(
    String petId,
    List<LocalAppointmentsCompanion> items,
  ) {
    return runWrite(
      () => transaction(() async {
        await (delete(localAppointments)
              ..where((tbl) => tbl.petId.equals(petId)))
            .go();
        for (final item in items) {
          await into(localAppointments).insert(item);
        }
      }),
    );
  }

  Future<void> deleteAppointment(String id) {
    return _write(
      () => (delete(localAppointments)..where((tbl) => tbl.id.equals(id))).go(),
    );
  }
}
