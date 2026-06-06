import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

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
    print('🔐 [SupabaseService] signIn iniciado | ${AppConstants.supabaseConfigDebug}');
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(
            AppConstants.authRequestTimeout,
            onTimeout: () {
              throw TimeoutException(
                'El servidor no respondió en ${AppConstants.authRequestTimeout.inSeconds}s. '
                'Revisa tu conexión a internet y la URL de Supabase.',
              );
            },
          );

      print(
        '🔐 [SupabaseService] signIn respuesta OK | userId=${response.user?.id}',
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email!,
          fullName: response.user!.userMetadata?['full_name'],
          createdAt: DateTime.now(),
        );
      }

      print('⚠️ [SupabaseService] signIn: respuesta sin usuario');
      throw Exception('El servidor respondió pero no devolvió un usuario.');
    } on AuthException catch (e) {
      print(
        '🚨 ERROR CAPTURADO EN LOGIN (AuthException): ${e.message} | '
        'status=${e.statusCode}',
      );
      throw Exception('Credenciales inválidas: ${e.message}');
    } on TimeoutException catch (e) {
      print('🚨 ERROR CAPTURADO EN LOGIN (Timeout): $e');
      throw Exception(e.message ?? e.toString());
    } catch (e, st) {
      print('🚨 ERROR CAPTURADO EN LOGIN: $e');
      print('🚨 STACK TRACE signIn: $st');
      throw Exception('Error de conexión: $e');
    }
  }

  // Login con Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      final String? iosClientId = AppConstants.googleIosClientId.isNotEmpty
          ? AppConstants.googleIosClientId
          : null;

      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: kIsWeb
            ? AppConstants.googleWebClientId
            : (Platform.isIOS || Platform.isMacOS ? iosClientId : null),
        serverClientId: kIsWeb ? null : AppConstants.googleWebClientId,
      );

      // Limpia estado anterior para evitar bloqueos silenciosos del flujo.
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'No se pudo obtener idToken de Google. Verifica Web Client ID y SHA-1 en Google Cloud.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email!,
          fullName:
              response.user!.userMetadata?['full_name'] ??
              response.user!.userMetadata?['name'],
          createdAt: DateTime.now(),
        );
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Error al iniciar sesión con Google: $e');
    }
    return null;
  }

  // Login con GitHub
  Future<UserModel?> signInWithGithub() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: kIsWeb ? null : AppConstants.oauthRedirectUri,
      );

      if (!launched) {
        throw Exception('No se pudo abrir el navegador para GitHub.');
      }

      final authState = await _client.auth.onAuthStateChange
          .firstWhere((data) => data.session != null)
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException(
                'Timeout esperando autenticación con GitHub',
              );
            },
          );

      final user = authState.session?.user ?? _client.auth.currentUser;
      if (user == null) {
        throw Exception('No se pudo completar el inicio de sesión con GitHub.');
      }

      return UserModel(
        id: user.id,
        email: user.email ?? '',
        fullName:
            user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            user.userMetadata?['login'],
        avatarUrl: user.userMetadata?['avatar_url'],
        createdAt: DateTime.now(),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } on TimeoutException {
      throw Exception(
        'El inicio de sesión con GitHub tardó demasiado. Intenta de nuevo.',
      );
    } catch (e) {
      throw Exception('Error al iniciar sesión con GitHub: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: AppConstants.googleWebClientId,
    );
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.disconnect();
    }
    await _client.auth.signOut();
  }

  // Perfil del usuario
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final data = await _client.from('profiles').select().eq('id', userId).single();
      return data;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }

  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String mimeType,
  ) async {
    final ext = mimeType.split('/').last;
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(AppConstants.avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    final publicUrl =
        _client.storage.from(AppConstants.avatarBucket).getPublicUrl(path);
    print('🔗 URL DE LA FOTO DE PERFIL: $publicUrl');
    return publicUrl;
  }

  //  Verificar sesión activa
  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get currentUserId => currentUser?.id;
}
