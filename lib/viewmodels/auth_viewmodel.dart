import 'package:flutter/foundation.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../data/models/user_model.dart';
import '../data/services/supabase_service.dart';

class AuthViewModel extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _error;
  int _avatarVersion = 0;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isUploadingAvatar => _isUploadingAvatar;
  int get avatarVersion => _avatarVersion;
  String? get error => _error;
  bool get isSignedIn => _user != null;

  // Verificar sesión al iniciar app
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AppBootstrap.instance.ready;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_supabase.isSignedIn) {
      final uid = _supabase.currentUser!.id;
      final email = _supabase.currentUser!.email!;
      String? fullName = _supabase.currentUser!.userMetadata?['full_name'];
      String? avatarUrl;

      // Intentamos cargar el perfil desde la tabla
      final profile = await _supabase.fetchProfile(uid);
      if (profile != null) {
        fullName = profile['full_name'] ?? fullName;
        avatarUrl = profile['avatar_url'];
      }

      _user = UserModel(
        id: uid,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(String fullName) async {
    if (_user == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.updateProfile(_user!.id, {'full_name': fullName});
      _user = UserModel(
        id: _user!.id,
        email: _user!.email,
        fullName: fullName,
        avatarUrl: _user!.avatarUrl,
        createdAt: _user!.createdAt,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAvatar(Uint8List bytes, String mimeType) async {
    if (_user == null) return false;
    _isUploadingAvatar = true;
    _error = null;
    notifyListeners();

    try {
      final url = await _supabase.uploadAvatar(_user!.id, bytes, mimeType);
      print('🔗 URL DE LA FOTO DE PERFIL: $url');

      await _supabase.updateProfile(_user!.id, {'avatar_url': url});

      final profile = await _supabase.fetchProfile(_user!.id);
      final resolvedUrl = (profile?['avatar_url'] as String?)?.trim();
      final avatarUrl = (resolvedUrl != null && resolvedUrl.isNotEmpty)
          ? resolvedUrl
          : url;

      print('🔗 URL DE LA FOTO DE PERFIL (confirmada): $avatarUrl');

      _user = UserModel(
        id: _user!.id,
        email: _user!.email,
        fullName: _user!.fullName,
        avatarUrl: avatarUrl,
        createdAt: _user!.createdAt,
      );
      _avatarVersion++;
      _isUploadingAvatar = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isUploadingAvatar = false;
      notifyListeners();
      return false;
    }
  }

  // Registro
  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _supabase.signUp(email, password, fullName);
      if (_user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login
  Future<bool> login(String email, String password) async {
    print('🔐 [AuthViewModel] login() iniciado');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔐 [AuthViewModel] Esperando AppBootstrap...');
      await AppBootstrap.instance.ready;
      print('🔐 [AuthViewModel] Bootstrap listo, llamando signIn...');

      _user = await _supabase.signIn(email, password);
      if (_user != null) {
        print('🔐 [AuthViewModel] login exitoso | userId=${_user!.id}');
        return true;
      }

      _error = 'No se pudo iniciar sesión (respuesta vacía del servidor).';
      print('⚠️ [AuthViewModel] signIn retornó null sin excepción');
    } catch (e, st) {
      print('🚨 ERROR CAPTURADO EN LOGIN: $e');
      print('🚨 STACK TRACE AuthViewModel.login: $st');
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🔐 [AuthViewModel] login() finalizado | error=$_error');
    }

    return false;
  }

  // Login con Google
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _supabase.signInWithGoogle();
      if (_user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login con GitHub
  Future<bool> loginWithGithub() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _supabase.signInWithGithub();
      if (_user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _supabase.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
