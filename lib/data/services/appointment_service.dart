import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/local_appointments.json');
  }

  Future<List<AppointmentModel>> _readLocal() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = json.decode(content) as List<dynamic>;
      return list.map((e) => AppointmentModel.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocal(List<AppointmentModel> all) async {
    try {
      final file = await _getLocalFile();
      final data = all.map((e) => {
        ...e.toInsertMap(),
        'id': e.id,
        'created_at': e.createdAt.toIso8601String(),
      }).toList();
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  Future<List<AppointmentModel>> fetchAppointments(String petId) async {
    try {
      final data = await _client
          .from('appointments')
          .select()
          .eq('pet_id', petId)
          .order('appointment_datetime', ascending: true);
      return (data as List<dynamic>).map((e) => AppointmentModel.fromMap(e)).toList();
    } catch (_) {
      final local = await _readLocal();
      final filtered = local.where((e) => e.petId == petId).toList();
      filtered.sort((a, b) => a.appointmentDatetime.compareTo(b.appointmentDatetime));
      return filtered;
    }
  }

  Future<AppointmentModel> addAppointment(AppointmentModel appointment) async {
    final generatedId = const Uuid().v4();
    final toSave = appointment.copyWith(id: generatedId, createdAt: DateTime.now());
    
    try {
      final data = await _client
          .from('appointments')
          .insert(toSave.toInsertMap())
          .select()
          .single();
      return AppointmentModel.fromMap(data);
    } catch (_) {
      final local = await _readLocal();
      local.add(toSave);
      await _writeLocal(local);
      return toSave;
    }
  }

  Future<AppointmentModel> updateAppointment(AppointmentModel appointment) async {
    try {
      final data = await _client
          .from('appointments')
          .update(appointment.toUpdateMap())
          .eq('id', appointment.id)
          .select()
          .single();
      return AppointmentModel.fromMap(data);
    } catch (_) {
      final local = await _readLocal();
      final idx = local.indexWhere((x) => x.id == appointment.id);
      if (idx != -1) {
        local[idx] = appointment;
        await _writeLocal(local);
      }
      return appointment;
    }
  }

  Future<void> deleteAppointment(String id) async {
    try {
      await _client.from('appointments').delete().eq('id', id);
    } catch (_) {
      final local = await _readLocal();
      local.removeWhere((x) => x.id == id);
      await _writeLocal(local);
    }
  }
}
