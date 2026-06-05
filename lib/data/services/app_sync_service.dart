import 'dart:async';

import '../repositories/consultation_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/vaccine_repository.dart';
import '../repositories/deworming_repository.dart';

class AppSyncService {
  static final AppSyncService _instance = AppSyncService._internal();
  factory AppSyncService() => _instance;
  AppSyncService._internal();

  final ConsultationRepository _consultationRepository =
      ConsultationRepository();
  final PetRepository _petRepository = PetRepository();
  final VaccineRepository _vaccineRepository = VaccineRepository();
  final DewormingRepository _dewormingRepository = DewormingRepository();

  Timer? _timer;
  bool _isRunning = false;
  bool _isSyncing = false;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // Primer intento al iniciar la app.
    await syncNow();

    // Reintenta en segundo plano para pendientes offline.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(syncNow());
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _consultationRepository.syncPendingQueue();
      await _petRepository.syncPendingQueue();
      await _vaccineRepository.syncPendingQueue();
      await _dewormingRepository.syncPendingQueue();
    } finally {
      _isSyncing = false;
    }
  }
}
