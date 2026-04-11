import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consultation_model.dart';
import '../models/vaccine_model.dart';
import '../models/deworming_model.dart';
import '../../core/constants/app_constants.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ConsultationModel>> fetchConsultations(String petId) async {
    final data = await _client
        .from('consultations')
        .select('*, consultation_photos(*)')
        .eq('pet_id', petId)
        .order('visit_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => ConsultationModel.fromMap(e))
        .toList();
  }

  Future<ConsultationModel> addConsultation(
      ConsultationModel c, List<XFile> photos) async {
    final data = await _client
        .from('consultations')
        .insert(c.toInsertMap())
        .select()
        .single();
    final saved = ConsultationModel.fromMap({...data, 'consultation_photos': []});

    final List<ConsultationPhotoModel> uploadedPhotos = [];
    for (final photo in photos) {
      final url = await _uploadConsultationPhoto(saved.id, photo);
      final photoData = await _client
          .from('consultation_photos')
          .insert({'consultation_id': saved.id, 'photo_url': url})
          .select()
          .single();
      uploadedPhotos.add(ConsultationPhotoModel.fromMap(photoData));
    }

    return saved.copyWith(photos: uploadedPhotos);
  }

  Future<ConsultationModel> updateConsultation(
      ConsultationModel c,
      List<XFile> newPhotos,
      List<String> photoIdsToDelete) async {
    await _client
        .from('consultations')
        .update(c.toUpdateMap())
        .eq('id', c.id);

    for (final id in photoIdsToDelete) {
      await _client.from('consultation_photos').delete().eq('id', id);
    }

    final List<ConsultationPhotoModel> addedPhotos = [];
    for (final photo in newPhotos) {
      final url = await _uploadConsultationPhoto(c.id, photo);
      final photoData = await _client
          .from('consultation_photos')
          .insert({'consultation_id': c.id, 'photo_url': url})
          .select()
          .single();
      addedPhotos.add(ConsultationPhotoModel.fromMap(photoData));
    }

    final remaining =
        c.photos.where((p) => !photoIdsToDelete.contains(p.id)).toList();
    return c.copyWith(photos: [...remaining, ...addedPhotos]);
  }

  Future<void> deleteConsultation(String id) async {
    await _client.from('consultations').delete().eq('id', id);
  }

  Future<String> _uploadConsultationPhoto(
      String consultationId, XFile photo) async {
    final bytes = await photo.readAsBytes();
    final mime = photo.mimeType ?? 'image/jpeg';
    final ext = mime.split('/').last;
    final path =
        '$consultationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(AppConstants.examPhotoBucket)
        .uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true));
    return _client.storage
        .from(AppConstants.examPhotoBucket)
        .getPublicUrl(path);
  }

  Future<List<VaccineModel>> fetchVaccines(String petId) async {
    final data = await _client
        .from('vaccines')
        .select()
        .eq('pet_id', petId)
        .order('application_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => VaccineModel.fromMap(e))
        .toList();
  }

  Future<VaccineModel> addVaccine(VaccineModel v) async {
    final data = await _client
        .from('vaccines')
        .insert(v.toInsertMap())
        .select()
        .single();
    return VaccineModel.fromMap(data);
  }

  Future<VaccineModel> updateVaccine(VaccineModel v) async {
    final data = await _client
        .from('vaccines')
        .update(v.toUpdateMap())
        .eq('id', v.id)
        .select()
        .single();
    return VaccineModel.fromMap(data);
  }

  Future<void> deleteVaccine(String id) async {
    await _client.from('vaccines').delete().eq('id', id);
  }

  Future<List<DewormingModel>> fetchDewormings(String petId) async {
    final data = await _client
        .from('dewormings')
        .select()
        .eq('pet_id', petId)
        .order('application_date', ascending: false);
    return (data as List<dynamic>)
        .map((e) => DewormingModel.fromMap(e))
        .toList();
  }

  Future<DewormingModel> addDeworming(DewormingModel d) async {
    final data = await _client
        .from('dewormings')
        .insert(d.toInsertMap())
        .select()
        .single();
    return DewormingModel.fromMap(data);
  }

  Future<DewormingModel> updateDeworming(DewormingModel d) async {
    final data = await _client
        .from('dewormings')
        .update(d.toUpdateMap())
        .eq('id', d.id)
        .select()
        .single();
    return DewormingModel.fromMap(data);
  }

  Future<void> deleteDeworming(String id) async {
    await _client.from('dewormings').delete().eq('id', id);
  }
}
