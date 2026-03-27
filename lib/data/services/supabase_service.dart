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

  // Login
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
          createdAt: DateTime.now(),
        );
      }
    } on AuthException {
      throw Exception('Credenciales inválidas.');
    }
    return null;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  //  Verificar sesión activa
  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get currentUserId => currentUser?.id;
}
