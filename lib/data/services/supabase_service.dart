import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Registro
  Future<UserModel?> signUp(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email!,
          fullName: fullName,
          createdAt: DateTime.now(),
        );
      }
    } on AuthException catch (e) {
      // Aquí SÍ usamos 'e' para leer el mensaje de error
      if (e.message.contains('already') || e.message.contains('duplicate')) {
        throw Exception('Este correo ya tiene una cuenta.');
      }
      if (e.message.contains('password')) {
        throw Exception(
          'La contraseña debe tener mínimo ${AppConstants.minPasswordLength} caracteres.',
        );
      }
      throw Exception(e.message);
    }
    return null;
  }

  Future<UserModel?> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email!,
          fullName: response.user!.userMetadata?['full_name'],
          avatarUrl: response.user!.userMetadata?['avatar_url'],
          createdAt: DateTime.now(),
        );
      }
    } on AuthException {
      throw Exception('Credenciales inválidas.');
    }
    return null;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String> uploadAvatar(String userId, Uint8List bytes, String mimeType) async {
    final ext = mimeType.split('/').last;
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(AppConstants.avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return _client.storage.from(AppConstants.avatarBucket).getPublicUrl(path);
  }

  Future<UserModel> updateProfile({required String fullName, String? avatarUrl}) async {
    final response = await _client.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': fullName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      ),
    );
    final user = response.user!;
    return UserModel(
      id: user.id,
      email: user.email!,
      fullName: user.userMetadata?['full_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
      createdAt: DateTime.now(),
    );
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get currentUserId => currentUser?.id;
}
