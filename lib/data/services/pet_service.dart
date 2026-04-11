import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet_model.dart';
import '../../core/constants/app_constants.dart';

class PetService {
  static final PetService _instance = PetService._internal();
  factory PetService() => _instance;
  PetService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<PetModel>> fetchPets(String userId) async {
    final data = await _client
        .from('pets')
        .select()
        .eq('user_id', userId)
        .order('name');
    return (data as List<dynamic>).map((e) => PetModel.fromMap(e)).toList();
  }

  Future<PetModel> addPet(PetModel pet) async {
    final data = await _client
        .from('pets')
        .insert(pet.toInsertMap())
        .select()
        .single();
    return PetModel.fromMap(data);
  }

  Future<PetModel> updatePet(PetModel pet) async {
    final data = await _client
        .from('pets')
        .update(pet.toUpdateMap())
        .eq('id', pet.id)
        .select()
        .single();
    return PetModel.fromMap(data);
  }

  Future<void> deletePet(String petId) async {
    await _client.from('pets').delete().eq('id', petId);
  }

  Future<String> uploadPetPhoto(
      String key, Uint8List bytes, String mimeType) async {
    final ext = mimeType.split('/').last;
    final path = '$key/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(AppConstants.petPhotoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return _client.storage
        .from(AppConstants.petPhotoBucket)
        .getPublicUrl(path);
  }
}
