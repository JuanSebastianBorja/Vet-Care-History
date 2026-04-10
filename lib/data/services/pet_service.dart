import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pet_model.dart';
import '../../core/constants/app_constants.dart';

class PetService {
  static final PetService _instance = PetService._internal();
  factory PetService() => _instance;
  PetService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Crear mascota
  Future<PetModel?> createPet(PetModel pet) async {
    try {
      final response = await _client
          .from('pets')
          .insert(pet.toSupabaseMap())
          .select()
          .single();

      return PetModel.fromSupabase(response);
    } on PostgrestException catch (e) {
      throw Exception('Error al crear mascota: ${e.message}');
    } catch (e) {
      throw Exception('Error al crear mascota: $e');
    }
  }

  // Actualizar mascota
  Future<PetModel?> updatePet(String petId, PetModel pet) async {
    try {
      final response = await _client
          .from('pets')
          .update(pet.toSupabaseUpdateMap())
          .eq('id', petId)
          .select()
          .single();

      return PetModel.fromSupabase(response);
    } on PostgrestException catch (e) {
      throw Exception('Error al actualizar mascota: ${e.message}');
    } catch (e) {
      throw Exception('Error al actualizar mascota: $e');
    }
  }

  // Eliminar mascota
  Future<void> deletePet(String petId) async {
    try {
      await _client.from('pets').delete().eq('id', petId);
    } on PostgrestException catch (e) {
      throw Exception('Error al eliminar mascota: ${e.message}');
    } catch (e) {
      throw Exception('Error al eliminar mascota: $e');
    }
  }

  // Obtener mascotas de un usuario
  Future<List<PetModel>> getPets(String userId) async {
    try {
      final response = await _client
          .from('pets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((data) => PetModel.fromSupabase(data)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Error al obtener mascotas: ${e.message}');
    } catch (e) {
      throw Exception('Error al obtener mascotas: $e');
    }
  }

  // Obtener una mascota por ID
  Future<PetModel?> getPetById(String petId) async {
    try {
      final response = await _client
          .from('pets')
          .select()
          .eq('id', petId)
          .single();

      return PetModel.fromSupabase(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null; // No rows found
      throw Exception('Error al obtener mascota: ${e.message}');
    } catch (e) {
      throw Exception('Error al obtener mascota: $e');
    }
  }

  // Subir foto de mascota
  Future<String> uploadPetPhoto(String petId, Uint8List imageBytes) async {
    try {
      final fileName = '${petId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _client.storage
          .from(AppConstants.petPhotoBucket)
          .uploadBinary(fileName, imageBytes);

      final photoUrl = _client.storage
          .from(AppConstants.petPhotoBucket)
          .getPublicUrl(fileName);

      // Actualizar URL en la base de datos
      await _client
          .from('pets')
          .update({'photo_url': photoUrl})
          .eq('id', petId);

      return photoUrl;
    } on StorageException catch (e) {
      throw Exception('Error al subir foto: ${e.message}');
    } catch (e) {
      throw Exception('Error al subir foto: $e');
    }
  }

  // Escuchar cambios en tiempo real
  Stream<List<PetModel>> watchPets(String userId) {
    return _client
        .from('pets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => PetModel.fromSupabase(e)).toList());
  }
}
