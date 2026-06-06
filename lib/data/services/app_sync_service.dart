import 'dart:async';

import '../repositories/consultation_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/vaccine_repository.dart';
import '../repositories/deworming_repository.dart';
import '../repositories/appointment_repository.dart';

/// Servicio centralizado de sincronización de datos fuera de línea (offline sync).
///
/// Implementa un patrón Singleton para asegurar que solo exista un bucle de sincronización activo.
/// Se encarga de programar reintentos periódicos en segundo plano (cada 45 segundos)
/// para subir los datos pendientes en local a Supabase.
class AppSyncService {
  static final AppSyncService _instance = AppSyncService._internal();
  factory AppSyncService() => _instance;
  AppSyncService._internal();

  final ConsultationRepository _consultationRepository =
      ConsultationRepository();
  final PetRepository _petRepository = PetRepository();
  final VaccineRepository _vaccineRepository = VaccineRepository();
  final DewormingRepository _dewormingRepository = DewormingRepository();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();

  Timer? _timer;
  bool _isRunning = false;
  bool _isSyncing = false;

  /// Arranca el bucle de sincronización en segundo plano.
  ///
  /// Ejecuta un intento de sincronización inicial inmediato y programa un temporizador periódico
  /// que se ejecuta en segundo plano cada 45 segundos para verificar si hay pendientes en local.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Primer intento sin bloquear el arranque de la UI.
    unawaited(syncNow());

    // Reintenta en segundo plano para pendientes offline.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(syncNow());
    });
  }

  /// Detiene el bucle de sincronización periódica y cancela el temporizador.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// Ejecuta el proceso de sincronización inmediato para todas las entidades del aplicativo.
  ///
  /// Valida que no haya un ciclo de sincronización ya en progreso. Dispara en orden secuencial
  /// la sincronización de colas locales pendientes de consultas, mascotas, vacunas,
  /// desparasitaciones y citas veterinarias hacia Supabase.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _consultationRepository.syncPendingQueue();
      await _petRepository.syncPendingQueue();
      await _vaccineRepository.syncPendingQueue();
      await _dewormingRepository.syncPendingQueue();
      await _appointmentRepository.syncPendingQueue();
    } finally {
      _isSyncing = false;
    }
  }
}
