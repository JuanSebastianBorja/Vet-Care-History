import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../data/models/consultation_model.dart';
import '../data/models/vaccine_model.dart';
import '../data/models/deworming_model.dart';
import '../data/services/history_service.dart';
import '../data/services/notification_service.dart';

class HistoryViewModel extends ChangeNotifier {
  final HistoryService _service = HistoryService();
  final NotificationService _notifService = NotificationService();

  List<ConsultationModel> _consultations = [];
  List<VaccineModel> _vaccines = [];
  List<DewormingModel> _dewormings = [];
  bool _isLoading = false;
  String? _error;

  List<ConsultationModel> get consultations => _consultations;
  List<VaccineModel> get vaccines => _vaccines;
  List<DewormingModel> get dewormings => _dewormings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadForPet(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.fetchConsultations(petId),
        _service.fetchVaccines(petId),
        _service.fetchDewormings(petId),
      ]);
      _consultations = results[0] as List<ConsultationModel>;
      _vaccines = results[1] as List<VaccineModel>;
      _dewormings = results[2] as List<DewormingModel>;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addConsultation(ConsultationModel c, List<XFile> photos) async {
    _error = null;
    try {
      final saved = await _service.addConsultation(c, photos);
      _consultations.insert(0, saved);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateConsultation(
    ConsultationModel c,
    List<XFile> newPhotos,
    List<String> photoIdsToDelete,
  ) async {
    _error = null;
    try {
      final updated = await _service.updateConsultation(
        c,
        newPhotos,
        photoIdsToDelete,
      );
      final idx = _consultations.indexWhere((x) => x.id == c.id);
      if (idx != -1) _consultations[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteConsultation(String id) async {
    _error = null;
    try {
      await _service.deleteConsultation(id);
      _consultations.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ================= VACUNAS =================

  Future<bool> addVaccine(VaccineModel v, String petName) async {
    _error = null;
    try {
      final saved = await _service.addVaccine(v);
      _vaccines.insert(0, saved);

      // Programar notificación
      if (saved.nextDueDate != null) {
        await _scheduleVaccineNotification(saved, petName);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateVaccine(VaccineModel v, String petName) async {
    _error = null;
    try {
      // Buscar el registro anterior para comparar fechas o cancelar
      final oldRecord = _vaccines.firstWhere(
        (x) => x.id == v.id,
        orElse: () => v,
      );

      final updated = await _service.updateVaccine(v);
      final idx = _vaccines.indexWhere((x) => x.id == v.id);
      if (idx != -1) _vaccines[idx] = updated;

      // Si cambió la fecha o es nueva, re-programar
      if (updated.nextDueDate != null) {
        // Cancelar primero por seguridad
        await _notifService.cancelNotification(
          NotificationService.generateNotificationId('vaccine', updated.id),
        );
        await _scheduleVaccineNotification(updated, petName);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVaccine(String id) async {
    _error = null;
    try {
      // Cancelar notificación antes de borrar
      await _notifService.cancelNotification(
        NotificationService.generateNotificationId('vaccine', id),
      );

      await _service.deleteVaccine(id);
      _vaccines.removeWhere((v) => v.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ================= DESPARASITACIONES =================

  Future<bool> addDeworming(DewormingModel d, String petName) async {
    _error = null;
    try {
      final saved = await _service.addDeworming(d);
      _dewormings.insert(0, saved);

      if (saved.nextDueDate != null) {
        await _scheduleDewormingNotification(saved, petName);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDeworming(DewormingModel d, String petName) async {
    _error = null;
    try {
      final updated = await _service.updateDeworming(d);
      final idx = _dewormings.indexWhere((x) => x.id == d.id);
      if (idx != -1) _dewormings[idx] = updated;

      if (updated.nextDueDate != null) {
        await _notifService.cancelNotification(
          NotificationService.generateNotificationId('deworming', updated.id),
        );
        await _scheduleDewormingNotification(updated, petName);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDeworming(String id) async {
    _error = null;
    try {
      await _notifService.cancelNotification(
        NotificationService.generateNotificationId('deworming', id),
      );

      await _service.deleteDeworming(id);
      _dewormings.removeWhere((d) => d.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ================= AUXILIARES DE NOTIFICACIÓN =================

  Future<void> _scheduleVaccineNotification(
    VaccineModel v,
    String petName,
  ) async {
    if (v.nextDueDate == null) return;

    // Programar 1 día antes a las 9:00 AM
    final scheduleDate = DateTime(
      v.nextDueDate!.year,
      v.nextDueDate!.month,
      v.nextDueDate!.day - 1,
      9,
      0,
    );

    final id = NotificationService.generateNotificationId('vaccine', v.id);
    final title = '💉 Vacuna pendiente';
    final body = '$petName necesita su vacuna "${v.vaccineName}" mañana.';

    await _notifService.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduleDate,
      channelId: 'vetcare_vaccines',
      payload: '{"type":"vaccine","petId":"${v.petId}","recordId":"${v.id}"}',
    );
  }

  Future<void> _scheduleDewormingNotification(
    DewormingModel d,
    String petName,
  ) async {
    if (d.nextDueDate == null) return;

    // Programar 1 día antes a las 9:00 AM
    final scheduleDate = DateTime(
      d.nextDueDate!.year,
      d.nextDueDate!.month,
      d.nextDueDate!.day - 1,
      9,
      0,
    );

    final id = NotificationService.generateNotificationId('deworming', d.id);
    final title = '💊 Desparasitación pendiente';
    final body = '$petName necesita desparasitarse con "${d.product}" mañana.';

    await _notifService.scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduleDate,
      channelId: 'vetcare_dewormings',
      payload: '{"type":"deworming","petId":"${d.petId}","recordId":"${d.id}"}',
    );
  }

  void clear() {
    _consultations = [];
    _vaccines = [];
    _dewormings = [];
    _error = null;
    notifyListeners();
  }
}
